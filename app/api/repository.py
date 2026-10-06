"""Data access for tasks, backed by PostgreSQL (Amazon RDS in AWS)."""

import os
from typing import Any, Protocol

import psycopg
from psycopg import sql
from psycopg.conninfo import make_conninfo
from psycopg.rows import dict_row

SCHEMA = """
CREATE TABLE IF NOT EXISTS tasks (
    id          SERIAL PRIMARY KEY,
    title       VARCHAR(200) NOT NULL,
    description TEXT,
    done        BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
)
"""

COLUMNS = "id, title, description, done, created_at"
UPDATABLE_FIELDS = ("title", "description", "done")


class TaskRepository(Protocol):
    def ping(self) -> bool: ...
    def list(self) -> list[dict[str, Any]]: ...
    def get(self, task_id: int) -> dict[str, Any] | None: ...
    def create(self, title: str, description: str | None) -> dict[str, Any]: ...
    def update(self, task_id: int, fields: dict[str, Any]) -> dict[str, Any] | None: ...
    def delete(self, task_id: int) -> bool: ...


def conninfo_from_env() -> str:
    """Builds the connection string from the variables injected by deploy-app.sh."""
    return make_conninfo(
        host=os.environ["DB_HOST"],
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        # RDS enforces TLS; docker-compose uses "disable" for the local container
        sslmode=os.getenv("DB_SSLMODE", "require"),
        connect_timeout=5,
    )


class PostgresTaskRepository:
    def __init__(self, conninfo: str) -> None:
        self._conninfo = conninfo

    def _connect(self) -> psycopg.Connection:
        return psycopg.connect(self._conninfo, row_factory=dict_row)

    def init_schema(self) -> None:
        with self._connect() as conn:
            conn.execute(SCHEMA)

    def ping(self) -> bool:
        try:
            with self._connect() as conn:
                conn.execute("SELECT 1")
            return True
        except psycopg.Error:
            return False

    def list(self) -> list[dict[str, Any]]:
        with self._connect() as conn:
            return conn.execute(f"SELECT {COLUMNS} FROM tasks ORDER BY id").fetchall()

    def get(self, task_id: int) -> dict[str, Any] | None:
        with self._connect() as conn:
            return conn.execute(
                f"SELECT {COLUMNS} FROM tasks WHERE id = %s", (task_id,)
            ).fetchone()

    def create(self, title: str, description: str | None) -> dict[str, Any]:
        with self._connect() as conn:
            return conn.execute(
                f"INSERT INTO tasks (title, description) VALUES (%s, %s) RETURNING {COLUMNS}",
                (title, description),
            ).fetchone()

    def update(self, task_id: int, fields: dict[str, Any]) -> dict[str, Any] | None:
        fields = {k: v for k, v in fields.items() if k in UPDATABLE_FIELDS}
        if not fields:
            return self.get(task_id)

        assignments = sql.SQL(", ").join(
            sql.SQL("{} = {}").format(sql.Identifier(column), sql.Placeholder())
            for column in fields
        )
        query = sql.SQL("UPDATE tasks SET {} WHERE id = {} RETURNING " + COLUMNS).format(
            assignments, sql.Placeholder()
        )
        with self._connect() as conn:
            return conn.execute(query, (*fields.values(), task_id)).fetchone()

    def delete(self, task_id: int) -> bool:
        with self._connect() as conn:
            row = conn.execute("DELETE FROM tasks WHERE id = %s RETURNING id", (task_id,)).fetchone()
        return row is not None
