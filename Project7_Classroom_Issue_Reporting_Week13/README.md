# Project 7 — Classroom Issue Reporting System (Week 13 SA7)

A **working-source starter**, not a tested production application. It demonstrates classroom reporting, rule-based routing, duplicate detection, issue updates, simulated retry and recovery, permanent failure → manual review, aging escalation and summary logging. Use fictional data.

## Requirements
- Flutter SDK + Dart SDK on PATH
- Google Chrome and VS Code / Android Studio
- Internet once to run `dart pub get` and `flutter pub get`

## Backend
```powershell
cd backend
dart pub get
dart run bin/server.dart
```
The API listens at http://127.0.0.1:8080. Confirm http://127.0.0.1:8080/health in Chrome.

## Frontend
The `frontend` folder contains the app source and pubspec. Before the first run, create missing Flutter platform scaffolding from inside the folder:
```powershell
cd frontend
flutter create --platforms=web .
flutter pub get
flutter run -d chrome --web-port 3000
```
Do not overwrite the supplied `lib/main.dart` or `pubspec.yaml` if prompted. Open http://localhost:3000. If the backend is not connecting, check that Chrome uses localhost:3000 and the backend is running on port 8080.

## Backend routes
- GET `/health`: service health
- GET `/issues`: issue list
- POST `/issues`: create, route, prevent duplicate, queue notification
- PATCH `/issues/:id`: move `assigned` → `in_progress` → `resolved` → `closed`
- GET `/notifications`: delivery attempt statuses
- POST `/worker/run`: run pending work and aging evaluation
- GET `/summary`: unresolved report by team
- GET `/logs`: JSON audit log

## Week 13 simulation
1. Normal: create `Electrical` issue; notice eventually becomes `delivered`.
2. Temporary failure: choose `Simulate temporary failure`; press Run worker; first attempt schedules retry; after 5+ seconds run worker again and observe `delivered`.
3. Permanent failure: choose `Simulate permanent failure`; run worker 3 times, waiting 5+ seconds between; notice reaches `manual_review`.
4. Duplicate: submit same room + title + category while issue is not closed. Receive HTTP 409 duplicate message.
5. Aging: leave an issue unresolved 60+ seconds; Run worker; observe `escalated: true` and escalation notification.
6. Summary: review API `/summary` and `/logs`.

## Limitations: important for technical defense
- All records reside in memory and reset whenever backend restarts.
- Email/SMS is not sent. Delivery is simulated in a local queue to make testing safe and repeatable.
- Authentication, authorization, secure deployment and persistent storage are **not implemented** in this Week 13 foundation.
- Automated summary runs every minute **as a classroom demonstration**, not daily; `/summary` is available at any time.
- CORS allows only http://localhost:3000; do not expose the server publicly.
- Work is supplied as starter source; Dart and Flutter tools were not available to execute it in the creation environment, so verify it on your computer and record actual outcomes.
