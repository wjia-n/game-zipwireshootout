import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

enum TargetKind { normal, bonus, hazard, fast }

class ShootTarget {
  final int id;
  double x, y; // 0..1 normalized
  double vx, vy;
  final TargetKind kind;
  final double size;
  int hp;
  bool get isHazard => kind == TargetKind.hazard;
  ShootTarget({required this.id, required this.x, required this.y, required this.vx, required this.vy, required this.kind, required this.size, this.hp = 1});
}

class ShotFX { double x, y, t; ShotFX(this.x, this.y) : t = 0; }

class ShootEngine extends ChangeNotifier {
  final Random _r = Random();
  int _nextId = 1;
  List<ShootTarget> targets = [];
  List<ShotFX> shots = [];
  int score = 0, combo = 0, bestCombo = 0, level = 1, lives = 3;
  int shotsFired = 0, hits = 0;
  bool playing = false, gameOver = false, paused = false;
  double spawnT = 0;
  Timer? _loop;
  // Config (per-game)
  final String targetEmoji;
  final double baseSpeed;
  final int targetsToLevel;
  int _killsThisLevel = 0;
  VoidCallback? onLevelUp;
  // Audio hooks (wired by GameScreen; all optional).
  void Function()? onShoot;
  void Function(int combo)? onTargetHit;
  void Function()? onTargetMiss;
  void Function()? onHazardHit;
  void Function()? onGameOver;

  ShootEngine({required this.targetEmoji, this.baseSpeed = 0.25, this.targetsToLevel = 12});

  void start() {
    score = 0; combo = 0; bestCombo = 0; level = 1; lives = 3;
    shotsFired = 0; hits = 0; _killsThisLevel = 0;
    targets.clear(); shots.clear();
    playing = true; gameOver = false; paused = false;
    _loop?.cancel();
    _loop = Timer.periodic(const Duration(milliseconds: 33), (_) => _tick(0.033));
    notifyListeners();
  }

  void stop() { _loop?.cancel(); playing = false; notifyListeners(); }
  void togglePause() { if (!playing || gameOver) return; paused = !paused; notifyListeners(); }

  void _tick(double dt) {
    if (!playing || paused || gameOver) return;
    spawnT -= dt;
    if (spawnT <= 0) { _spawn(); spawnT = max(0.35, 1.1 - level * 0.07); }
    final sp = baseSpeed * (1 + (level - 1) * 0.15);
    for (final t in targets) {
      t.x += t.vx * sp * dt;
      t.y += t.vy * sp * dt;
    }
    // despawn off-screen: hazard escaping costs a life
    targets.removeWhere((t) {
      final out = t.x < -0.1 || t.x > 1.1 || t.y < -0.1 || t.y > 1.1;
      if (out && !t.isHazard) { _miss(); }
      return out;
    });
    for (final s in shots) s.t += dt;
    shots.removeWhere((s) => s.t > 0.25);
    notifyListeners();
  }

  void _spawn() {
    final roll = _r.nextDouble();
    final kind = roll < 0.08 ? TargetKind.hazard : roll < 0.2 ? TargetKind.bonus : roll < 0.35 ? TargetKind.fast : TargetKind.normal;
    final fromLeft = _r.nextBool();
    final y = 0.15 + _r.nextDouble() * 0.6;
    targets.add(ShootTarget(
      id: _nextId++,
      x: fromLeft ? -0.05 : 1.05, y: y,
      vx: (fromLeft ? 1 : -1) * (0.6 + _r.nextDouble() * 0.8),
      vy: (_r.nextDouble() - 0.5) * 0.6,
      kind: kind,
      size: kind == TargetKind.bonus ? 0.09 : kind == TargetKind.fast ? 0.055 : 0.075,
      hp: kind == TargetKind.bonus ? 2 : 1,
    ));
  }

  void shoot(double x, double y) {
    if (!playing || paused || gameOver) return;
    shotsFired++;
    shots.add(ShotFX(x, y));
    onShoot?.call();
    // find closest target within radius
    ShootTarget? best; double bestD = 0.09;
    for (final t in targets) {
      final d = sqrt(pow(t.x - x, 2) + pow(t.y - y, 2));
      if (d < bestD) { bestD = d; best = t; }
    }
    if (best != null) {
      hits++;
      if (best.isHazard) {
        combo = 0; lives--;
        targets.remove(best);
        onHazardHit?.call();
        if (lives <= 0) _end();
      } else {
        best.hp--;
        if (best.hp <= 0) {
          targets.remove(best);
          combo++; bestCombo = max(bestCombo, combo);
          onTargetHit?.call(combo);
          final pts = (best.kind == TargetKind.bonus ? 50 : best.kind == TargetKind.fast ? 25 : 10) * (1 + combo ~/ 5);
          score += pts;
          _killsThisLevel++;
          if (_killsThisLevel >= targetsToLevel) { _killsThisLevel = 0; level++; onLevelUp?.call(); }
        }
      }
    } else {
      combo = 0;
      onTargetMiss?.call();
    }
    notifyListeners();
  }

  void _miss() { combo = 0; }
  void _end() {
    gameOver = true;
    playing = false;
    _loop?.cancel();
    onGameOver?.call();
    notifyListeners();
  }
  double get accuracy => shotsFired == 0 ? 0 : hits / shotsFired;
  @override void dispose() { _loop?.cancel(); super.dispose(); }
}
