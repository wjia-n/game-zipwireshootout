import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/game_config.dart';
import 'screens/splash_screen.dart';
import 'services/audio_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final audio = ZipwireshootoutAudio();
  await audio.init();
  final sp = await SharedPreferences.getInstance();
  final p = '${gameConfig.slug}_';
  audio.configure(
    musicOn: sp.getBool('${p}music') ?? true,
    sfxOn: sp.getBool('${p}sfx') ?? true,
    volume: 0.8,
  );
  // Synthesize music clips off the critical path; never blocks first frame.
  audio.prewarm();
  runApp(ShootApp(config: gameConfig, audio: audio));
}

class ShootApp extends StatefulWidget {
  final GameConfig config;
  final ZipwireshootoutAudio audio;
  const ShootApp({super.key, required this.config, required this.audio});
  @override
  State<ShootApp> createState() => _ShootAppState();
}

class _ShootAppState extends State<ShootApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.audio.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      widget.audio.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: widget.config.displayName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: widget.config.primaryColor, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: SplashScreen(config: widget.config, audio: widget.audio),
    );
  }
}
