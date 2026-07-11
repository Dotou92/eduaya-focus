import 'dart:async';
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
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ------------------- ECRAN D'ACCUEIL -------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _accessibilityGranted = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final granted = await ConfigService.isAccessibilityServiceEnabled();
    setState(() => _accessibilityGranted = granted);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EduAya Focus'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Concentration pendant vos sessions d'étude",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Choisissez une durée, sélectionnez les applications à "
              "bloquer, puis démarrez votre session.",
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            if (!_accessibilityGranted) _buildPermissionCard(),
            if (_accessibilityGranted)
              SizedBox(
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
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DurationScreen(),
                      ),
                    );
                  },
                ),
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
              onPressed: () async {
                await ConfigService.openAccessibilitySettings();
                await Future.delayed(const Duration(seconds: 1));
                _loadState();
              },
              child: const Text("Ouvrir les réglages"),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------- ECRAN CHOIX DE LA DUREE -------------------

class DurationScreen extends StatelessWidget {
  const DurationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final options = [30, 60, 90, 120];
    return Scaffold(
      appBar: AppBar(title: const Text("Durée de la session")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Combien de temps souhaitez-vous étudier ?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ...options.map((minutes) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AppSelectionScreen(minutes: minutes),
                          ),
                        );
                      },
                      child: Text(
                        minutes < 60
                            ? "$minutes minutes"
                            : "${minutes ~/ 60}h${minutes % 60 == 0 ? '' : minutes % 60}",
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ------------------- ECRAN SELECTION DES APPS -------------------

class AppSelectionScreen extends StatefulWidget {
  final int minutes;
  const AppSelectionScreen({super.key, required this.minutes});

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

  Future<void> _startSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('blocked_apps', _selected.join(','));
    await ConfigService.startSession(widget.minutes);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SessionScreen(minutes: widget.minutes),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Applications à bloquer")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    "${_selected.length} application(s) sélectionnée(s) "
                    "pour cette session de ${widget.minutes} min",
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
  final int minutes;
  const SessionScreen({super.key, required this.minutes});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late int _secondsRemaining;
  Timer? _timer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.minutes * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 0) {
        timer.cancel();
        _onFinished();
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _onFinished() async {
    setState(() => _finished = true);
    await ConfigService.stopSession();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
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
                const SizedBox(height: 24),
                const Text(
                  "Concentration en cours",
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
                const SizedBox(height: 12),
                Text(
                  _formatTime(_secondsRemaining),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ] else ...[
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
                    Navigator.of(context)
                        .popUntil((route) => route.isFirst);
                  },
                  child: const Text("Retour à l'accueil"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
