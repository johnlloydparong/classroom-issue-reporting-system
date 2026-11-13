# System boundary and screen flow

User (student/faculty, demo role) → Flutter Web report form → POST /issues → server validation → duplicate check → category-based routing → assigned issue → queued delivery notification → worker → delivered OR retry (max 3) → manual review.

Facilities coordinator demo workflow → issue list → in_progress → resolved → closed (after verification). This prototype does not enforce user identities or roles yet; roles are a Week 14 goal.

Timer (5 seconds) → retry due notifications; timer/worker → escalate unresolved items older than 60 seconds; on-demand GET /summary → unresolved totals by team; 1-minute timer → summary log for classroom demonstration.

Failure branches: empty/missing input → 400; duplicate unresolved issue → 409; invalid status transition → 400; backend unavailable → Flutter connection message; transient delivery failure → retry, then delivered; permanent failure → manual_review.
