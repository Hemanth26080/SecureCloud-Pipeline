import pytest
from app.main import app


@pytest.fixture
def client():
    """Creates a fake browser for testing"""
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def test_health_returns_200(client):
    """Health endpoint must return 200 OK"""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.get_json()
    assert data["status"] == "healthy"


def test_ready_returns_200(client):
    """Ready endpoint must return 200 OK"""
    response = client.get("/ready")
    assert response.status_code == 200


def test_root_returns_message(client):
    """Root endpoint returns a message"""
    response = client.get("/")
    assert response.status_code == 200
    data = response.get_json()
    assert "message" in data


def test_users_returns_list(client):
    """Users endpoint returns a list"""
    response = client.get("/api/users")
    assert response.status_code == 200
    data = response.get_json()
    assert isinstance(data, list)
    assert len(data) > 0