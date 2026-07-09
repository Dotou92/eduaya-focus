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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _accessibilityGranted = false;
  bool _blockingEnabled = false;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final granted = await ConfigService.isAccessibilityServiceEnabled();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _accessibilityGranted = granted;
      _blockingEnabled = prefs.getBool('blocking_enabled') ?? false;
      _startTime = TimeOfDay(
        hour: prefs.getInt('study_start_hour') ?? 8,
        minute: prefs.getInt('study_start_minute') ?? 0,
      );
      _endTime = TimeOfDay(
        hour: prefs.getInt('study_end_hour') ?? 17,
        minute: prefs.getInt('study_end_minute') ?? 0,
      );
    });
  }

  Future<void> _toggleBlocking(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('blocking_enabled', value);
    setState(() => _blockingEnabled = value);
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('study_start_hour', picked.hour);
      await prefs.setInt('study_start_minute', picked.minute);
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('study_end_hour', picked.hour);
      await prefs.setInt('study_end_minute', picked.minute);
      setState(() => _endTime = picked);
    }
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '${h}h$m';
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
              "Concentration pendant les heures d'étude",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Les réseaux sociaux sélectionnés seront bloqués automatiquement "
              "entre ${_formatTime(_startTime)} et ${_formatTime(_endTime)}.",
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            if (!_accessibilityGranted) _buildPermissionCard(),
            if (_accessibilityGranted) ...[
              _buildBlockingSwitch(),
              const SizedBox(height: 24),
              const Text(
                "Créneau d'étude",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.play_arrow),
                  title: const Text("Heure de début"),
                  trailing: Text(
                    _formatTime(_startTime),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  onTap: _pickStartTime,
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.stop),
                  title: const Text("Heure de fin"),
                  trailing: Text(
                    _formatTime(_endTime),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  onTap: _pickEndTime,
                ),
              ),
            ],
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

  Widget _buildBlockingSwitch() {
    return SwitchListTile(
      title: const Text("Activer le blocage"),
      subtitle: Text(_blockingEnabled
          ? "Blocage actif pendant les heures d'étude"
          : "Blocage désactivé"),
      value: _blockingEnabled,
      onChanged: _toggleBlocking,
    );
  }
}
