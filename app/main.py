import asyncio
import os
from contextlib import asynccontextmanager

import psycopg
from fastapi import FastAPI
from pydantic import BaseModel


def get_conn():
    # DB 접속 정보는 Helm 차트가 환경변수로 넣어 줌 (Secret에서 가져옴)
    return psycopg.connect(
        host=os.environ["DB_HOST"],  # = postgres Service 이름 (내부 DNS)
        port=os.environ.get("DB_PORT", "5432"),
        dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        connect_timeout=3,
    )


@asynccontextmanager
async def lifespan(app: FastAPI):
    # postgres가 늦게 뜰 수 있으니 재시도하면서 테이블 생성
    for attempt in range(30):
        try:
            with get_conn() as conn:
                conn.execute(
                    "CREATE TABLE IF NOT EXISTS notes (id SERIAL PRIMARY KEY, text TEXT NOT NULL)"
                )
            print("DB ready")
            break
        except psycopg.Error as error:
            print(f"DB not ready yet ({attempt + 1}/30): {error}")
            await asyncio.sleep(2)
    yield


app = FastAPI(lifespan=lifespan)


class NoteIn(BaseModel):
    text: str


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/db")
def db_version():
    with get_conn() as conn:
        version = conn.execute("SELECT version()").fetchone()[0]
    return {"postgres": version}


@app.post("/notes")
def create_note(note: NoteIn):
    with get_conn() as conn:
        row = conn.execute(
            "INSERT INTO notes (text) VALUES (%s) RETURNING id", (note.text,)
        ).fetchone()
    return {"id": row[0], "text": note.text}


@app.get("/notes")
def list_notes():
    with get_conn() as conn:
        rows = conn.execute("SELECT id, text FROM notes ORDER BY id").fetchall()
    return [{"id": r[0], "text": r[1]} for r in rows]
