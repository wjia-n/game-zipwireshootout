import 'package:flutter/material.dart';
import '../theme/game_config.dart';
import 'menu_screen.dart';

class SplashScreen extends StatefulWidget {
  final GameConfig config;
  const SplashScreen({super.key, required this.config});
  @override State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> {
  @override void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) { Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => MenuScreen(config: widget.config))); }
    });
  }
  @override Widget build(BuildContext context) {
    final c = widget.config;
    return Scaffold(backgroundColor: c.darkColor, body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(c.targetEmoji, style: const TextStyle(fontSize: 96)),
      const SizedBox(height: 16),
      Text(c.displayName.toUpperCase(), textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
      const SizedBox(height: 24),
      const CircularProgressIndicator(color: Colors.white54),
      const SizedBox(height: 32),
      const Text('Credits: WAJIHA', style: TextStyle(color: Colors.white38, fontSize: 12)),
    ])));
  }
}
