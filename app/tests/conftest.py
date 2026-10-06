from datetime import datetime, timezone
from typing import Any

import pytest
from fastapi.testclient import TestClient

from api.main import app


class InMemoryTaskRepository:
    """Fake repository so the API can be tested without a database."""

    def __init__(self) -> None:
        self._tasks: dict[int, dict[str, Any]] = {}
        self._next_id = 1
        self.healthy = True

    def ping(self) -> bool:
        return self.healthy

    def list(self) -> list[dict[str, Any]]:
        return [self._tasks[k] for k in sorted(self._tasks)]

    def get(self, task_id: int) -> dict[str, Any] | None:
        return self._tasks.get(task_id)

    def create(self, title: str, description: str | None) -> dict[str, Any]:
        task = {
            "id": self._next_id,
            "title": title,
            "description": description,
            "done": False,
            "created_at": datetime.now(timezone.utc),
        }
        self._tasks[self._next_id] = task
        self._next_id += 1
        return task

    def update(self, task_id: int, fields: dict[str, Any]) -> dict[str, Any] | None:
        task = self._tasks.get(task_id)
        if task is None:
            return None
        task.update(fields)
        return task

    def delete(self, task_id: int) -> bool:
        return self._tasks.pop(task_id, None) is not None


@pytest.fixture
def repository() -> InMemoryTaskRepository:
    return InMemoryTaskRepository()


@pytest.fixture
def client(repository: InMemoryTaskRepository):
    with TestClient(app) as test_client:
        app.state.repository = repository
        yield test_client
    app.state.repository = None
