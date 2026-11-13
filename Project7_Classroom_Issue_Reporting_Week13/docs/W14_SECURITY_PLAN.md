
# Week 14 — Security Protection Plan

## Project Information

Project: Classroom Issue Reporting System
Assessment: Week 14 — SA8 and IA5
Module: Secure Data Exchange and Encryption

## 1. System Data Flow

1. A user opens the Flutter Web application.
2. The user enters classroom issue information.
3. The Flutter interface checks required fields.
4. The browser sends a request to the Dart backend API.
5. The backend validates the submitted information.
6. The backend creates an issue and assigns a maintenance team.
7. The system records issue changes and notification activity.
8. The backend returns a response to Flutter Web.
9. The user views the issue status and notifications.

## 2. Protection Requirements

| Component | Risk | Required Protection |
|---|---|---|
| Login | Unauthorized access | Authentication |
| API endpoints | Unauthorized actions | Role-based authorization |
| Issue form | Invalid or harmful input | Client and server validation |
| Browser-to-API connection | Data interception | HTTPS in approved deployment |
| Configuration | Exposed secrets | Environment configuration |
| Logs | Sensitive information exposure | Safe and minimal logging |
| Issue records | Unauthorized modification | Access checks and audit logs |
| Notification queue | Unauthorized processing | Restricted worker actions |

## 3. Proposed User Roles

Reporter:
- Submit classroom issues.
- View permitted issue records.
- Check issue status.

Maintenance Staff:
- View assigned issues.
- Update permitted issue statuses.

Administrator:
- Manage authorized users.
- Review issues and notifications.
- Handle permanent failures.

## 4. Security Tests

Test 1: Valid login.
Test 2: Invalid login.
Test 3: Missing authentication.
Test 4: Unauthorized role accessing a protected endpoint.
Test 5: Empty or invalid issue information.
Test 6: Altered or invalid authentication token.
Test 7: Expired authentication token.
Test 8: Protected configuration verification.
Test 9: Safe logging verification.
Test 10: Flutter Web API error handling.

## 5. Current Limitations

The Week 13 prototype uses in-memory data and local HTTP.
Authentication, role-based authorization, secure token handling,
and production HTTPS are planned Week 14 improvements.

No real credentials or sensitive institutional records
will be used during testing.
