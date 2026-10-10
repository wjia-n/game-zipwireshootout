import 'package:flutter/material.dart';
import '../theme/game_config.dart';
import '../engine/shoot_engine.dart';
import 'game_screen.dart';
import 'settings_screen.dart';
import 'pro_screen.dart';

class MenuScreen extends StatelessWidget {
  final GameConfig config;
  const MenuScreen({super.key, required this.config});
  @override Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [config.darkColor, config.primaryColor.withOpacity(0.6)])),
        child: SafeArea(child: Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(config.targetEmoji, style: const TextStyle(fontSize: 80)),
          const SizedBox(height: 8),
          Text(config.displayName.toUpperCase(), textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(config.tagline, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 32),
          _btn(context, '🎯  PLAY', config.accentColor, () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => GameScreen(config: config, engine: ShootEngine(targetEmoji: config.targetEmoji))))),
          _btn(context, '⚙️  SETTINGS', Colors.white24, () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => SettingsScreen(config: config)))),
          _btn(context, '⭐  GO PRO', Colors.amber.shade700, () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => ProScreen(config: config)))),
          const SizedBox(height: 24),
          const Text('Credits: WAJIHA', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ])))),
      ),
    );
  }
  Widget _btn(BuildContext ctx, String label, Color color, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: SizedBox(width: double.infinity, child: ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      onPressed: onTap, child: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)))),
  );
}
