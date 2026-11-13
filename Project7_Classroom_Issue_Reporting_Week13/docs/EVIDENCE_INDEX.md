# Evidence index — Week 13 SA7

Capture only after successfully running the project locally. Do not submit placeholder images as actual evidence.

| Filename | What to capture | Expected observation |
|---|---|---|
| W13_01_Backend_Started.png | Terminal running `dart run bin/server.dart` | backend_started JSON event and localhost URL |
| W13_02_Health_API.png | Browser `http://127.0.0.1:8080/health` | status = ok |
| W13_03_Flutter_Interface.png | Flutter Chrome view | report form, issues section, notification queue |
| W13_04_Issue_Submitted.png | Filled form followed by created issue | auto-assigned team and assigned status |
| W13_05_Duplicate_Blocked.png | Re-submit same room, title, category | duplicate message, no extra issue |
| W13_06_Routing_And_Status.png | Create issue & change state | issue assigned to team; updated status |
| W13_07_Transient_Attempt_1.png | Queue after first temporary failure | pending, attempts 1, temporary service timeout |
| W13_08_Transient_Recovered.png | Same notification after retry | delivered, attempts 2 |
| W13_09_Permanent_Manual_Review.png | After 3 failed attempts | manual_review, attempts 3 |
| W13_10_Aging_Escalation.png | Unresolved issue after 60+ seconds | escalated true; aging escalation notification |
| W13_11_Summary_API.png | Browser `/summary` | unresolved totals per team |
| W13_12_Structured_Logs.png | Browser `/logs` or terminal | timestamp, event, issue or notification ID |
| W13_13_Folder_And_Code.png | VS Code Explorer with project folders | frontend, backend, docs, evidence |
| W13_14_Git_Commit.png | Git terminal (optional if required by instructor) | personal commit describing Week 13 |

Add screenshots to `evidence/` and include a short caption for each in the submitted Week 13 report. Capture the actual output; do not fabricate tests or proof.
