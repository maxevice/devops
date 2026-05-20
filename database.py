import json
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

def load_config():
    try:
        with open("/etc/mywebapp/config.json", "r") as f:
            return json.load(f)
    except FileNotFoundError:
        with open("config.json", "r") as f:
            return json.load(f)

config = load_config()
engine = create_engine(config["db_url"])
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()
