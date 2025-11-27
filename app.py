import os
import datetime
import asyncpg
from contextlib import asynccontextmanager
from dotenv import load_dotenv
from typing import Literal, Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from google import genai
from google.genai import types

load_dotenv()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if not GEMINI_API_KEY:
    raise RuntimeError("GEMINI_API_KEY environment variable is not set.")

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL environment variable is not set.")

class CallInsight(BaseModel):
    primary_purpose: str
    objective_met: bool
    key_outcome: str
    customer_intent: str
    non_payment_reason: Optional[str] = None
    sentiment_start: Literal["negative", "neutral", "positive"]
    sentiment_end: Literal["negative", "neutral", "positive"]
    hardship_flag: bool
    agent_performance_rating: int
    action_required: bool
    summary: str

class TranscriptInput(BaseModel):
    transcript: str

class AnalyzeCallResponse(BaseModel):
    record_id: int
    insights: CallInsight

db_pool: Optional[asyncpg.pool.Pool] = None
_genai_client = genai.Client(api_key=GEMINI_API_KEY)
genai_client_aio = _genai_client.aio

SYSTEM_PROMPT = """
You are an AI analyst specializing in Indian debt-collection call reviews. You will extract structured insights from call transcripts that may include Hinglish, informal language, sentiment shifts, and negotiation behavior.

Your job is to analyze the transcript objectively, without assumptions that are not supported by the text.

You MUST follow these rules:
1. Output ONLY valid JSON matching the schema exactly (no markdown, no extra text).
2. Do not change field names.
3. All values must be based strictly on the content of the transcript.

Field definitions:
- primary_purpose: The core reason for the call (e.g., "payment reminder", "overdue recovery", "settlement discussion", "dispute handling", "hardship request", "follow-up").
- objective_met: true ONLY if the agent achieved the intended outcome (e.g., confirmed payment date, recorded promise to pay, explained next steps successfully). false if the outcome is incomplete, refused, stalled, or unclear.
- key_outcome: A short factual sentence describing the final result of the call (e.g., "Customer promised payment next Friday", "Customer refused to pay", "Customer requested settlement details", "Customer reiterated a dispute").
- customer_intent: The customer's stated intention (e.g., "agreeing to pay later", "refusing to pay", "requesting more time", "raising dispute", "requesting restructuring").
- non_payment_reason: Use a short phrase if a reason is stated (e.g., "job loss", "salary delay", "travel", "system issue", "dispute", "forgot", "medical expenses", "financial hardship"). If no reason is clearly stated, set this to null.
- sentiment_start: "positive", "neutral", or "negative" based on the customer's tone at the beginning of the call.
- sentiment_end: "positive", "neutral", or "negative" based on the customer's tone at the end of the call, capturing any shift from the start.
- hardship_flag: true ONLY if the customer explicitly mentions financial difficulty, medical issues, job loss, or similar hardship. Otherwise false.
- agent_performance_rating: Integer 1-5, where:
    5 = very clear, professional, patient, and compliant
    4 = mostly professional with minor issues
    3 = average or neutral performance
    2 = somewhat aggressive, unclear, or pressuring
    1 = clearly aggressive, threatening, or non-compliant
- action_required: true if any follow-up is needed (e.g., reminder call on promise date, sending forms, internal review, escalation). false if no further action is needed.
- summary: 2-4 concise factual sentences describing the call, the customer's situation, and the outcome in neutral tone.

Output: Return ONLY a single JSON object conforming exactly to this schema. Do not include explanations or extra formatting outside the JSON.
"""

@asynccontextmanager
async def lifespan(app: FastAPI):
    global db_pool
    print("startup: creating database pool")
    db_pool = await asyncpg.create_pool(DATABASE_URL)

    async with db_pool.acquire() as conn:
        print("startup: ensuring call_records table exists")
        await conn.execute(
            """
            CREATE TABLE IF NOT EXISTS call_records (
                id SERIAL PRIMARY KEY,
                transcript TEXT NOT NULL,
                primary_purpose TEXT,
                objective_met BOOLEAN,
                key_outcome TEXT,
                customer_intent TEXT,
                non_payment_reason TEXT,
                sentiment_start TEXT,
                sentiment_end TEXT,
                hardship_flag BOOLEAN,
                agent_performance_rating INT,
                action_required BOOLEAN,
                summary TEXT NOT NULL
            );
            """
        )
        print("startup: schema ready")

    yield

    print("shutdown: closing database pool")
    if db_pool:
        await db_pool.close()
    print("shutdown: closing LLM client")
    if genai_client_aio:
        await genai_client_aio.aclose()
    print("shutdown: complete")

app = FastAPI(
    title="Conversational Insight Generator",
    lifespan=lifespan
)

async def generate_insights(transcript: str) -> CallInsight:
    if not transcript.strip():
        raise HTTPException(status_code=422, detail="Transcript cannot be empty")

    print("llm: generating insights")
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
            print("llm: received structured response")
            return parsed if isinstance(parsed, CallInsight) else CallInsight.model_validate(parsed)
        except Exception as exc:
            print(f"llm: attempt {attempt + 1} failed: {exc}")
            last_error = exc

    print("llm: all attempts failed")
    raise HTTPException(status_code=500, detail=f"LLM generation failed: {last_error}")

@app.get("/")
async def healthcheck() -> dict:
    print("api: healthcheck")
    return {"status": "ok", "timestamp": str(datetime.datetime.now(datetime.timezone.utc))}

@app.post("/analyze_call", response_model=AnalyzeCallResponse)
async def analyze_call(payload: TranscriptInput) -> AnalyzeCallResponse:
    if db_pool is None:
        print("api: database pool not initialized")
        raise HTTPException(status_code=500, detail="Database pool not initialized.")

    transcript = payload.transcript.strip()
    if not transcript:
        print("api: empty transcript received")
        raise HTTPException(status_code=422, detail="Transcript cannot be empty.")

    print(f"api: analyze_call, transcript_length={len(transcript)}")
    insights = await generate_insights(transcript)

    async with db_pool.acquire() as conn:
        print("db: inserting call record")
        record_id = await conn.fetchval(
            """
            INSERT INTO call_records (
                transcript,
                primary_purpose,
                objective_met,
                key_outcome,
                customer_intent,
                non_payment_reason,
                sentiment_start,
                sentiment_end,
                hardship_flag,
                agent_performance_rating,
                action_required,
                summary
            )
            VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
            RETURNING id;
            """,
            transcript,
            insights.primary_purpose,
            insights.objective_met,
            insights.key_outcome,
            insights.customer_intent,
            insights.non_payment_reason,
            insights.sentiment_start,
            insights.sentiment_end,
            insights.hardship_flag,
            insights.agent_performance_rating,
            insights.action_required,
            insights.summary,
        )
        print(f"db: record inserted id={record_id}")

    return AnalyzeCallResponse(record_id=record_id, insights=insights)
