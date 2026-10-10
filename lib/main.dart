import 'package:flutter/material.dart';
import 'theme/game_config.dart';
import 'screens/splash_screen.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ShootApp(config: gameConfig));
}

class ShootApp extends StatelessWidget {
  final GameConfig config;
  const ShootApp({super.key, required this.config});
  @override Widget build(BuildContext context) {
    return MaterialApp(
      title: config.displayName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: config.primaryColor, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: SplashScreen(config: config),
    );
  }
}
