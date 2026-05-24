from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_health_alive():
    response = client.get("/health/alive")
    assert response.status_code == 200

def test_read_items_json():
    response = client.get("/items", headers={"Accept": "application/json"})
    assert response.status_code == 200
    assert isinstance(response.json(), list)