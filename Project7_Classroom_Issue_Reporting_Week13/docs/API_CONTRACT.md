# Week 13 API contract (controlled prototype)

Base: `http://127.0.0.1:8080`, application/json responses.

| Method | Route | Request | Success | Error example |
|---|---|---|---|---|
| GET | /health | none | 200 status ok | service offline |
| GET | /issues | none | 200 JSON array | service offline |
| POST | /issues | `room`, `title`, `description`, `category`; optional demo `deliveryMode` | 201 issue JSON with assignedTeam | 400 missing field, 409 duplicate |
| PATCH | /issues/:id | `status` | 200 updated issue | 400 bad transition, 404 unknown id |
| GET | /notifications | none | 200 queued notifications | service offline |
| POST | /worker/run | none | 200 current notifications | service offline |
| GET | /summary | none | 200 unresolved totals grouped by team | service offline |
| GET | /logs | none | 200 structured events | service offline |

Categories: Electrical → Electrical Team; Furniture → Carpentry Team; Cleaning → Custodial Team; Other → Facilities Team. Valid status progression: assigned → in_progress → resolved → closed, with resolved → in_progress allowed for reopening verification.

**Notifications**: normal deliveries are logged as delivered, temporary failure succeeds on the second attempt, permanent simulated failures go to manual_review on the third attempt. Max attempts = 3; retry delay = 5 seconds for classroom evidence. Scheduling is server-side and the worker runs every 5 seconds or manually via POST /worker/run.

**Decision**: Event-driven assignments queue work upon creation; scheduled worker services retries and alerts. Automatic routing is rule-based by category. Aging threshold is 60 seconds for reproducible evidence; production thresholds would be longer. The daily unresolved summary is represented by an on-demand `/summary` endpoint and a 1-minute demonstration log; it is NOT a literal daily job.

**Unimplemented future protection**: Authentication, role-based access, HTTPS deployment, persistent data store, and appropriate secure configuration. API is only for local testing.
