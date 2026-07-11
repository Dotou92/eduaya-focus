import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/config_service.dart';

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

String fmtTime(DateTime t) =>
    "${t.hour.toString().padLeft(2, '0')}h${t.minute.toString().padLeft(2, '0')}";

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
    setState(() => _accessibilityGranted = granted);
    await _checkForInterruptedSession();
    await _loadHistory();
  }

  /// Détecte si une session était en cours mais que le service natif
  /// a été tué (app gelée/forcée à s'arrêter), puis relance le blocage
  /// et note l'interruption dans l'historique.
  Future<void> _checkForInterruptedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final inProgress = prefs.getBool('session_in_progress') ?? false;
    if (!inProgress) return;

    final status = await ConfigService.getSessionStatus();
    final active = status['active'] == true;
    final endTime = (status['endTime'] ?? 0) as int;
    final lastHeartbeat = (status['lastHeartbeat'] ?? 0) as int;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (endTime > now && !active) {
      // Interruption détectée : le service ne tourne plus alors que
      // la session n'était pas terminée.
      await _appendInterruption(lastHeartbeat);

      final endDt = DateTime.fromMillisecondsSinceEpoch(endTime);
      await ConfigService.startSession(endDt.hour, endDt.minute);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SessionScreen(endTime: endDt)),
      );
    } else if (endTime <= now) {
      await _finalizeSession(completed: true);
    }
  }

  Future<void> _appendInterruption(int lastHeartbeatMillis) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('current_session_record');
    if (raw == null) return;
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
    final list = raw
        .map((s) => Map<String, dynamic>.from(jsonDecode(s)))
        .toList()
        .reversed
        .toList();
    setState(() => _history = list);
  }

  @override
  Widget build(BuildContext context) {
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
          children: [
            const Text(
              "Concentration pendant vos sessions d'étude",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Choisissez une heure de fin, sélectionnez les applications "
              "à bloquer, puis démarrez votre session.",
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            if (!_accessibilityGranted) _buildPermissionCard(),
            if (_accessibilityGranted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_circle_fill),
                  label: const Text("Nouvelle session de concentration",
                      style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18)),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EndTimeScreen()),
                    );
                    _loadHistory();
                  },
                ),
              ),
            const SizedBox(height: 32),
            const Text("Historique des sessions",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_history.isEmpty)
              const Text("Aucune session enregistrée pour l'instant.",
                  style: TextStyle(color: Colors.black54)),
            ..._history.map(_buildHistoryTile),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  interruptions.isEmpty
                      ? (completed ? Icons.check_circle : Icons.access_time)
                      : Icons.warning_amber_rounded,
                  color: interruptions.isEmpty
                      ? (completed ? Colors.green : Colors.orange)
                      : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  "Session ${fmtTime(start)} - ${fmtTime(end)}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (interruptions.isEmpty)
              Text(completed ? "Terminée sans interruption" : "En cours",
                  style: const TextStyle(color: Colors.black54))
            else
              ...interruptions.map((millis) {
                final t = DateTime.fromMillisecondsSinceEpoch(millis);
                return Text(
                  "⚠️ Interruption détectée vers ${fmtTime(t)}",
                  style: const TextStyle(color: Colors.red),
                );
              }),
            const SizedBox(height: 6),
            Text(
              "Applications bloquées : ${apps.isEmpty ? 'aucune' : apps.join(', ')}",
              style: const TextStyle(fontSize: 12, color: Colors.black45),
            ),
          ],
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
            const Text("Permission requise",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              "Pour bloquer les applications, EduAya Focus a besoin de la "
              "permission d'accessibilité. Vous devez l'activer manuellement.",
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await ConfigService.openAccessibilitySettings();
                await Future.delayed(const Duration(seconds: 1));
                final granted =
                    await ConfigService.isAccessibilityServiceEnabled();
                setState(() => _accessibilityGranted = granted);
              },
              child: const Text("Ouvrir les réglages"),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------- CHOIX DE L'HEURE DE FIN -------------------

class EndTimeScreen extends StatelessWidget {
  const EndTimeScreen({super.key});

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
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.access_time),
                label: const Text("Choisir l'heure de fin"),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18)),
                onPressed: () async {
                  final now = TimeOfDay.now();
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: (now.hour + 1) % 24,
                      minute: now.minute,
                    ),
                  );
                  if (picked != null && context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AppSelectionScreen(endTime: picked),
                      ),
                    );
                  }
                },
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
  const AppSelectionScreen({super.key, required this.endTime});

  @override
  State<AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<AppSelectionScreen> {
  List<Map<String, String>> _apps = [];
  Set<String> _selected = {};
  bool _loading = true;

  static const List<String> _knownSocialKeywords = [
    'facebook', 'instagram', 'tiktok', 'musically', 'twitter', 'snapchat', 'youtube'
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
      if (_knownSocialKeywords.any((k) => pkg.contains(k) || name.contains(k))) {
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
    var end = DateTime(now.year, now.month, now.day, widget.endTime.hour, widget.endTime.minute);
    if (!end.isAfter(now)) {
      end = end.add(const Duration(days: 1));
    }
    return end;
  }

  Future<void> _startSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('blocked_apps', _selected.join(','));

    final selectedNames = _apps
        .where((a) => _selected.contains(a['packageName']))
        .map((a) => a['name'] ?? '')
        .toList();

    final start = DateTime.now();
    final end = _resolveEndDateTime();

    final record = {
      'start': start.millisecondsSinceEpoch,
      'end': end.millisecondsSinceEpoch,
      'appNames': selectedNames,
      'interruptions': <int>[],
      'completed': false,
    };
    await prefs.setString('current_session_record', jsonEncode(record));
    await prefs.setBool('session_in_progress', true);

    await ConfigService.startSession(widget.endTime.hour, widget.endTime.minute);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => SessionScreen(endTime: end)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final end = _resolveEndDateTime();
    return Scaffold(
      appBar: AppBar(title: const Text("Applications à bloquer")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: _selected.isEmpty ? null : _startSession,
                      child: const Text("Valider et démarrer",
                          style: TextStyle(fontSize: 16)),
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
  const SessionScreen({super.key, required this.endTime});

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
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
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
    if (!active && !_finished && DateTime.now().isBefore(widget.endTime)) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('current_session_record');
      if (raw != null) {
        final record = Map<String, dynamic>.from(jsonDecode(raw));
        final interruptions = List<int>.from(record['interruptions'] ?? []);
        interruptions.add(DateTime.now().millisecondsSinceEpoch);
        record['interruptions'] = interruptions;
        await prefs.setString('current_session_record', jsonEncode(record));
      }
      await ConfigService.startSession(
          TimeOfDay.fromDateTime(widget.endTime).hour,
          TimeOfDay.fromDateTime(widget.endTime).minute);
    }
  }

  Future<void> _onFinished() async {
    setState(() => _finished = true);
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

  String get _remainingText {
    final diff = widget.endTime.difference(DateTime.now());
    if (diff.isNegative) return "00:00";
    final m = diff.inMinutes.toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _finished,
      child: Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_finished) ...[
                const Icon(Icons.school, color: Colors.white, size: 64),
                const SizedBox(height: 20),
                Text(
                  "Session en cours jusqu'à ${fmtTime(widget.endTime)}",
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                ),
                const SizedBox(height: 12),
                Text(
                  _remainingText,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      fontWeight: Fo
