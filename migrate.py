from database import engine, Base
import models

print("Початок міграції бази даних...")
Base.metadata.create_all(bind=engine)
print("Міграцію завершено успішно. Таблиці створені.")
