def test_health_ok(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "database": "up"}


def test_health_reports_database_down(client, repository):
    repository.healthy = False
    response = client.get("/health")
    assert response.status_code == 503
    assert response.json()["database"] == "down"


def test_create_and_get_task(client):
    created = client.post("/tasks", json={"title": "Provision VPC", "description": "Terraform"})
    assert created.status_code == 201
    task = created.json()
    assert task["id"] == 1
    assert task["done"] is False

    fetched = client.get(f"/tasks/{task['id']}")
    assert fetched.status_code == 200
    assert fetched.json()["title"] == "Provision VPC"


def test_list_tasks(client):
    client.post("/tasks", json={"title": "first"})
    client.post("/tasks", json={"title": "second"})
    response = client.get("/tasks")
    assert response.status_code == 200
    assert [t["title"] for t in response.json()] == ["first", "second"]


def test_update_task(client):
    client.post("/tasks", json={"title": "Configure alarms"})
    response = client.patch("/tasks/1", json={"done": True})
    assert response.status_code == 200
    assert response.json()["done"] is True
    assert response.json()["title"] == "Configure alarms"


def test_delete_task(client):
    client.post("/tasks", json={"title": "temporary"})
    assert client.delete("/tasks/1").status_code == 204
    assert client.get("/tasks/1").status_code == 404


def test_missing_task_returns_404(client):
    assert client.get("/tasks/999").status_code == 404
    assert client.patch("/tasks/999", json={"done": True}).status_code == 404
    assert client.delete("/tasks/999").status_code == 404


def test_validation_error(client):
    response = client.post("/tasks", json={"title": ""})
    assert response.status_code == 422


def test_without_database_returns_503():
    from fastapi.testclient import TestClient

    from api.main import app

    with TestClient(app) as raw_client:
        app.state.repository = None
        assert raw_client.get("/tasks").status_code == 503
        assert raw_client.get("/health").status_code == 503
