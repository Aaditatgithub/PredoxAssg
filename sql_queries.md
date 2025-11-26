# Queries

## Get all items
```
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
