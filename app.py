import os
import datetime
import asyncpg
from contextlib import asynccontextmanager
from dotenv import load_dotenv
from typing import Literal, Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, ValidationError

from google import genai
from google.genai import types

load_dotenv()

# Configs
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if not GEMINI_API_KEY:
    raise RuntimeError("GEMINI_API_KEY environment variable is not set.")

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL environment variable is not set.")

# Models
class CallInsight(BaseModel):
    customer_intent: str
    sentiment: Literal["negative", "positive", "neutral"]
    action_required: bool
    summary: str

class TranscriptInput(BaseModel):
    transcript: str

class AnalyzeCallResponse(BaseModel):
    record_id: int
    insights: CallInsight

# Globals-----------------------
db_pool: Optional[asyncpg.pool.Pool] = None
_genai_client = genai.Client(api_key=GEMINI_API_KEY)
genai_client_aio = _genai_client.aio

SYSTEM_PROMPT = """
You are an expert financial and debt-collection compliance analyst.

Your task:
- Read raw Hinglish (Hindi + English + informal) call transcripts.
- Convert each conversation into a concise, structured insight.

Schema:
- customer_intent: short sentence
- sentiment: Positive | Neutral | Negative
- action_required: boolean
- summary: 2-4 line professional summary

Rules:
- Output only valid JSON matching the schema.
- No extra text or formatting.
"""

@asynccontextmanager
async def lifespan(app: FastAPI):
    global db_pool

    print("[startup] Initializing database connection pool...")
    db_pool = await asyncpg.create_pool(DATABASE_URL)
    print("[startup] Database pool created.")

    async with db_pool.acquire() as conn:
        print("[startup] Ensuring table exists...")
        await conn.execute(
            """
            CREATE TABLE IF NOT EXISTS call_records (
                id SERIAL PRIMARY KEY,
                transcript TEXT NOT NULL,
                intent TEXT NOT NULL,
                sentiment TEXT NOT NULL,
                summary TEXT NOT NULL,
                action_required BOOLEAN NOT NULL
            );
            """
        )
        print("[startup] Table check completed.")

    yield

    print("[shutdown] Closing DB pool...")
    if db_pool:
        await db_pool.close()
        print("[shutdown] DB pool closed.")

    print("[shutdown] Closing LLM client...")
    if genai_client_aio:
        await genai_client_aio.aclose()
        print("[shutdown] LLM client closed.")

# App
app = FastAPI(
    title="Conversational Insight Generator",
    lifespan=lifespan
)

async def generate_insights(transcript: str) -> CallInsight:
    if not transcript.strip():
        raise HTTPException(status_code=422, detail="Transcript cannot be empty")

    print("[llm] Calling model with structured output...")
    retries = 2
    last_error: Optional[Exception] = None

    for attempt in range(retries + 1):
        try:
            response = await genai_client_aio.models.generate_content(
                model="gemini-2.5-flash",
                contents=transcript,
                config=types.GenerateContentConfig(
                    system_instruction=SYSTEM_PROMPT,
                    response_mime_type="application/json",
                    response_schema=CallInsight,
                ),
            )

            parsed = response.parsed
            print("[llm] Response received and parsed.")
            return parsed if isinstance(parsed, CallInsight) else CallInsight.model_validate(parsed)

        except Exception as exc:
            print(f"[llm] Attempt {attempt + 1} failed: {exc}")
            last_error = exc

    raise HTTPException(status_code=500, detail=f"LLM generation failed: {last_error}")

@app.get("/")
async def healthcheck() -> dict:
    return {
        "status": "ok",
        "timestamp": str(datetime.datetime.now(datetime.timezone.utc)),
    }

@app.post("/analyze_call", response_model=AnalyzeCallResponse)
async def analyze_call(payload: TranscriptInput) -> AnalyzeCallResponse:
    if db_pool is None:
        raise HTTPException(status_code=500, detail="Database pool not initialized.")

    transcript = payload.transcript.strip()
    if not transcript:
        raise HTTPException(status_code=422, detail="Transcript cannot be empty.")

    print("[api] Generating insights...")
    insights = await generate_insights(transcript)

    print("[db] Inserting record...")
    async with db_pool.acquire() as conn:
        record_id = await conn.fetchval(
            """
            INSERT INTO call_records (
                transcript,
                intent,
                sentiment,
                summary,
                action_required
            )
            VALUES ($1, $2, $3, $4, $5)
            RETURNING id;
            """,
            transcript,
            insights.customer_intent,
            insights.sentiment,
            insights.summary,
            insights.action_required,
        )

    print(f"[db] Record inserted with ID: {record_id}")
    return AnalyzeCallResponse(record_id=record_id, insights=insights)
