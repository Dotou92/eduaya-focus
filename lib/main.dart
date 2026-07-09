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
      title: 'EduAyo Focus',
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
    });
  }

  Future<void> _toggleBlocking(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('blocking_enabled', value);
    setState(() => _blockingEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EduAyo Focus'),
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
            const Text(
              "Les réseaux sociaux sélectionnés seront bloqués automatiquement "
              "pendant le créneau d'étude configuré (par défaut 08h00 - 17h00).",
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            if (!_accessibilityGranted) _buildPermissionCard(),
            if (_accessibilityGranted) _buildBlockingSwitch(),
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
              "Pour bloquer les applications, EduAyo Focus a besoin de la "
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
