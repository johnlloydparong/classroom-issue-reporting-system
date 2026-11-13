import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

// Week 13 controlled-data prototype. Not intended for production use.
final issues = <Map<String, dynamic>>[];
final notifications = <Map<String, dynamic>>[];
final audit = <Map<String, dynamic>>[];
int issueSequence = 1;
int noticeSequence = 1;
const maxAttempts = 3;
const retryDelay = Duration(seconds: 5); // short for reproducible classroom demo

String now() => DateTime.now().toUtc().toIso8601String();
void logEvent(String event, Map<String, dynamic> detail) {
  final log = <String, dynamic>{'time': now(), 'event': event, ...detail};
  audit.add(log);
  stdout.writeln(jsonEncode(log));
}
Response jsonResponse(Object value, {int status = 200}) => Response(status,
    body: jsonEncode(value), headers: {'content-type': 'application/json'});
Map<String, dynamic>? findIssue(String id) {
  for (final issue in issues) {
    if (issue['id'].toString() == id) return issue;
  }
  return null;
}
String teamFor(String category) {
  switch (category) {
    case 'Electrical': return 'Electrical Team';
    case 'Furniture': return 'Carpentry Team';
    case 'Cleaning': return 'Custodial Team';
    default: return 'Facilities Team';
  }
}
void enqueue(int issueId, String type, {String deliveryMode = 'normal'}) {
  notifications.add({
    'id': noticeSequence++, 'issueId': issueId, 'type': type,
    'status': 'pending', 'attempts': 0, 'nextAttempt': now(),
    'deliveryMode': deliveryMode, 'lastError': null,
  });
  logEvent('notification_queued', {'issueId': issueId, 'type': type});
}
Future<void> processQueue() async {
  final current = DateTime.now().toUtc();
  for (final notification in notifications) {
    if (notification['status'] != 'pending' ||
        DateTime.parse(notification['nextAttempt'] as String).isAfter(current)) continue;
    notification['attempts'] = (notification['attempts'] as int) + 1;
    final attempts = notification['attempts'] as int;
    final mode = notification['deliveryMode'];
    final shouldFail = mode == 'permanent' || (mode == 'transient' && attempts == 1);
    if (shouldFail) {
      notification['lastError'] = mode == 'permanent'
          ? 'Simulated permanent recipient failure' : 'Simulated temporary service timeout';
      if (attempts >= maxAttempts) {
        notification['status'] = 'manual_review';
        logEvent('notification_manual_review', {'notificationId': notification['id'], 'attempt': attempts});
      } else {
        notification['nextAttempt'] = current.add(retryDelay).toIso8601String();
        logEvent('notification_retry_scheduled', {'notificationId': notification['id'], 'attempt': attempts});
      }
    } else {
      // Safe demo delivery to the in-app notification log, not real email/SMS.
      notification['status'] = 'delivered';
      notification['deliveredAt'] = now();
      notification['lastError'] = null;
      logEvent('notification_delivered', {'notificationId': notification['id'], 'attempt': attempts});
    }
  }
}
void processAging() {
  final current = DateTime.now().toUtc();
  for (final issue in issues) {
    if (issue['status'] == 'closed') continue;
    final age = current.difference(DateTime.parse(issue['createdAt'] as String));
    if (age.inSeconds >= 60 && issue['alertSent'] != true) {
      issue['alertSent'] = true;
      issue['escalated'] = true;
      enqueue(issue['id'] as int, 'aging_escalation');
      logEvent('issue_escalated', {'issueId': issue['id']});
    }
  }
}
Future<Map<String, dynamic>?> readMap(Request request) async {
  try {
    final data = jsonDecode(await request.readAsString());
    return data is Map<String, dynamic> ? data : null;
  } catch (_) { return null; }
}
Future<void> main() async {
  final router = Router();
  router.get('/health', (Request request) => jsonResponse({'status': 'ok', 'time': now()}));
  router.get('/issues', (Request request) => jsonResponse(issues));
  router.post('/issues', (Request request) async {
    final body = await readMap(request);
    if (body == null) return jsonResponse({'error': 'Invalid JSON object'}, status: 400);
    final room = (body['room'] ?? '').toString().trim();
    final title = (body['title'] ?? '').toString().trim();
    final description = (body['description'] ?? '').toString().trim();
    final category = (body['category'] ?? '').toString().trim();
    const categories = {'Electrical', 'Furniture', 'Cleaning', 'Other'};
    if (room.isEmpty || title.isEmpty || description.isEmpty || !categories.contains(category)) {
      return jsonResponse({'error': 'Room, title, description and valid category are required'}, status: 400);
    }
    // Simplified duplicate key: same room, title and category for a non-closed issue.
    for (final existing in issues) {
      if (existing['room'].toString().toLowerCase() == room.toLowerCase() &&
          existing['title'].toString().toLowerCase() == title.toLowerCase() &&
          existing['category'] == category && existing['status'] != 'closed') {
        logEvent('duplicate_blocked', {'existingIssueId': existing['id']});
        return jsonResponse({'error': 'Possible duplicate issue', 'existingIssueId': existing['id']}, status: 409);
      }
    }
    final issue = <String, dynamic>{
      'id': issueSequence++, 'room': room, 'title': title, 'description': description,
      'category': category, 'assignedTeam': teamFor(category), 'status': 'assigned',
      'createdAt': now(), 'updatedAt': now(), 'escalated': false, 'alertSent': false,
    };
    issues.add(issue);
    final requestedMode = body['deliveryMode'];
    final mode = {'normal', 'transient', 'permanent'}.contains(requestedMode)
        ? requestedMode.toString() : 'normal';
    enqueue(issue['id'] as int, 'assigned', deliveryMode: mode);
    logEvent('issue_created_and_routed', {'issueId': issue['id'], 'team': issue['assignedTeam']});
    return jsonResponse(issue, status: 201);
  });
  router.patch('/issues/<id>', (Request request, String id) async {
    final issue = findIssue(id);
    if (issue == null) return jsonResponse({'error': 'Issue not found'}, status: 404);
    final body = await readMap(request);
    final status = body?['status'];
    const transitions = {
      'assigned': {'in_progress'},
      'in_progress': {'resolved'},
      'resolved': {'closed', 'in_progress'},
      'closed': <String>{},
    };
    if (status is! String || !(transitions[issue['status']] ?? <String>{}).contains(status)) {
      return jsonResponse({'error': 'Invalid status transition'}, status: 400);
    }
    issue['status'] = status;
    issue['updatedAt'] = now();
    logEvent('issue_status_changed', {'issueId': issue['id'], 'status': status});
    enqueue(issue['id'] as int, 'status_$status');
    return jsonResponse(issue);
  });
  router.get('/notifications', (Request request) => jsonResponse(notifications));
  router.get('/logs', (Request request) => jsonResponse(audit));
  router.post('/worker/run', (Request request) async {
    processAging();
    await processQueue();
    return jsonResponse({'message': 'Worker completed', 'notifications': notifications});
  });
  router.get('/summary', (Request request) => jsonResponse({
    'total': issues.length,
    'unresolved': issues.where((x) => x['status'] != 'closed').length,
    'manualReview': notifications.where((x) => x['status'] == 'manual_review').length,
    'teams': ['Electrical Team', 'Carpentry Team', 'Custodial Team', 'Facilities Team']
        .map((team) => {'team': team, 'unresolved': issues.where((x) => x['assignedTeam'] == team && x['status'] != 'closed').length}).toList(),
  }));
  final handler = Pipeline().addMiddleware(logRequests()).addMiddleware((inner) => (request) async {
    if (request.method == 'OPTIONS') return Response.ok('', headers: corsHeaders);
    final result = await inner(request);
    return result.change(headers: {...result.headers, ...corsHeaders});
  }).addHandler(router.call);
  final server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, 8080);
  logEvent('backend_started', {'url': 'http://${server.address.host}:${server.port}'});
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
const corsHeaders = <String, String>{
  'access-control-allow-origin': 'http://localhost:3000',
  'access-control-allow-methods': 'GET,POST,PATCH,OPTIONS',
  'access-control-allow-headers': 'content-type',
};
