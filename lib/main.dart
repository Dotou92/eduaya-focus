import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/ambient_sounds.dart';
import 'data/subjects.dart';
import 'services/badges.dart';
import 'services/challenges.dart';
import 'services/config_service.dart';
import 'services/focus_score.dart';
import 'services/goals.dart';
import 'services/motivation_coach.dart';
import 'services/planned_session.dart';
import 'services/planning_service.dart';
import 'services/session_summary.dart';
import 'services/sound_service.dart';
import 'services/weekly_report.dart';

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

List<Map<String, dynamic>> loadSessionHistory(SharedPreferences prefs) {
  final raw = prefs.getStringList('session_history') ?? [];
  return raw
      .map((s) => Map<String, dynamic>.from(jsonDecode(s)))
      .toList();
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
  StudyGoals _goals = StudyGoals.defaults;

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
    await _loadGoals();
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
      final personalBest =
          MotivationCoach.personalBestMinutes(loadSessionHistory(prefs));

      if (!mounted) {
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionScreen(
            endTime: endDt,
            subject: subject,
            personalBestMinutes: personalBest,
          ),
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

  Future<void> _loadGoals() async {
    final goals = await GoalsService.load();
    setState(() {
      _goals = goals;
    });
  }

  Future<void> _openGoalsScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GoalsScreen(goals: _goals)),
    );
    _loadGoals();
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
    children.add(_buildGoalsCard());
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
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: "Calendrier",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PlanningScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: "Mes objectifs",
            onPressed: _openGoalsScreen,
          ),
          IconButton(
            icon: const Icon(Icons.summarize_outlined),
            tooltip: "Rapport hebdomadaire",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WeeklyReportScreen()),
              );
            },
          ),
        ],
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

  Widget _buildGoalsCard() {
    final records = _history
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();
    final progress = GoalProgress.compute(records);

    final rows = [
      _GoalRow(
        label: "Aujourd'hui",
        progress: progress.todayHours,
        target: _goals.hoursPerDay,
        unit: 'h',
        decimals: 1,
      ),
      _GoalRow(
        label: 'Cette semaine',
        progress: progress.weekSessions.toDouble(),
        target: _goals.sessionsPerWeek.toDouble(),
        unit: 'séances',
        decimals: 0,
      ),
      _GoalRow(
        label: 'Jours sans interruption',
        progress: progress.cleanStreakDays.toDouble(),
        target: _goals.consecutiveDaysNoInterruption.toDouble(),
        unit: 'jours',
        decimals: 0,
      ),
    ];

    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Mes objectifs',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: _openGoalsScreen,
                  child: const Text('Modifier'),
                ),
              ],
            ),
            for (final row in rows) ...[
              row,
              const SizedBox(height: 8),
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

class _GoalRow extends StatelessWidget {
  final String label;
  final double progress;
  final double target;
  final String unit;
  final int decimals;

  const _GoalRow({
    required this.label,
    required this.progress,
    required this.target,
    required this.unit,
    required this.decimals,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = target <= 0 ? 0.0 : (progress / target).clamp(0.0, 1.0);
    final reached = progress >= target;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13)),
            ),
            Text(
              "${progress.toStringAsFixed(decimals)}/"
              "${target.toStringAsFixed(decimals)} $unit",
              style: TextStyle(
                fontSize: 12,
                color: reached ? Colors.deepOrange : Colors.black54,
                fontWeight: reached ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: Colors.orange[100],
            color: reached ? Colors.deepOrange : Colors.orange[300],
          ),
        ),
      ],
    );
  }
}

// ------------------- MES OBJECTIFS -------------------

class GoalsScreen extends StatefulWidget {
  final StudyGoals goals;
  const GoalsScreen({super.key, required this.goals});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  late double _hoursPerDay;
  late int _sessionsPerWeek;
  late int _consecutiveDays;

  @override
  void initState() {
    super.initState();
    _hoursPerDay = widget.goals.hoursPerDay;
    _sessionsPerWeek = widget.goals.sessionsPerWeek;
    _consecutiveDays = widget.goals.consecutiveDaysNoInterruption;
  }

  Future<void> _save() async {
    await GoalsService.save(StudyGoals(
      hoursPerDay: _hoursPerDay,
      sessionsPerWeek: _sessionsPerWeek,
      consecutiveDaysNoInterruption: _consecutiveDays,
    ));
    if (!mounted) {
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mes objectifs")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            "Heures d'étude par jour : ${_hoursPerDay.toStringAsFixed(1)} h",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Slider(
            value: _hoursPerDay,
            min: 0.5,
            max: 8,
            divisions: 15,
            label: "${_hoursPerDay.toStringAsFixed(1)} h",
            onChanged: (value) => setState(() => _hoursPerDay = value),
          ),
          const SizedBox(height: 16),
          Text(
            "Séances par semaine : $_sessionsPerWeek",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Slider(
            value: _sessionsPerWeek.toDouble(),
            min: 1,
            max: 21,
            divisions: 20,
            label: "$_sessionsPerWeek",
            onChanged: (value) =>
                setState(() => _sessionsPerWeek = value.round()),
          ),
          const SizedBox(height: 16),
          Text(
            "Jours sans interruption consécutifs : $_consecutiveDays",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Slider(
            value: _consecutiveDays.toDouble(),
            min: 1,
            max: 30,
            divisions: 29,
            label: "$_consecutiveDays",
            onChanged: (value) =>
                setState(() => _consecutiveDays = value.round()),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text("Enregistrer"),
            ),
          ),
        ],
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

    final personalBest =
        MotivationCoach.personalBestMinutes(loadSessionHistory(prefs));

    await ConfigService.startSession(
        widget.endTime.hour, widget.endTime.minute);

    if (!mounted) {
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SessionScreen(
          endTime: end,
          subject: widget.subject,
          personalBestMinutes: personalBest,
        ),
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
  final int? personalBestMinutes;
  const SessionScreen({
    super.key,
    required this.endTime,
    required this.subject,
    this.personalBestMinutes,
  });

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _finished = false;
  List<String> _blockedAppNames = [];
  AmbientSound? _selectedSound;
  double _soundVolume = 0.5;
  DateTime? _startTime;
  bool _hadInterruptionThisSession = false;
  final Set<CoachTrigger> _triggeredCoachMessages = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSessionRecord();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tick();
    });
  }

  Future<void> _loadSessionRecord() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('current_session_record');
    if (raw != null) {
      final record = Map<String, dynamic>.from(jsonDecode(raw));
      final interruptions = List<int>.from(record['interruptions'] ?? []);
      setState(() {
        _blockedAppNames = List<String>.from(record['appNames'] ?? []);
        _startTime = DateTime.fromMillisecondsSinceEpoch(record['start']);
        _hadInterruptionThisSession = interruptions.isNotEmpty;
      });
    }
  }

  void _tick() {
    if (DateTime.now().isAfter(widget.endTime)) {
      _timer?.cancel();
      _onFinished();
    } else {
      _checkCoachTriggers();
      setState(() {});
    }
  }

  void _checkCoachTriggers() {
    final start = _startTime;
    if (start == null) {
      return;
    }
    final trigger = MotivationCoach.checkTriggers(
      start: start,
      end: widget.endTime,
      now: DateTime.now(),
      hasInterruptionThisSession: _hadInterruptionThisSession,
      personalBestMinutes: widget.personalBestMinutes,
      alreadyTriggered: _triggeredCoachMessages,
    );
    if (trigger == null) {
      return;
    }
    _triggeredCoachMessages.add(trigger);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(MotivationCoach.messages[trigger]!),
      duration: const Duration(seconds: 4),
    ));
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
      _hadInterruptionThisSession = true;
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
    await SoundService.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    SoundService.stop();
    super.dispose();
  }

  Future<void> _selectSound(AmbientSound? sound) async {
    if (sound == null) {
      await SoundService.stop();
      setState(() {
        _selectedSound = null;
      });
      return;
    }

    final ok = await SoundService.play(sound.assetPath, volume: _soundVolume);
    if (!mounted) {
      return;
    }
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          "Fichier audio introuvable pour \"${sound.label}\" "
          "(voir assets/sounds/README.md).",
        ),
      ));
      return;
    }
    setState(() {
      _selectedSound = sound;
    });
  }

  void _openSoundPicker() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Ambiance sonore",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    RadioListTile<AmbientSound?>(
                      title: const Text("Aucun son"),
                      value: null,
                      groupValue: _selectedSound,
                      onChanged: (value) {
                        _selectSound(value);
                        setSheetState(() {});
                      },
                    ),
                    for (final sound in ambientSounds)
                      RadioListTile<AmbientSound?>(
                        title: Text(sound.label),
                        value: sound,
                        groupValue: _selectedSound,
                        onChanged: (value) {
                          _selectSound(value);
                          setSheetState(() {});
                        },
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.volume_down),
                        Expanded(
                          child: Slider(
                            value: _soundVolume,
                            onChanged: (value) {
                              setState(() {
                                _soundVolume = value;
                              });
                              setSheetState(() {});
                              SoundService.setVolume(value);
                            },
                          ),
                        ),
                        const Icon(Icons.volume_up),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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

    content.add(const SizedBox(height: 8));
    content.add(Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _selectedSound == null ? Icons.music_off : Icons.music_note,
          color: Colors.white60,
          size: 16,
        ),
        const SizedBox(width: 6),
        Text(
          _selectedSound?.label ?? "Aucune ambiance sonore",
          style: const TextStyle(color: Colors.white60, fontSize: 13),
        ),
      ],
    ));

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
        floatingActionButton: _finished
            ? null
            : FloatingActionButton(
                onPressed: _openSoundPicker,
                tooltip: "Ambiance sonore",
                child: Icon(
                  _selectedSound == null ? Icons.music_off : Icons.music_note,
                ),
              ),
      ),
    );
  }
}

// ------------------- CALENDRIER -------------------

class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  DateTime _selectedDay = DateTime.now();
  List<PlannedSession> _sessions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await PlanningService.load();
    setState(() {
      _sessions = sessions;
    });
  }

  List<PlannedSession> get _sessionsForSelectedDay {
    final list = _sessions
        .where((s) =>
            s.dateTime.year == _selectedDay.year &&
            s.dateTime.month == _selectedDay.month &&
            s.dateTime.day == _selectedDay.day)
        .toList();
    list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return list;
  }

  Future<void> _addSession() async {
    final result = await showModalBottomSheet<PlannedSession>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddPlannedSessionSheet(day: _selectedDay),
    );
    if (result != null) {
      await PlanningService.add(result);
      _load();
    }
  }

  Future<void> _removeSession(PlannedSession session) async {
    await PlanningService.remove(session.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final daySessions = _sessionsForSelectedDay;

    return Scaffold(
      appBar: AppBar(title: const Text('Calendrier')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSession,
        tooltip: 'Planifier une séance',
        child: const Icon(Icons.add),
      ),
      body: ListView(
        children: [
          CalendarDatePicker(
            initialDate: _selectedDay,
            firstDate: DateTime.now().subtract(const Duration(days: 365)),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            onDateChanged: (date) {
              setState(() {
                _selectedDay = date;
              });
            },
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              "Séances du "
              "${_selectedDay.day.toString().padLeft(2, '0')}/"
              "${_selectedDay.month.toString().padLeft(2, '0')}/"
              "${_selectedDay.year}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          if (daySessions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                "Aucune séance planifiée ce jour-là.",
                style: TextStyle(color: Colors.black54),
              ),
            )
          else
            for (final session in daySessions)
              ListTile(
                leading: const Icon(Icons.event_note),
                title: Text(session.subject),
                subtitle: Text(
                  "${fmtTime(session.dateTime)} • ${session.durationMinutes} min",
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _removeSession(session),
                ),
              ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _AddPlannedSessionSheet extends StatefulWidget {
  final DateTime day;
  const _AddPlannedSessionSheet({required this.day});

  @override
  State<_AddPlannedSessionSheet> createState() =>
      _AddPlannedSessionSheetState();
}

class _AddPlannedSessionSheetState extends State<_AddPlannedSessionSheet> {
  String _subject = subjectsList.first;
  TimeOfDay _time = TimeOfDay.now();
  int _durationMinutes = 50;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) {
      setState(() {
        _time = picked;
      });
    }
  }

  void _confirm() {
    final dateTime = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      _time.hour,
      _time.minute,
    );
    Navigator.pop(
      context,
      PlannedSession(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        subject: _subject,
        dateTime: dateTime,
        durationMinutes: _durationMinutes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Planifier une séance",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _subject,
            decoration: const InputDecoration(labelText: "Matière"),
            items: [
              for (final s in subjectsList)
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: (value) {
              setState(() {
                _subject = value ?? _subject;
              });
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Heure"),
            trailing: Text(_time.format(context)),
            onTap: _pickTime,
          ),
          const SizedBox(height: 12),
          Text("Durée : $_durationMinutes min"),
          Slider(
            value: _durationMinutes.toDouble(),
            min: 15,
            max: 180,
            divisions: 33,
            label: "$_durationMinutes min",
            onChanged: (value) {
              setState(() {
                _durationMinutes = value.round();
              });
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirm,
              child: const Text("Planifier"),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------- RAPPORT HEBDOMADAIRE -------------------

class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  final GlobalKey _reportKey = GlobalKey();
  WeeklyReport? _report;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final records = loadSessionHistory(prefs);
    setState(() {
      _report = WeeklyReport.compute(records);
    });
  }

  Future<void> _share() async {
    setState(() {
      _sharing = true;
    });
    try {
      final boundary = _reportKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/rapport_hebdo_eduaya_focus.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Mon rapport hebdomadaire EduAya Focus',
      );
    } finally {
      if (mounted) {
        setState(() {
          _sharing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return Scaffold(
      appBar: AppBar(title: const Text("Rapport hebdomadaire")),
      body: report == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                RepaintBoundary(
                  key: _reportKey,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(20),
                    child: _buildReportContent(report),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share),
                    label: Text(_sharing ? "Préparation..." : "Partager"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _sharing ? null : _share,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildReportContent(WeeklyReport report) {
    final subjects = report.subjectMinutes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "EduAya Focus",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.indigo,
          ),
        ),
        Text(
          "Rapport du ${_fmtDate(report.weekStart)} au "
          "${_fmtDate(report.weekEnd)}",
          style: const TextStyle(color: Colors.black54, fontSize: 13),
        ),
        const SizedBox(height: 20),
        _reportStat(
          "Temps d'étude total",
          "${report.totalHours.toStringAsFixed(1)} h",
        ),
        _reportStat(
          "Taux de concentration",
          "${report.concentrationRatePercent.round()} %",
        ),
        _reportStat(
          "Distractions interceptées",
          "${report.distractionsIntercepted}",
        ),
        const SizedBox(height: 16),
        const Text(
          "Répartition par matière",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (subjects.isEmpty)
          const Text(
            "Aucune session cette semaine.",
            style: TextStyle(color: Colors.black54),
          )
        else
          for (final entry in subjects)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                "• ${entry.key} : ${(entry.value / 60).toStringAsFixed(1)} h",
              ),
            ),
        if (report.mostBlockedApps.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            "Applications les plus bloquées",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (final entry in report.mostBlockedApps)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                "• ${entry.key} (${entry.value} session"
                "${entry.value > 1 ? 's' : ''})",
              ),
            ),
        ],
      ],
    );
  }

  Widget _reportStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    return "${d.day.toString().padLeft(2, '0')}/"
        "${d.month.toString().padLeft(2, '0')}";
  }
}
