import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

# Default ke SQLite biar gampang jalan di lokal tanpa setup DB server.
# Di production (Minggu 4 dst), ganti DATABASE_URL ke Postgres via environment variable,
# misal: postgresql://user:password@host:5432/minisoc
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./minisoc.db")

connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}

engine = create_engine(DATABASE_URL, connect_args=connect_args)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
