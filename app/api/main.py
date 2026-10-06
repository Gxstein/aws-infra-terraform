"""Tasks API: small REST service used to exercise the AWS infrastructure.

Runs as a Docker container on EC2 and stores data in PostgreSQL on RDS.
"""

import logging
import os
import time
from contextlib import asynccontextmanager
from datetime import datetime

from fastapi import Depends, FastAPI, HTTPException, Request, Response, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from .repository import PostgresTaskRepository, TaskRepository, conninfo_from_env

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
logger = logging.getLogger("tasks-api")


@asynccontextmanager
async def lifespan(app: FastAPI):
    if os.getenv("DB_HOST"):
        repository = PostgresTaskRepository(conninfo_from_env())
        # RDS can still be starting when the container comes up: retry for ~1 minute
        for attempt in range(1, 13):
            try:
                repository.init_schema()
                logger.info("database ready")
                break
            except Exception as exc:  # noqa: BLE001 - log and retry any connection error
                logger.warning("database not ready (attempt %s): %s", attempt, exc)
                time.sleep(5)
        app.state.repository = repository
    yield


app = FastAPI(title="Tasks API", version="1.0.0", lifespan=lifespan)


def get_repository(request: Request) -> TaskRepository:
    repository = getattr(request.app.state, "repository", None)
    if repository is None:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Database is not configured")
    return repository


class TaskCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    description: str | None = Field(default=None, max_length=2000)


class TaskUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = Field(default=None, max_length=2000)
    done: bool | None = None


class Task(BaseModel):
    id: int
    title: str
    description: str | None
    done: bool
    created_at: datetime


@app.get("/health", tags=["ops"])
def health(request: Request) -> JSONResponse:
    """Used by the Docker HEALTHCHECK and by the deploy pipeline smoke test."""
    repository = getattr(request.app.state, "repository", None)
    database_up = repository is not None and repository.ping()
    body = {"status": "ok" if database_up else "degraded", "database": "up" if database_up else "down"}
    return JSONResponse(body, status_code=200 if database_up else 503)


@app.get("/tasks", response_model=list[Task], tags=["tasks"])
def list_tasks(repository: TaskRepository = Depends(get_repository)):
    return repository.list()


@app.post("/tasks", response_model=Task, status_code=status.HTTP_201_CREATED, tags=["tasks"])
def create_task(payload: TaskCreate, repository: TaskRepository = Depends(get_repository)):
    return repository.create(payload.title, payload.description)


@app.get("/tasks/{task_id}", response_model=Task, tags=["tasks"])
def get_task(task_id: int, repository: TaskRepository = Depends(get_repository)):
    task = repository.get(task_id)
    if task is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Task not found")
    return task


@app.patch("/tasks/{task_id}", response_model=Task, tags=["tasks"])
def update_task(task_id: int, payload: TaskUpdate, repository: TaskRepository = Depends(get_repository)):
    task = repository.update(task_id, payload.model_dump(exclude_unset=True))
    if task is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Task not found")
    return task


@app.delete("/tasks/{task_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["tasks"])
def delete_task(task_id: int, repository: TaskRepository = Depends(get_repository)) -> Response:
    if not repository.delete(task_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Task not found")
    return Response(status_code=status.HTTP_204_NO_CONTENT)
