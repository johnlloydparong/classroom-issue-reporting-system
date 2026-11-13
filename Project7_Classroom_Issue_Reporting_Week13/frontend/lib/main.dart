import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const api = 'http://127.0.0.1:8080';
void main() => runApp(const ClassroomApp());

class ClassroomApp extends StatelessWidget {
  const ClassroomApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Classroom Issue Reporting', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF215B9A)),
    home: const IssuesPage(),
  );
}

class IssuesPage extends StatefulWidget {
  const IssuesPage({super.key});
  @override
  State<IssuesPage> createState() => _IssuesPageState();
}
class _IssuesPageState extends State<IssuesPage> {
  final room = TextEditingController();
  final title = TextEditingController();
  final description = TextEditingController();
  String category = 'Electrical';
  String deliveryMode = 'normal';
  bool loading = false;
  String message = '';
  List<dynamic> issues = [];
  List<dynamic> notifications = [];
  Map<String, dynamic> summary = {};
  @override
  void initState() { super.initState(); refresh(); }
  @override
  void dispose() { room.dispose(); title.dispose(); description.dispose(); super.dispose(); }
  Future<void> refresh() async {
    setState(() => loading = true);
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('$api/issues')), http.get(Uri.parse('$api/notifications')),
        http.get(Uri.parse('$api/summary')),
      ]);
      if (responses.any((r) => r.statusCode != 200)) throw Exception('Server response error');
      setState(() {
        issues = jsonDecode(responses[0].body) as List<dynamic>;
        notifications = jsonDecode(responses[1].body) as List<dynamic>;
        summary = jsonDecode(responses[2].body) as Map<String, dynamic>;
        message = '';
      });
    } catch (_) { setState(() => message = 'Cannot connect to the backend. Start Dart server on port 8080.'); }
    finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> createIssue() async {
    if ([room.text, title.text, description.text].any((x) => x.trim().isEmpty)) {
      setState(() => message = 'Please complete all three text fields.'); return;
    }
    setState(() => loading = true);
    try {
      final response = await http.post(Uri.parse('$api/issues'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'room': room.text, 'title': title.text, 'description': description.text,
          'category': category, 'deliveryMode': deliveryMode}));
      if (response.statusCode == 201) {
        room.clear(); title.clear(); description.clear();
        await refresh(); setState(() => message = 'Issue submitted and assigned automatically.');
      } else {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() => message = body['error'].toString());
      }
    } catch (_) { setState(() => message = 'Submission failed: check backend connectivity.'); }
    finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> changeStatus(Map<String, dynamic> issue, String next) async {
    try {
      final response = await http.patch(Uri.parse('$api/issues/${issue['id']}'),
        headers: {'content-type': 'application/json'}, body: jsonEncode({'status': next}));
      if (response.statusCode != 200) throw Exception('Update rejected');
      await refresh(); setState(() => message = 'Issue status updated to $next.');
    } catch (_) { setState(() => message = 'Update failed.'); }
  }
  Future<void> runWorker() async {
    try { await http.post(Uri.parse('$api/worker/run')); await refresh();
    setState(() => message = 'Worker executed. Review notification statuses.');
    } catch (_) { setState(() => message = 'Worker request failed.'); }
  }
  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 740;
    return Scaffold(appBar: AppBar(title: const Text('Classroom Issue Reporting · Week 13')),
      body: RefreshIndicator(onRefresh: refresh, child: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Facilities issue tracker', style: Theme.of(context).textTheme.headlineMedium),
        const Text('Controlled sample records only · Week 13 automation prototype'),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 8, children: [
          Chip(label: Text('Total issues: ${summary['total'] ?? 0}')),
          Chip(label: Text('Unresolved: ${summary['unresolved'] ?? 0}')),
          Chip(label: Text('Manual review: ${summary['manualReview'] ?? 0}')),
        ]),
        if (message.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.primary))),
        if (loading) const LinearProgressIndicator(),
        const SizedBox(height: 14),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Report a classroom issue', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          TextField(controller: room, decoration: const InputDecoration(labelText: 'Room (example: CIT-201)', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Issue title', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: description, maxLines: 2, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          Wrap(spacing: 16, runSpacing: 8, children: [
            DropdownButton<String>(value: category,
              items: ['Electrical', 'Furniture', 'Cleaning', 'Other'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => category = v ?? category)),
            DropdownButton<String>(value: deliveryMode,
              items: const [DropdownMenuItem(value: 'normal', child: Text('Normal delivery')),
              DropdownMenuItem(value: 'transient', child: Text('Simulate temporary failure')),
              DropdownMenuItem(value: 'permanent', child: Text('Simulate permanent failure'))],
              onChanged: (v) => setState(() => deliveryMode = v ?? deliveryMode)),
          ]),
          FilledButton.icon(onPressed: loading ? null : createIssue, icon: const Icon(Icons.add), label: const Text('Submit issue')),
        ]))),
        const SizedBox(height: 14),
        Row(children: [Expanded(child: Text('Issues and routing', style: Theme.of(context).textTheme.titleLarge)),
          IconButton(onPressed: refresh, icon: const Icon(Icons.refresh), tooltip: 'Refresh')]),
        if (issues.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No issues yet. Add a sample issue above.'))),
        ...issues.map((raw) {
          final issue = Map<String, dynamic>.from(raw as Map);
          String? next;
          if (issue['status'] == 'assigned') next = 'in_progress';
          if (issue['status'] == 'in_progress') next = 'resolved';
          if (issue['status'] == 'resolved') next = 'closed';
          final nextStatus = next;
          return Card(child: ListTile(isThreeLine: true,
            title: Text('#${issue['id']} · ${issue['title']}'),
            subtitle: Text('${issue['room']} · ${issue['category']} → ${issue['assignedTeam']}\nStatus: ${issue['status']} · Escalated: ${issue['escalated']}'),
            trailing: nextStatus == null ? const Icon(Icons.check_circle_outline)
              : narrow ? IconButton(icon: const Icon(Icons.arrow_forward), tooltip: nextStatus,
                  onPressed: () => changeStatus(issue, nextStatus))
                : FilledButton.tonal(onPressed: () => changeStatus(issue, nextStatus), child: Text(nextStatus.replaceAll('_', ' '))),
          ));
        }),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: Text('Notification delivery queue', style: Theme.of(context).textTheme.titleLarge)),
          OutlinedButton(onPressed: runWorker, child: const Text('Run worker'))]),
        if (notifications.isEmpty) const Text('No notifications yet.'),
        ...notifications.map((raw) { final n = Map<String, dynamic>.from(raw as Map); return Card(
          child: ListTile(title: Text('#${n['id']} · Issue ${n['issueId']} · ${n['type']}'),
          subtitle: Text('Status: ${n['status']} · Attempts: ${n['attempts']} / 3\n${n['lastError'] ?? 'No error'}')),
        ); }),
        const SizedBox(height: 18),
        const Text('Demo only: authentication, production storage and HTTPS belong to later approved milestones.'),
      ])));
  }
}
