import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

// PROJECT 7 — CLASSROOM ISSUE REPORTING SYSTEM
// WEEK 14 — AUTHENTICATION AND ROLE-BASED AUTHORIZATION
// Controlled classroom prototype only.

// ==================================================
// 1. DATA AND AUTOMATION SETTINGS
// ==================================================

final issues = <Map<String, dynamic>>[];
final notifications = <Map<String, dynamic>>[];
final audit = <Map<String, dynamic>>[];

int issueSequence = 1;
int noticeSequence = 1;

const maxAttempts = 3;
const retryDelay = Duration(seconds: 5);

// ==================================================
// 2. AUTHENTICATION CONFIGURATION
// ==================================================

final jwtSecret = Platform.environment['JWT_SECRET'] ?? '';

final demoAccounts = <String, Map<String, String>>{
  'admin': {
    'username': Platform.environment['DEMO_USERNAME'] ?? '',
    'password': Platform.environment['DEMO_PASSWORD'] ?? '',
  },
  'reporter': {
    'username': Platform.environment['REPORTER_USERNAME'] ?? '',
    'password': Platform.environment['REPORTER_PASSWORD'] ?? '',
  },
  'staff': {
    'username': Platform.environment['STAFF_USERNAME'] ?? '',
    'password': Platform.environment['STAFF_PASSWORD'] ?? '',
  },
};

void validateAuthConfig() {
  if (jwtSecret.length < 32) {
    throw StateError('JWT_SECRET must contain at least 32 characters.');
  }

  final usernames = <String>{};

  for (final account in demoAccounts.values) {
    final username = account['username'] ?? '';
    final password = account['password'] ?? '';

    if (username.isEmpty || password.isEmpty) {
      throw StateError('Missing demo account configuration.');
    }

    if (!usernames.add(username)) {
      throw StateError('Demo usernames must be unique.');
    }
  }
}

// ==================================================
// 3. COMMON HELPERS
// ==================================================

String now() => DateTime.now().toUtc().toIso8601String();

void logEvent(String event, Map<String, dynamic> details) {
  final entry = <String, dynamic>{
    'time': now(),
    'event': event,
    ...details,
  };

  audit.add(entry);
  stdout.writeln(jsonEncode(entry));
}

Response jsonResponse(Object value, {int status = 200}) {
  return Response(
    status,
    body: jsonEncode(value),
    headers: {
      'content-type': 'application/json',
      'cache-control': 'no-store',
    },
  );
}

Future<Map<String, dynamic>?> readMap(Request request) async {
  try {
    final value = jsonDecode(await request.readAsString());

    if (value is Map<String, dynamic>) {
      return value;
    }
  } catch (_) {
    return null;
  }

  return null;
}

Map<String, dynamic>? findIssue(String id) {
  for (final issue in issues) {
    if (issue['id'].toString() == id) {
      return issue;
    }
  }

  return null;
}

String teamFor(String category) {
  switch (category) {
    case 'Electrical':
      return 'Electrical Team';
    case 'Furniture':
      return 'Carpentry Team';
    case 'Cleaning':
      return 'Custodial Team';
    default:
      return 'Facilities Team';
  }
}

// ==================================================
// 4. JWT CREATION
// ==================================================

Map<String, dynamic> createLoginToken(
  String username,
  String role,
) {
  final current = DateTime.now().toUtc();
  final expiration = current.add(const Duration(minutes: 15));

  final jwt = JWT({
    'sub': username,
    'role': role,
    'iat': current.millisecondsSinceEpoch ~/ 1000,
    'exp': expiration.millisecondsSinceEpoch ~/ 1000,
  });

  final token = jwt.sign(
    SecretKey(jwtSecret),
    algorithm: JWTAlgorithm.HS256,
  );

  return {
    'token': token,
    'tokenType': 'Bearer',
    'role': role,
    'expiresAt': expiration.toIso8601String(),
  };
}

// ==================================================
// 5. JWT VERIFICATION
// ==================================================

Map<String, dynamic>? verifyToken(Request request) {
  final authorization = request.headers['authorization'];

  if (authorization == null || !authorization.startsWith('Bearer ')) {
    return null;
  }

  final token = authorization.substring(7).trim();

  if (token.isEmpty) {
    return null;
  }

  try {
    // Verify signature and standard JWT validity checks.
    final jwt = JWT.verify(token, SecretKey(jwtSecret));

    final payload = jwt.payload;

    if (payload is! Map) {
      return null;
    }

    final subject = payload['sub'];
    final role = payload['role'];
    final expiration = payload['exp'];

    if (subject is! String || role is! String || expiration is! int) {
      return null;
    }

    if (!demoAccounts.containsKey(role)) {
      return null;
    }

    if (demoAccounts[role]?['username'] != subject) {
      return null;
    }

    final currentSeconds =
        DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

    if (expiration <= currentSeconds) {
      return null;
    }

    return Map<String, dynamic>.from(payload);
  } catch (_) {
    return null;
  }
}

// ==================================================
// 6. ROLE-BASED AUTHORIZATION
// ==================================================

Set<String> allowedRoles(String method, String path) {
  if (method == 'GET' && path == '/issues') {
    return {'admin', 'reporter', 'staff'};
  }

  if (method == 'POST' && path == '/issues') {
    return {'admin', 'reporter'};
  }

  if (method == 'PATCH' && path.startsWith('/issues/')) {
    return {'admin', 'staff'};
  }

  if (method == 'GET' && path == '/notifications') {
    return {'admin', 'staff'};
  }

  if (method == 'GET' && path == '/summary') {
    return {'admin', 'staff'};
  }

  if (method == 'GET' && path == '/logs') {
    return {'admin'};
  }

  if (method == 'POST' && path == '/worker/run') {
    return {'admin'};
  }

  return {};
}

Middleware authenticationMiddleware() {
  return (Handler inner) {
    return (Request request) async {
      final path = '/${request.url.path}';

      // Health and login routes are public.
      if (path == '/health' || path == '/login') {
        return inner(request);
      }

      final user = verifyToken(request);

      if (user == null) {
        logEvent('authentication_denied', {
          'path': path,
          'reason': 'missing_or_invalid_token',
        });

        return jsonResponse(
          {'error': 'Authentication required or token invalid'},
          status: 401,
        );
      }

      final role = user['role'] as String;
      final roles = allowedRoles(request.method, path);

      if (!roles.contains(role)) {
        logEvent('authorization_denied', {
          'path': path,
          'role': role,
        });

        return jsonResponse(
          {'error': 'Access forbidden for this role'},
          status: 403,
        );
      }

      return inner(request.change(context: {
        'user': user,
      }));
    };
  };
}

// ==================================================
// 7. WEEK 13 — NOTIFICATION QUEUE
// ==================================================

void enqueue(
  int issueId,
  String type, {
  String deliveryMode = 'normal',
}) {
  notifications.add({
    'id': noticeSequence++,
    'issueId': issueId,
    'type': type,
    'status': 'pending',
    'attempts': 0,
    'nextAttempt': now(),
    'deliveryMode': deliveryMode,
    'lastError': null,
  });

  logEvent('notification_queued', {
    'issueId': issueId,
    'type': type,
  });
}

Future<void> processQueue() async {
  final current = DateTime.now().toUtc();

  for (final notice in notifications) {
    if (notice['status'] != 'pending') {
      continue;
    }

    final next = DateTime.parse(notice['nextAttempt'] as String);

    if (next.isAfter(current)) {
      continue;
    }

    notice['attempts'] = (notice['attempts'] as int) + 1;

    final attempts = notice['attempts'] as int;
    final mode = notice['deliveryMode'];

    final shouldFail =
        mode == 'permanent' || (mode == 'transient' && attempts == 1);

    if (shouldFail) {
      notice['lastError'] = mode == 'permanent'
          ? 'Simulated permanent recipient failure'
          : 'Simulated temporary service timeout';

      if (attempts >= maxAttempts) {
        notice['status'] = 'manual_review';

        logEvent('notification_manual_review', {
          'notificationId': notice['id'],
          'attempt': attempts,
        });
      } else {
        notice['nextAttempt'] = current.add(retryDelay).toIso8601String();

        logEvent('notification_retry_scheduled', {
          'notificationId': notice['id'],
          'attempt': attempts,
        });
      }
    } else {
      notice['status'] = 'delivered';
      notice['deliveredAt'] = now();
      notice['lastError'] = null;

      logEvent('notification_delivered', {
        'notificationId': notice['id'],
        'attempt': attempts,
      });
    }
  }
}

// ==================================================
// 8. WEEK 13 — AGING ESCALATION
// ==================================================

void processAging() {
  final current = DateTime.now().toUtc();

  for (final issue in issues) {
    if (issue['status'] == 'closed') {
      continue;
    }

    final createdAt = DateTime.parse(issue['createdAt'] as String);
    final age = current.difference(createdAt);

    if (age.inSeconds >= 60 && issue['alertSent'] != true) {
      issue['alertSent'] = true;
      issue['escalated'] = true;

      enqueue(issue['id'] as int, 'aging_escalation');

      logEvent('issue_escalated', {
        'issueId': issue['id'],
      });
    }
  }
}

// ==================================================
// 9. MAIN SERVER
// ==================================================

Future<void> main() async {
  validateAuthConfig();

  final router = Router();

  // HEALTH
  router.get('/health', (Request request) {
    return jsonResponse({
      'status': 'ok',
      'time': now(),
    });
  });

  // LOGIN
  router.post('/login', (Request request) async {
    final body = await readMap(request);

    if (body == null) {
      return jsonResponse(
        {'error': 'Invalid login request'},
        status: 400,
      );
    }

    final username = body['username'];
    final password = body['password'];

    if (username is! String || password is! String) {
      return jsonResponse(
        {'error': 'Invalid username or password'},
        status: 401,
      );
    }

    for (final entry in demoAccounts.entries) {
      final account = entry.value;

      if (username == account['username'] && password == account['password']) {
        logEvent('login_success', {
          'role': entry.key,
        });

        return jsonResponse(
          createLoginToken(username, entry.key),
        );
      }
    }

    logEvent('login_failed', {
      'reason': 'invalid_credentials',
    });

    return jsonResponse(
      {'error': 'Invalid username or password'},
      status: 401,
    );
  });

  // GET ISSUES
  router.get('/issues', (Request request) {
    return jsonResponse(issues);
  });

  // CREATE ISSUE
  router.post('/issues', (Request request) async {
    final body = await readMap(request);

    if (body == null) {
      return jsonResponse(
        {'error': 'Invalid JSON object'},
        status: 400,
      );
    }

    final room = (body['room'] ?? '').toString().trim();
    final title = (body['title'] ?? '').toString().trim();
    final description = (body['description'] ?? '').toString().trim();
    final category = (body['category'] ?? '').toString().trim();

    const categories = {
      'Electrical',
      'Furniture',
      'Cleaning',
      'Other',
    };

    if (room.isEmpty ||
        title.isEmpty ||
        description.isEmpty ||
        !categories.contains(category) ||
        room.length > 80 ||
        title.length > 120 ||
        description.length > 1000) {
      return jsonResponse(
        {'error': 'Invalid classroom issue information'},
        status: 400,
      );
    }

    // DUPLICATE PREVENTION
    for (final existing in issues) {
      if (existing['room'].toString().toLowerCase() == room.toLowerCase() &&
          existing['title'].toString().toLowerCase() == title.toLowerCase() &&
          existing['category'] == category &&
          existing['status'] != 'closed') {
        logEvent('duplicate_blocked', {
          'existingIssueId': existing['id'],
        });

        return jsonResponse(
          {
            'error': 'Possible duplicate issue',
            'existingIssueId': existing['id'],
          },
          status: 409,
        );
      }
    }

    final issue = <String, dynamic>{
      'id': issueSequence++,
      'room': room,
      'title': title,
      'description': description,
      'category': category,
      'assignedTeam': teamFor(category),
      'status': 'assigned',
      'createdAt': now(),
      'updatedAt': now(),
      'escalated': false,
      'alertSent': false,
    };

    issues.add(issue);

    final requestedMode = body['deliveryMode'];

    final mode = {'normal', 'transient', 'permanent'}.contains(requestedMode)
        ? requestedMode.toString()
        : 'normal';

    enqueue(
      issue['id'] as int,
      'assigned',
      deliveryMode: mode,
    );

    logEvent('issue_created_and_routed', {
      'issueId': issue['id'],
      'team': issue['assignedTeam'],
    });

    return jsonResponse(issue, status: 201);
  });

  // UPDATE ISSUE STATUS
  router.patch('/issues/<id>', (
    Request request,
    String id,
  ) async {
    final issue = findIssue(id);

    if (issue == null) {
      return jsonResponse(
        {'error': 'Issue not found'},
        status: 404,
      );
    }

    final body = await readMap(request);
    final status = body?['status'];

    const transitions = {
      'assigned': {'in_progress'},
      'in_progress': {'resolved'},
      'resolved': {'closed', 'in_progress'},
      'closed': <String>{},
    };

    if (status is! String ||
        !(transitions[issue['status']] ?? <String>{}).contains(status)) {
      return jsonResponse(
        {'error': 'Invalid status transition'},
        status: 400,
      );
    }

    issue['status'] = status;
    issue['updatedAt'] = now();

    logEvent('issue_status_changed', {
      'issueId': issue['id'],
      'status': status,
    });

    enqueue(issue['id'] as int, 'status_$status');

    return jsonResponse(issue);
  });

  // NOTIFICATIONS
  router.get('/notifications', (Request request) {
    return jsonResponse(notifications);
  });

  // AUDIT LOGS
  router.get('/logs', (Request request) {
    return jsonResponse(audit);
  });

  // WORKER
  router.post('/worker/run', (Request request) async {
    processAging();
    await processQueue();

    return jsonResponse({
      'message': 'Worker completed',
      'notifications': notifications,
    });
  });

  // SUMMARY
  router.get('/summary', (Request request) {
    return jsonResponse({
      'total': issues.length,
      'unresolved': issues.where((x) => x['status'] != 'closed').length,
      'manualReview':
          notifications.where((x) => x['status'] == 'manual_review').length,
      'teams': [
        'Electrical Team',
        'Carpentry Team',
        'Custodial Team',
        'Facilities Team',
      ].map((team) {
        return {
          'team': team,
          'unresolved': issues
              .where(
                  (x) => x['assignedTeam'] == team && x['status'] != 'closed')
              .length,
        };
      }).toList(),
    });
  });

  // MIDDLEWARE
  final handler = Pipeline()
      .addMiddleware(corsMiddleware())
      .addMiddleware(authenticationMiddleware())
      .addMiddleware(logRequests())
      .addHandler(router.call);

  final server = await shelf_io.serve(
    handler,
    InternetAddress.loopbackIPv4,
    8080,
  );

  logEvent('backend_started', {
    'url': 'http://${server.address.host}:${server.port}',
  });

  Timer.periodic(const Duration(seconds: 5), (_) {
    processAging();
    processQueue();
  });

  Timer.periodic(const Duration(minutes: 1), (_) {
    logEvent('daily_summary_demo', {
      'unresolved': issues.where((x) => x['status'] != 'closed').length,
    });
  });
}

// ==================================================
// 10. CORS CONFIGURATION
// ==================================================

const corsHeaders = <String, String>{
  'access-control-allow-origin': 'http://localhost:3000',
  'access-control-allow-methods': 'GET,POST,PATCH,OPTIONS',
  'access-control-allow-headers': 'content-type,authorization',
};

Middleware corsMiddleware() {
  return (Handler inner) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: corsHeaders);
      }

      final response = await inner(request);

      return response.change(
        headers: {
          ...response.headers,
          ...corsHeaders,
        },
      );
    };
  };
}
