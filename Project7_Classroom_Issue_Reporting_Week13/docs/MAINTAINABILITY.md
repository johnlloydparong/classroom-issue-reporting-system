# Week 13 maintainability note

- Source separation: `frontend/lib/main.dart` is the UI, `backend/bin/server.dart` is the API and queue worker. In a larger solution, split routes, data storage, queue and routing policy into separate services.
- Failure handling: fixed max of three notification delivery attempts. One 5-second retry delay makes transient recovery testable. Exhausted attempts become `manual_review`; they are not silently dropped.
- Structured audit: view `GET /logs` or backend terminal. Logs contain issue IDs, event names, timestamps and attempts; they do not need real names or credentials.
- Duplicate detection: controlled demonstration uses room + category + title on unresolved issues. A later implementation should use careful normalization and allow staff confirmation of false positives.
- Persistent storage: currently in-memory (resets on restart). Migrate to SQLite or another instructor-approved store in later iterations.
- Scheduled reporting: currently 1-minute demo interval. Implement actual calendar-day schedule only after agreement on the operational timezone and required report delivery mechanism.
- Test conditions: normal, temporary failure (recovered), permanent failure (manual review), duplicate, status changes, aged item and summary. Capture evidence with actual timestamps and do not claim success if a local test fails.
- Data policy: fictional room IDs and fictional descriptions only. No real student identity, contact details, production access, or passwords.
