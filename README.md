# Conversational Insight Generator

A FastAPI-based application that analyzes financial call transcripts using AI to extract actionable insights. The system processes Hinglish (Hindi + English) conversations between debt collection agents and customers, converting raw transcripts into structured insights with sentiment analysis and action recommendations.

## Features

- **AI-Powered Analysis**: Uses Google Gemini 2.5 Flash to intelligently analyze call transcripts
- **Structured Output**: Extracts customer intent, sentiment, and action requirements in JSON format
- **Hinglish Support**: Handles mixed Hindi-English conversations commonly found in financial services
- **Database Persistence**: Stores all analyzed transcripts and insights in PostgreSQL
- **Async Architecture**: Built on FastAPI with async/await for high performance
- **Compliance Ready**: Designed with compliance and audit trails in mind for financial institutions

## Project Structure

```
PredoxionAssignment/
├── app.py                 # Main FastAPI application
├── requirements.txt       # Python dependencies
├── run_tests.ps1         # PowerShell script to run test transcripts
├── commands.md           # Sample curl commands for testing
├── sql_queries.md        # Useful database queries
├── .env                  # Environment variables (not included - see setup)
└── myenv/               # Virtual environment
```

## Tech Stack

- **Framework**: FastAPI 0.122.0
- **Server**: Uvicorn 0.38.0
- **Database**: PostgreSQL with asyncpg 0.31.0
- **AI Model**: Google Gemini 2.5 Flash via google-genai 1.52.0
- **Validation**: Pydantic 2.12.4
- **Async Support**: Python 3.8+

## Installation

### Prerequisites
- Python 3.8 or higher
- PostgreSQL 12 or higher
- Google Gemini API key
- PostgreSQL connection string

### Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd PredoxionAssignment
   ```

2. **Create virtual environment**
   ```bash
   python -m venv myenv
   myenv\Scripts\activate  # Windows
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

4. **Configure environment variables**
   Create a `.env` file in the project root:
   ```env
   GEMINI_API_KEY=your_gemini_api_key_here
   DATABASE_URL=postgresql://user:password@localhost:5432/call_records
   ```

## Running the Application

Start the FastAPI server:
```bash
uvicorn app:app --host 127.0.0.1 --port 8000 --reload
```

The API will be available at `http://127.0.0.1:8000`

### Interactive API Documentation
- **Swagger UI**: `http://127.0.0.1:8000/docs`
- **ReDoc**: `http://127.0.0.1:8000/redoc`

## API Endpoints

### Health Check
```http
GET /
```
Returns application status and current timestamp.

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2025-11-26T10:30:45.123456+00:00"
}
```

### Analyze Call Transcript
```http
POST /analyze_call
Content-Type: application/json

{
  "transcript": "Agent: Hello, main Maya bol rahi hoon..."
}
```

**Response:**
```json
{
  "record_id": 1,
  "insights": {
    "customer_intent": "Customer wants to confirm payment schedule",
    "sentiment": "positive",
    "action_required": false,
    "summary": "Friendly EMI reminder call. Customer confirmed willingness to pay on time. No immediate action needed."
  }
}
```

## Input Schema

### TranscriptInput
```python
{
  "transcript": str  # Call transcript (required, non-empty)
}
```

## Output Schema

### AnalyzeCallResponse
```python
{
  "record_id": int,      # Unique database ID
  "insights": {
    "customer_intent": str,           # Brief summary of customer's intent
    "sentiment": "positive|neutral|negative",
    "action_required": bool,          # Whether action is needed
    "summary": str                    # 2-4 line professional summary
  }
}
```

## Testing

### Using PowerShell Test Script
```bash
.\run_tests.ps1
```

This script sends 10 sample transcripts to the `/analyze_call` endpoint and displays responses.

### Using curl
```bash
curl -Method POST "http://127.0.0.1:8000/analyze_call" `
  -Headers @{ "Content-Type"="application/json" } `
  -Body '{"transcript":"Agent: Hello..."}'
```

See `commands.md` for more examples.

## Database Schema

The application creates a `call_records` table on startup:

```sql
CREATE TABLE IF NOT EXISTS call_records (
    id SERIAL PRIMARY KEY,
    transcript TEXT NOT NULL,
    intent TEXT NOT NULL,
    sentiment TEXT NOT NULL,
    summary TEXT NOT NULL,
    action_required BOOLEAN NOT NULL
);
```

### Useful Queries

Get the last 10 records:
```sql
SELECT id,
       LEFT(transcript, 80) AS transcript_snip,
       intent,
       sentiment,
       action_required,
       LEFT(summary, 80) AS summary_snip
FROM call_records
ORDER BY id DESC
LIMIT 10;
```

See `sql_queries.md` for additional queries.

## System Prompt

The application uses a specialized system prompt for the Gemini model:

```
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
```

## Error Handling

The API provides meaningful error responses:

| Status Code | Scenario |
|-------------|----------|
| 200 | Successful analysis |
| 422 | Empty or invalid transcript |
| 500 | Database initialization failed or LLM generation failed |

## Performance Considerations

- **Async Processing**: Uses asyncpg for non-blocking database operations
- **Connection Pooling**: Maintains a PostgreSQL connection pool for efficiency
- **Retry Logic**: LLM calls have built-in retry mechanism (2 retries)
- **Structured Output**: Gemini model configured for JSON schema validation

## Logging

The application provides detailed logging:
- `[startup]` - Application initialization
- `[api]` - API request processing
- `[llm]` - LLM model interactions
- `[db]` - Database operations
- `[shutdown]` - Graceful shutdown

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `GEMINI_API_KEY` | Google Gemini API key | Yes |
| `DATABASE_URL` | PostgreSQL connection string | Yes |

## Dependencies

See `requirements.txt` for complete list. Key dependencies:
- fastapi, uvicorn (web framework)
- google-genai (AI model)
- asyncpg (async database driver)
- pydantic (data validation)
- python-dotenv (environment management)
