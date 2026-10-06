"""Integration tests against a real PostgreSQL.

Skipped unless DB_HOST is set. In CI a postgres:16 service container is used;
locally: docker compose up -d db, then DB_HOST=localhost DB_NAME=tasks
DB_USER=app DB_PASSWORD=app DB_SSLMODE=disable pytest
"""

import os

import pytest

from api.repository import PostgresTaskRepository, conninfo_from_env

pytestmark = pytest.mark.skipif(not os.getenv("DB_HOST"), reason="DB_HOST not set")


@pytest.fixture
def repository():
    repo = PostgresTaskRepository(conninfo_from_env())
    repo.init_schema()
    with repo._connect() as conn:
        conn.execute("TRUNCATE tasks RESTART IDENTITY")
    return repo


def test_ping(repository):
    assert repository.ping() is True


def test_crud_roundtrip(repository):
    created = repository.create("Write Terraform", "network module")
    assert created["id"] == 1
    assert created["done"] is False

    assert repository.get(1)["title"] == "Write Terraform"
    assert len(repository.list()) == 1

    updated = repository.update(1, {"done": True, "title": "Write Terraform code"})
    assert updated["done"] is True
    assert updated["title"] == "Write Terraform code"

    assert repository.delete(1) is True
    assert repository.get(1) is None
    assert repository.delete(1) is False


def test_update_ignores_unknown_fields(repository):
    repository.create("task", None)
    updated = repository.update(1, {"id": 99, "created_at": "x"})
    assert updated["id"] == 1


def test_update_missing_task(repository):
    assert repository.update(42, {"done": True}) is None
