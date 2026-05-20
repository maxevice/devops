from fastapi import FastAPI, Depends, Request, Response, Form
from fastapi.responses import HTMLResponse, JSONResponse
from sqlalchemy.orm import Session
from sqlalchemy import text
from database import SessionLocal, engine
import models

app = FastAPI(title="mywebapp")

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.get("/", response_class=HTMLResponse)
def root():
    return """
    <html><body>
        <h1>Simple Inventory</h1>
        <ul>
            <li><a href="/items">Всі предмети (GET /items)</a></li>
            <li><a href="/health/alive">Перевірка: Alive</a></li>
            <li><a href="/health/ready">Перевірка: Ready</a></li>
        </ul>
        <form action="/items" method="post" enctype="application/x-www-form-urlencoded">
            <h3>Додати предмет</h3>
            Назва: <input type="text" name="name" required><br>
            Кількість: <input type="number" name="quantity" required><br>
            <input type="submit" value="Створити">
        </form>
    </body></html>
    """

@app.get("/health/alive")
def alive():
    return Response(content="OK", media_type="text/plain")

@app.get("/health/ready")
def ready(db: Session = Depends(get_db)):
    try:
        db.execute(text("SELECT 1"))
        return Response(content="OK", media_type="text/plain")
    except Exception as e:
        return Response(content=f"Error connecting to DB: {str(e)}", status_code=500, media_type="text/plain")

@app.get("/items")
def get_items(request: Request, db: Session = Depends(get_db)):
    items = db.query(models.Item).all()
    accept = request.headers.get("accept", "")
    if "text/html" in accept:
        html = "<html><body><h1>Інвентар</h1><table border='1'><tr><th>ID</th><th>Назва</th></tr>"
        for item in items:
            html += f"<tr><td>{item.id}</td><td><a href='/items/{item.id}'>{item.name}</a></td></tr>"
        html += "</table><br><a href='/'>На головну</a></body></html>"
        return HTMLResponse(content=html)
    return [{"id": i.id, "name": i.name} for i in items]

@app.post("/items")
async def create_item(request: Request, db: Session = Depends(get_db)):
    content_type = request.headers.get("content-type", "")
    if "application/x-www-form-urlencoded" in content_type:
        form_data = await request.form()
        name = form_data.get("name")
        quantity = int(form_data.get("quantity"))
    else:
        json_data = await request.json()
        name = json_data.get("name")
        quantity = int(json_data.get("quantity"))

    new_item = models.Item(name=name, quantity=quantity)
    db.add(new_item)
    db.commit()
    db.refresh(new_item)
    
    accept = request.headers.get("accept", "")
    if "text/html" in accept:
        return HTMLResponse(content=f"<html><body>Створено: ID {new_item.id}. <a href='/'>Назад</a></body></html>")
    return {"id": new_item.id, "name": new_item.name}

@app.get("/items/{item_id}")
def get_item(item_id: int, request: Request, db: Session = Depends(get_db)):
    item = db.query(models.Item).filter(models.Item.id == item_id).first()
    if not item:
        return Response(content="Not Found", status_code=404)
        
    accept = request.headers.get("accept", "")
    if "text/html" in accept:
        html = f"<html><body><h1>Деталі</h1><p>ID: {item.id}</p><p>Назва: {item.name}</p><p>Кількість: {item.quantity}</p><p>Створено: {item.created_at}</p><a href='/items'>Назад до списку</a></body></html>"
        return HTMLResponse(content=html)
    return {"id": item.id, "name": item.name, "quantity": item.quantity, "created_at": item.created_at.isoformat()}
