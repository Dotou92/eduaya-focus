import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/subjects.dart';
import 'services/badges.dart';
import 'services/challenges.dart';
import 'services/config_service.dart';
import 'services/focus_score.dart';
import 'services/session_summary.dart';

void main() {
  runApp(const EduAyoFocusApp());
}

class EduAyoFocusApp extends StatelessWidget {
  const EduAyoFocusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduAya Focus',
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

String fmtTime(DateTime t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return "${h}h$m";
}

// ------------------- ACCUEIL -------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _accessibilityGranted = false;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final granted = await ConfigService.isAccessibilityServiceEnabled();
    setState(() {
      _accessibilityGranted = granted;
    });
    await _checkForInterruptedSession();
    await _loadHistory();
  }

  Future<void> _checkForInterruptedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final inProgress = prefs.getBool('session_in_progress') ?? false;
    if (!inProgress) {
      return;
    }

    final status = await ConfigService.getSessionStatus();
    final active = status['active'] == true;
    final endTime = (status['endTime'] ?? 0) as int;
    final lastHeartbeat = (status['lastHeartbeat'] ?? 0) as int;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (endTime > now && !active) {
      await _appendInterruption(lastHeartbeat);
      final endDt = DateTime.fromMillisecondsSinceEpoch(endTime);
      await ConfigService.startSession(endDt.hour, endDt.minute);

      final raw = prefs.getString('current_session_record');
      final subject = raw == null
          ? 'Non précisé'
          : (Map<String, dynamic>.from(jsonDecode(raw))['subject']
                  as String?) ??
              'Non précisé';

      if (!mounted) {
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionScreen(endTime: endDt, subject: subject),
        ),
      );
    } else if (endTime > 0 && endTime <= now) {
      await _finalizeSession(completed: true);
    }
  }

  Future<void> _appendInterruption(int lastHeartbeatMillis) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('current_session_record');
    if (raw == null) {
      return;
    }
    final record = Map<String, dynamic>.from(jsonDecode(raw));
    final interruptions = List<int>.from(record['interruptions'] ?? []);
    interruptions.add(lastHeartbeatMillis);
    record['interruptions'] = interruptions;
    await prefs.setString('current_session_record', jsonEncode(record));
  }

  Future<void> _finalizeSession({required bool completed}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('current_session_record');
    if (raw != null) {
      final record = Map<String, dynamic>.from(jsonDecode(raw));
      record['completed'] = completed;
      final historyRaw = prefs.getStringList('session_history') ?? [];
      historyRaw.add(jsonEncode(record));
      await prefs.setStringList('session_history', historyRaw);
      await prefs.remove('current_session_record');
    }
    await prefs.setBool('session_in_progress', false);
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('session_history') ?? [];
    final list = <Map<String, dynamic>>[];
    for (final s in raw) {
      list.add(Map<String, dynamic>.from(jsonDecode(s)));
    }
    final reversed = list.reversed.toList();
    setState(() {
      _history = reversed;
    });
  }

  Future<void> _startNewSession() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SubjectSelectionScreen()),
    );
    _loadHistory();
  }

  Future<void> _grantPermission() async {
    await ConfigService.openAccessibilitySettings();
    await Future.delayed(const Duration(seconds: 1));
    final granted = await ConfigService.isAccessibilityServiceEnabled();
    setState(() {
      _accessibilityGranted = granted;
    });
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    children.add(const Text(
      "Concentration pendant vos sessions d'étude",
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    ));
    children.add(const SizedBox(height: 8));
    children.add(const Text(
      "Choisissez une heure de fin, sélectionnez les applications à "
      "bloquer, puis démarrez votre session.",
      style: TextStyle(color: Colors.black54),
    ));
    children.add(const SizedBox(height: 16));
    children.add(_buildFocusScoreCard());
    children.add(const SizedBox(height: 12));
    children.add(_buildChallengesCard());
    children.add(const SizedBox(height: 12));
    children.add(_buildSummaryCard());
    children.add(const SizedBox(height: 24));

    if (!_accessibilityGranted) {
      children.add(_buildPermissionCard());
    } else {
      children.add(SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.play_circle_fill),
          label: const Text(
            "Nouvelle session de concentration",
            style: TextStyle(fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
          ),
          onPressed: _startNewSession,
        ),
      ));
    }

    children.add(const SizedBox(height: 32));
    children.add(const Text(
      "Historique des sessions",
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ));
    children.add(const SizedBox(height: 12));

    if (_history.isEmpty) {
      children.add(const Text(
        "Aucune session enregistrée pour l'instant.",
        style: TextStyle(color: Colors.black54),
      ));
    } else {
      for (final record in _history) {
        children.add(_buildHistoryTile(record));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('EduAya Focus'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: children,
        ),
      ),
    );
  }

  Widget _buildFocusScoreCard() {
    final records = _history
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();
    final score = FocusScore.compute(records);
    final stats = SessionStats.fromRecords(records);
    final badges = BadgeEvaluator.evaluate(
      weeklyScore: score,
      recentWeeklyScores: FocusScore.weeklyHistory(records),
      totalCompletedSessions: stats.completedSessions,
    );

    return Card(
      color: Colors.deepPurple[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Indice Focus (7 derniers jours)",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  "${score.overall.round()}/100",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Concentration ${score.concentration.round()}% • "
              "Régularité ${score.regularity.round()}% • "
              "Persévérance ${score.perseverance.round()}%",
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            if (badges.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: badges
                    .map((b) => Chip(
                          avatar: const Icon(Icons.emoji_events, size: 18),
                          label: Text(b.label),
                          backgroundColor: Colors.amber[100],
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChallengesCard() {
    final records = _history
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();
    final challenges = ChallengeEvaluator.evaluate(records);

    return Card(
      color: Colors.teal[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Défis en cours",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            for (final challenge in challenges) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      challenge.label,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    "${challenge.progress.toStringAsFixed(challenge.unit == 'h' ? 1 : 0)}"
                    "/${challenge.target.toStringAsFixed(0)} ${challenge.unit}",
                    style: TextStyle(
                      fontSize: 12,
                      color: challenge.isCompleted
                          ? Colors.teal
                          : Colors.black54,
                      fontWeight: challenge.isCompleted
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: challenge.progressRatio,
                  minHeight: 6,
                  backgroundColor: Colors.teal[100],
                  color: challenge.isCompleted ? Colors.teal : Colors.teal[300],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final stats = SessionStats.fromRecords(
      _history
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList(),
    );

    return Card(
      color: Colors.indigo[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Résumé de votre semaine",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "${stats.totalSessions} session${stats.totalSessions > 1 ? 's' : ''} • "
              "${stats.completedSessions} réussie${stats.completedSessions > 1 ? 's' : ''} • "
              "${stats.interruptedSessions} interruption${stats.interruptedSessions > 1 ? 's' : ''}",
            ),
            const SizedBox(height: 6),
            Text(
              "Taux de réussite : ${stats.completionRatePercent.toStringAsFixed(0)}%",
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> record) {
    final start = DateTime.fromMillisecondsSinceEpoch(record['start']);
    final end = DateTime.fromMillisecondsSinceEpoch(record['end']);
    final completed = record['completed'] == true;
    final interruptions = List<int>.from(record['interruptions'] ?? []);
    final apps = List<String>.from(record['appNames'] ?? []);
    final subject = (record['subject'] as String?) ?? 'Non précisé';

    IconData icon;
    Color color;
    if (interruptions.isNotEmpty) {
      icon = Icons.warning_amber_rounded;
      color = Colors.red;
    } else if (completed) {
      icon = Icons.check_circle;
      color = Colors.green;
    } else {
      icon = Icons.access_time;
      color = Colors.orange;
    }

    final innerChildren = <Widget>[];
    innerChildren.add(Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(
          "$subject · ${fmtTime(start)} - ${fmtTime(end)}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    ));
    innerChildren.add(const SizedBox(height: 4));

    if (interruptions.isEmpty) {
      final label = completed ? "Terminée sans interruption" : "En cours";
      innerChildren.add(Text(
        label,
        style: const TextStyle(color: Colors.black54),
      ));
    } else {
      for (final millis in interruptions) {
        final t = DateTime.fromMillisecondsSinceEpoch(millis);
        innerChildren.add(Text(
          "Interruption détectée vers ${fmtTime(t)}",
          style: const TextStyle(color: Colors.red),
        ));
      }
    }

    innerChildren.add(const SizedBox(height: 6));
    final appsLabel = apps.isEmpty ? 'aucune' : apps.join(', ');
    innerChildren.add(Text(
      "Applications bloquées : $appsLabel",
      style: const TextStyle(fontSize: 12, color: Colors.black45),
    ));

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: innerChildren,
        ),
      ),
    );
  }

  Widget _buildPermissionCard() {
    return Card(
      color: Colors.amber[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Permission requise",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Pour bloquer les applications, EduAya Focus a besoin de la "
              "permission d'accessibilité. Vous devez l'activer manuellement.",
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _grantPermission,
              child: const Text("Ouvrir les réglages"),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------- CHOIX DE LA MATIERE -------------------

class SubjectSelectionScreen extends StatelessWidget {
  const SubjectSelectionScreen({super.key});

  void _selectSubject(BuildContext context, String subject) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EndTimeScreen(subject: subject)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Quelle matière ?")),
      body: ListView.builder(
        itemCount: subjectsList.length,
        itemBuilder: (context, index) {
          final subject = subjectsList[index];
          return ListTile(
            title: Text(subject),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _selectSubject(context, subject),
          );
        },
      ),
    );
  }
}

// ------------------- CHOIX DE L'HEURE DE FIN -------------------

class EndTimeScreen extends StatelessWidget {
  final String subject;
  const EndTimeScreen({super.key, required this.subject});

  Future<void> _pickTime(BuildContext context) async {
    final now = TimeOfDay.now();
    final initial = TimeOfDay(hour: (now.hour + 1) % 24, minute: now.minute);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AppSelectionScreen(endTime: picked, subject: subject),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Heure de fin de session")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Jusqu'à quelle heure voulez-vous étudier ?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Choisissez une heure réaliste pour rester concentré sans vous surcharger.",
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.access_time),
                label: const Text("Choisir l'heure de fin"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                onPressed: () => _pickTime(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------- SELECTION DES APPS -------------------

class AppSelectionScreen extends StatefulWidget {
  final TimeOfDay endTime;
  final String subject;
  const AppSelectionScreen({
    super.key,
    required this.endTime,
    required this.subject,
  });

  @override
  State<AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<AppSelectionScreen> {
  List<Map<String, String>> _apps = [];
  Set<String> _selected = {};
  bool _loading = true;

  static const List<String> _knownSocialKeywords = [
    'facebook',
    'instagram',
    'tiktok',
    'musically',
    'twitter',
    'snapchat',
    'youtube',
  ];

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    final apps = await ConfigService.getInstalledApps();
    final preselected = <String>{};
    for (final app in apps) {
      final pkg = (app['packageName'] ?? '').toLowerCase();
      final name = (app['name'] ?? '').toLowerCase();
      var matches = false;
      for (final k in _knownSocialKeywords) {
        if (pkg.contains(k) || name.contains(k)) {
          matches = true;
          break;
        }
      }
      if (matches) {
        preselected.add(app['packageName']!);
      }
    }
    setState(() {
      _apps = apps;
      _selected = preselected;
      _loading = false;
    });
  }

  DateTime _resolveEndDateTime() {
    final now = DateTime.now();
    var end = DateTime(
      now.year,
      now.month,
      now.day,
      widget.endTime.hour,
      widget.endTime.minute,
    );
    if (!end.isAfter(now)) {
      end = end.add(const Duration(days: 1));
    }
    return end;
  }

  Future<void> _startSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('blocked_apps', _selected.join(','));

    final selectedNames = <String>[];
    for (final a in _apps) {
      if (_selected.contains(a['packageName'])) {
        selectedNames.add(a['name'] ?? '');
      }
    }

    final start = DateTime.now();
    final end = _resolveEndDateTime();

    final record = <String, dynamic>{
      'start': start.millisecondsSinceEpoch,
      'end': end.millisecondsSinceEpoch,
      'subject': widget.subject,
      'appNames': selectedNames,
      'interruptions': <int>[],
      'completed': false,
    };
    await prefs.setString('current_session_record', jsonEncode(record));
    await prefs.setBool('session_in_progress', true);

    await ConfigService.startSession(
        widget.endTime.hour, widget.endTime.minute);

    if (!mounted) {
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SessionScreen(endTime: end, subject: widget.subject),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final end = _resolveEndDateTime();

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Applications à bloquer")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Applications à bloquer")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              "${_selected.length} application(s) sélectionnée(s) — "
              "session jusqu'à ${fmtTime(end)}",
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _apps.length,
              itemBuilder: (context, index) {
                final app = _apps[index];
                final pkg = app['packageName']!;
                return CheckboxListTile(
                  title: Text(app['name'] ?? pkg),
                  value: _selected.contains(pkg),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selected.add(pkg);
                      } else {
                        _selected.remove(pkg);
                      }
                    });
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _selected.isEmpty ? null : _startSession,
                child: const Text(
                  "Valider et démarrer",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------- ECRAN SESSION VERROUILLEE -------------------

class SessionScreen extends StatefulWidget {
  final DateTime endTime;
  final String subject;
  const SessionScreen({
    super.key,
    required this.endTime,
    required this.subject,
  });

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _finished = false;
  List<String> _blockedAppNames = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBlockedAppNames();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tick();
    });
  }

  Future<void> _loadBlockedAppNames() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('current_session_record');
    if (raw != null) {
      final record = Map<String, dynamic>.from(jsonDecode(raw));
      setState(() {
        _blockedAppNames = List<String>.from(record['appNames'] ?? []);
      });
    }
  }

  void _tick() {
    if (DateTime.now().isAfter(widget.endTime)) {
      _timer?.cancel();
      _onFinished();
    } else {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkInterruptionOnResume();
    }
  }

  Future<void> _checkInterruptionOnResume() async {
    final status = await ConfigService.getSessionStatus();
    final active = status['active'] == true;
    final isBeforeEnd = DateTime.now().isBefore(widget.endTime);

    if (!active && !_finished && isBeforeEnd) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('current_session_record');
      if (raw != null) {
        final record = Map<String, dynamic>.from(jsonDecode(raw));
        final interruptions = List<int>.from(record['interruptions'] ?? []);
        interruptions.add(DateTime.now().millisecondsSinceEpoch);
        record['interruptions'] = interruptions;
        await prefs.setString('current_session_record', jsonEncode(record));
      }
      final endAsTime = TimeOfDay.fromDateTime(widget.endTime);
      await ConfigService.startSession(endAsTime.hour, endAsTime.minute);
    }
  }

  Future<void> _onFinished() async {
    setState(() {
      _finished = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('current_session_record');
    if (raw != null) {
      final record = Map<String, dynamic>.from(jsonDecode(raw));
      record['completed'] = true;
      final historyRaw = prefs.getStringList('session_history') ?? [];
      historyRaw.add(jsonEncode(record));
      await prefs.setStringList('session_history', historyRaw);
      await prefs.remove('current_session_record');
    }
    await prefs.setBool('session_in_progress', false);
    await ConfigService.stopSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  String _remainingText() {
    final diff = widget.endTime.difference(DateTime.now());
    if (diff.isNegative) {
      return "00:00";
    }
    final m = diff.inMinutes.toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  Widget _buildActiveContent() {
    final content = <Widget>[];
    content.add(const Icon(Icons.school, color: Colors.white, size: 64));
    content.add(const SizedBox(height: 20));
    content.add(Text(
      widget.subject,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ));
    content.add(const SizedBox(height: 4));
    content.add(Text(
      "Session en cours jusqu'à ${fmtTime(widget.endTime)}",
      style: const TextStyle(color: Colors.white70, fontSize: 18),
    ));
    content.add(const SizedBox(height: 12));
    content.add(Text(
      _remainingText(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 56,
        fontWeight: FontWeight.bold,
      ),
    ));
    content.add(const SizedBox(height: 24));

    if (_blockedAppNames.isNotEmpty) {
      content.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Text(
          "Bloquées : ${_blockedAppNames.join(', ')}",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60, fontSize: 13),
        ),
      ));
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: content,
    );
  }

  Widget _buildFinishedContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 72),
        const SizedBox(height: 24),
        const Text(
          "Bravo, session terminée !",
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          child: const Text("Retour à l'accueil"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _finished,
      child: Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        body: Center(
          child: _finished ? _buildFinishedContent() : _buildActiveContent(),
        ),
      ),
    );
  }
}
