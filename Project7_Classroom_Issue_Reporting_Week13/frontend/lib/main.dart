import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// PROJECT 7 — CLASSROOM ISSUE REPORTING SYSTEM
// WEEK 14 — AUTHENTICATED FLUTTER WEB INTERFACE
// Controlled classroom demonstration only.

const api = 'http://127.0.0.1:8080';

void main() {
  runApp(const ClassroomApp());
}

class ClassroomApp extends StatelessWidget {
  const ClassroomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Classroom Issue Reporting',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF215B9A),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const IssuesPage(),
    );
  }
}

class IssuesPage extends StatefulWidget {
  const IssuesPage({super.key});

  @override
  State<IssuesPage> createState() => _IssuesPageState();
}

class _IssuesPageState extends State<IssuesPage> {
  // Login fields
  final username = TextEditingController();
  final password = TextEditingController();

  // Classroom issue fields
  final room = TextEditingController();
  final title = TextEditingController();
  final description = TextEditingController();

  String category = 'Electrical';
  String deliveryMode = 'normal';

  String? token;
  String role = '';
  String message = '';

  bool loading = false;
  bool hidePassword = true;
  bool sessionExpired = false;

  List<dynamic> issues = [];
  List<dynamic> notifications = [];
  Map<String, dynamic> summary = {};

  bool get isLoggedIn => token != null;

  bool get isAdmin => role == 'admin';

  bool get isReporter => role == 'reporter';

  bool get isStaff => role == 'staff';

  bool get canCreateIssue => isAdmin || isReporter;

  bool get canUpdateIssue => isAdmin || isStaff;

  bool get canViewNotifications => isAdmin || isStaff;

  bool get canRunWorker => isAdmin;

  Map<String, String> get authHeaders => {
        'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
      };

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    room.dispose();
    title.dispose();
    description.dispose();
    super.dispose();
  }

  void showMessage(String value) {
    if (!mounted) return;

    setState(() {
      message = value;
    });
  }

  // ------------------------------------------------
  // LOGIN
  // ------------------------------------------------

  Future<void> login() async {
    if (username.text.trim().isEmpty || password.text.isEmpty) {
      showMessage('Please enter your username and password.');
      return;
    }

    setState(() {
      loading = true;
      message = '';
    });

    try {
      final response = await http
          .post(
            Uri.parse('$api/login'),
            headers: {
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'username': username.text.trim(),
              'password': password.text,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        final receivedToken = data['token'];
        final receivedRole = data['role'];

        if (receivedToken is! String ||
            receivedToken.isEmpty ||
            receivedRole is! String) {
          showMessage('Invalid login response from server.');
          return;
        }

        setState(() {
          token = receivedToken;
          role = receivedRole;
          sessionExpired = false;
          message = 'Login successful. Welcome, $role!';
        });

        password.clear();

        await refresh();
      } else if (response.statusCode == 401) {
        showMessage('Invalid username or password.');
      } else {
        showMessage(
          'Login failed. Server returned '
          'HTTP ${response.statusCode}.',
        );
      }
    } catch (_) {
      showMessage(
        'Unable to connect to the login server. '
        'Check whether the Dart backend is running.',
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ------------------------------------------------
  // LOGOUT AND EXPIRED SESSION
  // ------------------------------------------------

  void logout({bool expired = false}) {
    setState(() {
      token = null;
      role = '';
      sessionExpired = expired;
      issues = [];
      notifications = [];
      summary = {};
      password.clear();

      message = expired
          ? 'Your session is invalid or has expired. '
              'Please log in again.'
          : 'You have logged out successfully.';
    });
  }

  bool handleAuthError(http.Response response) {
    if (response.statusCode == 401) {
      logout(expired: true);
      return true;
    }

    if (response.statusCode == 403) {
      showMessage(
        'Access denied. Your account is not allowed '
        'to perform this action.',
      );
      return true;
    }

    return false;
  }

  // ------------------------------------------------
  // GET ISSUES AND PERMITTED DATA
  // ------------------------------------------------

  Future<void> refresh() async {
    if (!isLoggedIn || loading && token == null) {
      return;
    }

    if (mounted) {
      setState(() => loading = true);
    }

    try {
      final requests = <Future<http.Response>>[
        http.get(
          Uri.parse('$api/issues'),
          headers: authHeaders,
        ),
      ];

      if (canViewNotifications) {
        requests.add(
          http.get(
            Uri.parse('$api/notifications'),
            headers: authHeaders,
          ),
        );

        requests.add(
          http.get(
            Uri.parse('$api/summary'),
            headers: authHeaders,
          ),
        );
      }

      final responses =
          await Future.wait(requests).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      for (final response in responses) {
        if (handleAuthError(response)) {
          return;
        }
      }

      if (responses.any((r) => r.statusCode != 200)) {
        showMessage('Unable to load some classroom records.');
        return;
      }

      final loadedIssues = jsonDecode(responses[0].body) as List<dynamic>;

      List<dynamic> loadedNotifications = [];
      Map<String, dynamic> loadedSummary = {};

      if (canViewNotifications) {
        loadedNotifications = jsonDecode(responses[1].body) as List<dynamic>;

        loadedSummary = jsonDecode(responses[2].body) as Map<String, dynamic>;
      }

      setState(() {
        issues = loadedIssues;
        notifications = loadedNotifications;
        summary = loadedSummary;
      });
    } catch (_) {
      showMessage(
        'Cannot load records. Check your connection '
        'and make sure the Dart backend is running.',
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ------------------------------------------------
  // CREATE CLASSROOM ISSUE
  // ------------------------------------------------

  Future<void> createIssue() async {
    if (!canCreateIssue) {
      showMessage('Your role cannot submit classroom issues.');
      return;
    }

    if (room.text.trim().isEmpty ||
        title.text.trim().isEmpty ||
        description.text.trim().isEmpty) {
      showMessage('Please complete all three text fields.');
      return;
    }

    if (room.text.trim().length > 80 ||
        title.text.trim().length > 120 ||
        description.text.trim().length > 1000) {
      showMessage(
        'Issue information exceeds the allowed length.',
      );
      return;
    }

    setState(() => loading = true);

    try {
      final response = await http
          .post(
            Uri.parse('$api/issues'),
            headers: authHeaders,
            body: jsonEncode({
              'room': room.text.trim(),
              'title': title.text.trim(),
              'description': description.text.trim(),
              'category': category,
              'deliveryMode': deliveryMode,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (handleAuthError(response)) return;

      if (response.statusCode == 201) {
        room.clear();
        title.clear();
        description.clear();

        await refresh();

        showMessage(
          'Issue submitted and assigned automatically.',
        );
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        showMessage(
          data['error']?.toString() ?? 'The issue could not be submitted.',
        );
      }
    } catch (_) {
      showMessage(
        'Issue submission failed. '
        'Check the backend connection.',
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  // ------------------------------------------------
  // UPDATE ISSUE STATUS — STAFF / ADMIN
  // ------------------------------------------------

  Future<void> changeStatus(
    Map<String, dynamic> issue,
    String next,
  ) async {
    if (!canUpdateIssue) {
      showMessage('Only staff or admin can update issues.');
      return;
    }

    setState(() => loading = true);

    try {
      final response = await http
          .patch(
            Uri.parse('$api/issues/${issue['id']}'),
            headers: authHeaders,
            body: jsonEncode({'status': next}),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (handleAuthError(response)) return;

      if (response.statusCode == 200) {
        await refresh();
        showMessage('Issue status updated to $next.');
      } else {
        showMessage(
          'Status update rejected: '
          'HTTP ${response.statusCode}.',
        );
      }
    } catch (_) {
      showMessage('Unable to update issue status.');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  // ------------------------------------------------
  // AUTOMATION WORKER — ADMIN ONLY
  // ------------------------------------------------

  Future<void> runWorker() async {
    if (!canRunWorker) {
      showMessage('Only administrators can run the worker.');
      return;
    }

    setState(() => loading = true);

    try {
      final response = await http
          .post(
            Uri.parse('$api/worker/run'),
            headers: authHeaders,
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (handleAuthError(response)) return;

      if (response.statusCode == 200) {
        await refresh();
        showMessage(
          'Worker executed. Review notification statuses.',
        );
      } else {
        showMessage('Worker execution was rejected.');
      }
    } catch (_) {
      showMessage('Worker request failed.');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  // ------------------------------------------------
  // LOGIN INTERFACE
  // ------------------------------------------------

  Widget buildLogin() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Classroom Issue Reporting · Week 14',
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 460,
            ),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.security,
                      size: 52,
                      color: Color(0xFF215B9A),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Secure Login',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Week 14 · Controlled demonstration',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: username,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: password,
                      obscureText: hidePassword,
                      onSubmitted: (_) {
                        if (!loading) login();
                      },
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              hidePassword = !hidePassword;
                            });
                          },
                          icon: Icon(
                            hidePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: loading ? null : login,
                      icon: const Icon(Icons.login),
                      label: const Text('Login'),
                    ),
                    if (loading) ...[
                      const SizedBox(height: 14),
                      const LinearProgressIndicator(),
                    ],
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: sessionExpired
                              ? Colors.red
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Text(
                      'Use only instructor-approved '
                      'demonstration accounts.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------
  // CLASSROOM ISSUE FORM
  // ------------------------------------------------

  Widget buildIssueForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report a classroom issue',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: room,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Room (example: CIT-201)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: title,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Issue title',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: description,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Description',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                DropdownButton<String>(
                  value: category,
                  items: [
                    'Electrical',
                    'Furniture',
                    'Cleaning',
                    'Other',
                  ].map((value) {
                    return DropdownMenuItem(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: loading
                      ? null
                      : (value) {
                          setState(() {
                            category = value ?? category;
                          });
                        },
                ),
                DropdownButton<String>(
                  value: deliveryMode,
                  items: const [
                    DropdownMenuItem(
                      value: 'normal',
                      child: Text('Normal delivery'),
                    ),
                    DropdownMenuItem(
                      value: 'transient',
                      child: Text(
                        'Simulate temporary failure',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'permanent',
                      child: Text(
                        'Simulate permanent failure',
                      ),
                    ),
                  ],
                  onChanged: loading
                      ? null
                      : (value) {
                          setState(() {
                            deliveryMode = value ?? deliveryMode;
                          });
                        },
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: loading ? null : createIssue,
              icon: const Icon(Icons.add),
              label: const Text('Submit issue'),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------
  // ISSUE LIST AND ROUTING
  // ------------------------------------------------

  Widget buildIssueList() {
    final narrow = MediaQuery.sizeOf(context).width < 740;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Issues and routing',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              onPressed: loading ? null : refresh,
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (issues.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No issues yet. Add a sample issue above.',
              ),
            ),
          ),
        ...issues.map((raw) {
          final issue = Map<String, dynamic>.from(
            raw as Map,
          );

          String? next;

          if (issue['status'] == 'assigned') {
            next = 'in_progress';
          }

          if (issue['status'] == 'in_progress') {
            next = 'resolved';
          }

          if (issue['status'] == 'resolved') {
            next = 'closed';
          }

          final nextStatus = next;

          return Card(
            child: ListTile(
              isThreeLine: true,
              title: Text(
                '#${issue['id']} · ${issue['title']}',
              ),
              subtitle: Text(
                '${issue['room']} · ${issue['category']} '
                '→ ${issue['assignedTeam']}\n'
                'Status: ${issue['status']} · '
                'Escalated: ${issue['escalated']}',
              ),
              trailing: !canUpdateIssue
                  ? const Icon(Icons.visibility_outlined)
                  : nextStatus == null
                      ? const Icon(
                          Icons.check_circle_outline,
                        )
                      : narrow
                          ? IconButton(
                              icon: const Icon(
                                Icons.arrow_forward,
                              ),
                              tooltip: nextStatus,
                              onPressed: loading
                                  ? null
                                  : () => changeStatus(
                                        issue,
                                        nextStatus,
                                      ),
                            )
                          : FilledButton.tonal(
                              onPressed: loading
                                  ? null
                                  : () => changeStatus(
                                        issue,
                                        nextStatus,
                                      ),
                              child: Text(
                                nextStatus.replaceAll(
                                  '_',
                                  ' ',
                                ),
                              ),
                            ),
            ),
          );
        }),
      ],
    );
  }

  // ------------------------------------------------
  // NOTIFICATION QUEUE
  // ------------------------------------------------

  Widget buildNotifications() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Notification delivery queue',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (canRunWorker)
              OutlinedButton(
                onPressed: loading ? null : runWorker,
                child: const Text('Run worker'),
              ),
          ],
        ),
        if (notifications.isEmpty) const Text('No notifications yet.'),
        ...notifications.map((raw) {
          final notice = Map<String, dynamic>.from(
            raw as Map,
          );

          return Card(
            child: ListTile(
              title: Text(
                '#${notice['id']} · '
                'Issue ${notice['issueId']} · '
                '${notice['type']}',
              ),
              subtitle: Text(
                'Status: ${notice['status']} · '
                'Attempts: ${notice['attempts']} / 3\n'
                '${notice['lastError'] ?? 'No error'}',
              ),
            ),
          );
        }),
      ],
    );
  }

  // ------------------------------------------------
  // AUTHENTICATED DASHBOARD
  // ------------------------------------------------

  Widget buildDashboard() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Classroom Issue Reporting · Week 14',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
            ),
            child: Center(
              child: Text(
                'Role: $role',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () => logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Facilities issue tracker',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Text(
              'Controlled sample records · '
              'Week 14 secure API integration',
            ),
            const SizedBox(height: 12),
            if (canViewNotifications)
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(
                      'Total issues: '
                      '${summary['total'] ?? 0}',
                    ),
                  ),
                  Chip(
                    label: Text(
                      'Unresolved: '
                      '${summary['unresolved'] ?? 0}',
                    ),
                  ),
                  Chip(
                    label: Text(
                      'Manual review: '
                      '${summary['manualReview'] ?? 0}',
                    ),
                  ),
                ],
              ),
            if (message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                ),
                child: Text(
                  message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            if (loading) const LinearProgressIndicator(),
            const SizedBox(height: 14),
            if (canCreateIssue) buildIssueForm(),
            const SizedBox(height: 14),
            buildIssueList(),
            const SizedBox(height: 12),
            if (canViewNotifications) buildNotifications(),
            const SizedBox(height: 18),
            const Text(
              'Controlled classroom prototype. '
              'Production HTTPS, persistent storage, '
              'and additional security hardening '
              'are not yet implemented.',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return isLoggedIn ? buildDashboard() : buildLogin();
  }
}
