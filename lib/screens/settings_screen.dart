import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/game_config.dart';
import '../services/audio_service.dart';

class SettingsScreen extends StatefulWidget {
  final GameConfig config;
  final ZipwireshootoutAudio audio;
  const SettingsScreen({super.key, required this.config, required this.audio});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}
class _SettingsScreenState extends State<SettingsScreen> {
  bool music = true, sfx = true, vibration = true;
  String playerName = 'Player 1';
  final _nameCtrl = TextEditingController();
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final p = '${widget.config.slug}_';
    setState(() {
      music = sp.getBool('${p}music') ?? true;
      sfx = sp.getBool('${p}sfx') ?? true;
      vibration = sp.getBool('${p}vibration') ?? true;
      playerName = sp.getString('${p}playerName') ?? 'Player 1';
      _nameCtrl.text = playerName;
    });
  }
  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    final p = '${widget.config.slug}_';
    await sp.setBool('${p}music', music);
    await sp.setBool('${p}sfx', sfx);
    await sp.setBool('${p}vibration', vibration);
    await sp.setString('${p}playerName', playerName);
  }
  @override Widget build(BuildContext context) {
    final c = widget.config;
    return Scaffold(backgroundColor: c.darkColor,
      appBar: AppBar(title: const Text('Settings'), backgroundColor: c.primaryColor, foregroundColor: Colors.white),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('PLAYER NAME', style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(controller: _nameCtrl, style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(filled: true, fillColor: Colors.white10,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
          onChanged: (v) { playerName = v; _save(); }),
        const SizedBox(height: 16),
        _toggle('🎵 Music', music, (v) {
          widget.audio.click();
          setState(() { music = v; _save(); });
          widget.audio.configure(musicOn: music, sfxOn: sfx, volume: widget.audio.volume);
        }),
        _toggle('🔊 Sound FX', sfx, (v) {
          widget.audio.click();
          setState(() { sfx = v; _save(); });
          widget.audio.configure(musicOn: music, sfxOn: sfx, volume: widget.audio.volume);
        }),
        _toggle('📳 Vibration', vibration, (v) => setState(() { vibration = v; _save(); })),
        const SizedBox(height: 16),
        Card(color: Colors.white10, child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('HOW TO PLAY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(c.howTo, style: const TextStyle(color: Colors.white70)),
        ]))),
      ]),
    );
  }
  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
    title: Text(label, style: const TextStyle(color: Colors.white)),
    value: value, onChanged: onChanged, activeColor: widget.config.accentColor);
}
