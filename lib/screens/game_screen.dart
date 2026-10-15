import 'package:flutter/material.dart';
import '../engine/shoot_engine.dart';
import '../theme/game_config.dart';
import '../services/audio_service.dart';

class GameScreen extends StatefulWidget {
  final GameConfig config;
  final ShootEngine engine;
  final ZipwireshootoutAudio audio;
  const GameScreen(
      {super.key, required this.config, required this.engine, required this.audio});
  @override State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  @override
  void initState() {
    super.initState();
    final a = widget.audio;
    final e = widget.engine;
    e.onShoot = () => a.shoot();
    e.onTargetHit = (combo) {
      a.targetHit();
      if (combo >= 3) a.combo();
    };
    e.onTargetMiss = () => a.targetMiss();
    e.onHazardHit = () => a.hazardHit();
    e.onGameOver = () => a.lose();
    e.onLevelUp = () => a.levelUp();
    e.start();
    a.gameStart();
    a.startGameMusic();
  }

  @override
  void dispose() {
    // Back on the menu — hand music back to the menu track.
    widget.audio.startMenuMusic();
    super.dispose();
  }
  @override Widget build(BuildContext context) {
    final c = widget.config;
    return Scaffold(
      backgroundColor: c.darkColor,
      appBar: AppBar(
        backgroundColor: c.primaryColor, foregroundColor: Colors.white,
        title: Text(c.displayName),
        actions: [
          IconButton(icon: const Icon(Icons.pause), onPressed: () => setState(() => widget.engine.togglePause())),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() => widget.engine.start())),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.engine,
        builder: (_, __) {
          final e = widget.engine;
          if (e.gameOver) return _gameOver(c, e);
          return Column(children: [
            _hud(c, e),
            Expanded(
              child: GestureDetector(
                onTapDown: (d) {
                  final box = context.findRenderObject() as RenderBox;
                  final local = box.globalToLocal(d.globalPosition);
                  final size = box.size;
                  // approximate: play area starts below HUD; use full-box mapping
                  e.shoot(local.dx / size.width, local.dy / size.height);
                },
                child: CustomPaint(
                  painter: _PlayPainter(engine: e, config: c),
                  child: Container(),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _hud(GameConfig c, ShootEngine e) {
    return Container(
      color: c.primaryColor.withOpacity(0.25),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _stat('SCORE', '${e.score}'),
        _stat('COMBO', 'x${e.combo}'),
        _stat('LEVEL', '${e.level}'),
        _stat('❤', '${e.lives}'),
      ]),
    );
  }
  Widget _stat(String label, String value) => Column(children: [
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
  ]);

  Widget _gameOver(GameConfig c, ShootEngine e) {
    return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🎯', style: TextStyle(fontSize: 64)),
      const SizedBox(height: 12),
      const Text('GAME OVER', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('Score: ${e.score}', style: const TextStyle(color: Colors.white, fontSize: 22)),
      Text('Best combo: x${e.bestCombo}  •  Accuracy: ${(e.accuracy * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 24),
      ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: c.accentColor, padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16)),
        onPressed: () {
          widget.audio.click();
          setState(() => e.start());
        }, child: const Text('PLAY AGAIN', style: TextStyle(fontSize: 18))),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Menu', style: TextStyle(color: Colors.white70))),
    ])));
  }
}

class _PlayPainter extends CustomPainter {
  final ShootEngine engine; final GameConfig config;
  _PlayPainter({required this.engine, required this.config});
  @override void paint(Canvas canvas, Size size) {
    // background emoji pattern
    final bgStyle = TextStyle(fontSize: 28, color: Colors.white.withOpacity(0.08));
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < 12; i++) {
      tp.text = TextSpan(text: config.bgEmoji, style: bgStyle);
      tp.layout();
      tp.paint(canvas, Offset((i * 97) % size.width, (i * 53) % size.height));
    }
    // targets
    for (final t in engine.targets) {
      final r = t.size * size.width;
      final cx = t.x * size.width, cy = t.y * size.height;
      final emoji = t.isHazard ? config.hazardEmoji : config.targetEmoji;
      final color = t.isHazard ? Colors.red : t.kind == TargetKind.bonus ? config.accentColor : t.kind == TargetKind.fast ? Colors.orange : Colors.white;
      canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color.withOpacity(0.25));
      final st = TextStyle(fontSize: r * 1.5);
      tp.text = TextSpan(text: emoji, style: st); tp.layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }
    // shot flashes
    for (final s in engine.shots) {
      final a = 1 - s.t / 0.25;
      canvas.drawCircle(Offset(s.x * size.width, s.y * size.height), 18 * a + 6,
        Paint()..color = Colors.yellow.withOpacity(a * 0.8));
    }
    if (engine.paused) {
      tp.text = const TextSpan(text: '⏸ PAUSED', style: TextStyle(fontSize: 32, color: Colors.white));
      tp.layout(); tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height / 2 - 30));
    }
  }
  @override bool shouldRepaint(covariant CustomPainter old) => true;
}
