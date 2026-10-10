import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  final String prefix;
  SettingsService(this.prefix);

  Future<bool> getMusic() async => (await SharedPreferences.getInstance()).getBool('${prefix}music') ?? true;
  Future<bool> getSfx() async => (await SharedPreferences.getInstance()).getBool('${prefix}sfx') ?? true;
  Future<bool> getVibration() async => (await SharedPreferences.getInstance()).getBool('${prefix}vibration') ?? true;
  Future<String> getPlayerName() async => (await SharedPreferences.getInstance()).getString('${prefix}playerName') ?? 'Player 1';

  Future<void> setMusic(bool v) async => (await SharedPreferences.getInstance()).setBool('${prefix}music', v);
  Future<void> setSfx(bool v) async => (await SharedPreferences.getInstance()).setBool('${prefix}sfx', v);
  Future<void> setVibration(bool v) async => (await SharedPreferences.getInstance()).setBool('${prefix}vibration', v);
  Future<void> setPlayerName(String v) async => (await SharedPreferences.getInstance()).setString('${prefix}playerName', v);

  Future<int> getHighScore() async => (await SharedPreferences.getInstance()).getInt('${prefix}highScore') ?? 0;
  Future<void> setHighScore(int v) async => (await SharedPreferences.getInstance()).setInt('${prefix}highScore', v);
}
