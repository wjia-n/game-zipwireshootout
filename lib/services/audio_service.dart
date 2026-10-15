import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Procedural audio for Zip Wire Shootout — laser zaps, target pops and combo sparkles,
/// synthesized in code as WAV bytes. No asset files.
///
/// BGM identity: D / 1-4-0-5 / bass_melody — unique to zipwireshootout.
///
/// Reliability design (every call is safe to repeat and safe to overlap):
/// - Music clips are synthesized ONCE and cached; starting music never blocks
///   the UI thread after the first build.
/// - A [_musicGen] generation counter serializes track changes: every
///   start/stop bumps the generation, in-flight work from an older request
///   aborts, and the LATEST request always wins.
/// - Lifecycle uses pause()/resume() so an interruption (call, backgrounding)
///   resumes exactly where it left off instead of restarting or dying.
/// - Every public method catches player errors; audio can never crash the app.
class ZipwireshootoutAudio {
  /// Per-game pitch character (zipwireshootout): 1.120x. Makes SFX unique.
  static const double _pitchMul = 1.120;

  /// BGM identity (key / progression / game-track style) — unique per game.
  static const String bgmKey = 'D';
  static const String bgmProgression = '1-4-0-5';
  static const String bgmStyle = 'bass_melody';

  static const int _rate = 22050;
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  final _rand = Random();

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;

  // Cache synthesized clips so we only build them once.
  final Map<String, Uint8List> _cache = {};

  // Music state machine. [_musicGen] is bumped by every start/stop request;
  // async work checks it still owns the latest generation before touching
  // the player, so overlapping requests can never desync the music.
  int _musicGen = 0;
  bool _musicBusy = false;
  String? _currentTrack; // 'menu' | 'game' | null
  bool _pausedByLifecycle = false;
  bool _disposed = false;

  Future<void> init() async {
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
    } catch (_) {}
  }

  void configure(
      {required bool musicOn, required bool sfxOn, required double volume}) {
    this.musicOn = musicOn;
    this.sfxOn = sfxOn;
    this.volume = volume.clamp(0.0, 1.0);
    _music.setVolume(musicOn ? this.volume * 0.5 : 0.0);
    _sfx.setVolume(sfxOn ? this.volume : 0.0);
    if (!musicOn) {
      stopMusic();
    } else if (_currentTrack != null) {
      // Toggled back on — make the current track audible again.
      final t = _currentTrack;
      _currentTrack = null;
      if (t == 'menu') {
        startMenuMusic();
      } else {
        startGameMusic();
      }
    }
  }

  /// Pre-build music clips off the critical path. Safe to call any time.
  Future<void> prewarm() async {
    if (_disposed) return;
    await Future(() {});
    _menuBytes();
    _gameBytes();
  }

  // ---------------------------------------------------------- WAV synthesis
  Uint8List _wav(List<double> samples) {
    final n = samples.length;
    final data = ByteData(44 + n * 2);
    void writeStr(int o, String s) {
      for (int i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, _rate, Endian.little);
    data.setUint32(28, _rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (int i = 0; i < n; i++) {
      final v = samples[i].clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  double _env(int i, int n, {double attack = 0.02}) {
    final t = i / n;
    final a = (t / attack).clamp(0.0, 1.0);
    final d = pow(1 - t, 2.2).toDouble();
    return a * d;
  }

  List<double> _tone(double freq, double secs,
      {double freqEnd = 0, double attack = 0.02, double harmonics = 0.25}) {
    freq *= _pitchMul;
    freqEnd *= _pitchMul;
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final f = freqEnd > 0 ? freq + (freqEnd - freq) * (i / n) : freq;
      final ph = 2 * pi * f * t;
      out[i] = _env(i, n, attack: attack) *
          (sin(ph) + harmonics * sin(2 * ph) + harmonics * 0.5 * sin(3 * ph));
    }
    return out;
  }

  List<double> _arp(List<double> freqs, double noteSecs, double gapSecs,
      {double harmonics = 0.2}) {
    final out = <double>[];
    for (final f in freqs) {
      out.addAll(_tone(f, noteSecs, harmonics: harmonics));
      final gap = List<double>.filled((_rate * gapSecs).round(), 0);
      out.addAll(gap);
    }
    return out;
  }

  // ignore: unused_element
  List<double> _padChord(List<double> freqs, double secs) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      double v = 0;
      for (final f in freqs) {
        final t = i / _rate;
        v += sin(2 * pi * f * t) + 0.3 * sin(2 * pi * f * 2 * t);
      }
      v /= freqs.length * 1.3;
      final t = i / n;
      final swell = sin(pi * t.clamp(0.0, 1.0)); // slow swell in/out
      out[i] = v * (0.35 + 0.65 * swell);
    }
    return out;
  }

  Uint8List _clip(String key, List<double> Function() build) =>
      _cache.putIfAbsent(key, () => _wav(build()));

  Uint8List _menuBytes() => _clip('music_menu', () {
        // A# pad 3 – 0 – 4 – 5, 16s loop. Unique to zipwireshootout.
        final seq = [
          [155.56, 195.99, 233.08],
          [116.54, 146.83, 174.61],
          [174.61, 220.00, 261.62],
          [195.99, 233.08, 293.66],
        ];
        final out = <double>[];
        for (final chord in seq) {
          out.addAll(_padChord(chord, 4.0));
        }
        return out;
      });

  Uint8List _gameBytes() => _clip('music_game', () {
        // D bass_melody 1 – 4 – 0 – 5, 8s loop. Unique to zipwireshootout.
        final seq = [
          [82.41, 98.00, 123.47],
          [110.00, 138.59, 164.81],
          [73.41, 92.50, 110.00],
          [123.47, 146.83, 184.99],
        ];
        final out = <double>[];
        for (final chord in seq) {
          out.addAll(_tone(chord[0] / 2, 0.9, harmonics: 0.3));
          out.addAll(_tone(chord[2], 0.35, harmonics: 0.25));
          out.addAll(_tone(chord[1], 0.35, harmonics: 0.25));
          out.addAll(_tone(chord[2] * 2, 0.35, harmonics: 0.25));
        }
        return out;
      });

  // ------------------------------------------------------------------ SFX
  Future<void> _play(Uint8List bytes) async {
    if (!sfxOn || _disposed) return;
    try {
      await _sfx.play(BytesSource(bytes));
    } catch (_) {}
  }

  Future<void> click() => _play(_clip('click', () => _tone(1150, 0.06)));

  /// Laser shot.
  Future<void> shoot() =>
      _play(_clip('shoot', () => _tone(1500, 0.14, freqEnd: 320, harmonics: 0.35)));

  /// Target popped — bright pop with a noise snap.
  Future<void> targetHit() => _play(_clip('hit', () {
        final pop = _tone(520, 0.09, freqEnd: 940, harmonics: 0.3);
        final n = (_rate * 0.09).round();
        final out = List<double>.from(pop);
        for (int i = 0; i < n; i++) {
          final t = i / _rate;
          out[i] += 0.35 * (_rand.nextDouble() * 2 - 1) * exp(-t * 90);
        }
        return out;
      }));

  /// Shot missed everything — soft thud.
  Future<void> targetMiss() =>
      _play(_clip('miss', () => _tone(190, 0.14, harmonics: 0.4)));

  /// Hazard hit — harsh buzz.
  Future<void> hazardHit() => _play(
      _clip('hazard', () => _tone(120, 0.32, freqEnd: 70, harmonics: 0.65)));

  /// Combo milestone — rising sparkle.
  Future<void> combo() => _play(_clip('combo',
      () => _arp([784.0, 987.77, 1174.66, 1567.98], 0.09, 0.02)));

  /// Level up fanfare.
  Future<void> levelUp() => _play(_clip('levelup',
      () => _arp([523.25, 659.25, 783.99, 1046.5], 0.12, 0.03)));

  Future<void> gameStart() =>
      _play(_clip('start', () => _tone(420, 0.32, freqEnd: 840)));

  Future<void> win() => _play(_clip('win',
      () => _arp([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.16, 0.03)));

  Future<void> lose() =>
      _play(_clip('lose', () => _arp([392.0, 329.63, 261.63, 196.0], 0.22, 0.04)));

  /// Reload clack (two-part).
  Future<void> reload() => _play(_clip('reload', () {
        final a = _tone(700, 0.05);
        final b = _tone(420, 0.07);
        return <double>[
          ...a,
          ...List<double>.filled((_rate * 0.03).round(), 0),
          ...b
        ];
      }));

  // ----------------------------------------------------------------- music
  /// Start (or keep) a music track. Generation-serialized: the latest request
  /// always wins; a start issued while an older one is in flight is never
  /// dropped. Re-requesting the current track just ensures it is audible.
  Future<void> _startTrack(String track, Uint8List Function() bytes) async {
    if (_disposed) return;
    final gen = ++_musicGen;
    if (_currentTrack == track && !_pausedByLifecycle) {
      // Already on this track — make sure it is actually audible.
      try {
        await _music.resume();
      } catch (_) {}
      return;
    }
    // Wait for any in-flight op, then bail if superseded meanwhile.
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (gen != _musicGen || _disposed || !musicOn) return;
    _musicBusy = true;
    try {
      await _music.stop();
      if (gen != _musicGen || _disposed || !musicOn) return;
      _currentTrack = track;
      _pausedByLifecycle = false;
      await _music.play(BytesSource(bytes()));
    } catch (_) {
      if (gen == _musicGen) _currentTrack = null;
    } finally {
      _musicBusy = false;
    }
  }

  Future<void> startMenuMusic() => _startTrack('menu', _menuBytes);
  Future<void> startGameMusic() => _startTrack('game', _gameBytes);

  /// App-scoped stop: cancels any pending start, then stops. Used only when
  /// the user turns music OFF — never on screen navigation.
  Future<void> stopMusic() async {
    ++_musicGen; // cancel any in-flight start
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (_disposed) return;
    try {
      await _music.stop();
    } catch (_) {}
    _currentTrack = null;
    _pausedByLifecycle = false;
  }

  /// App went to background / interruption: pause (not stop) so we resume
  /// exactly where it left off.
  Future<void> onAppPaused() async {
    if (_disposed || _currentTrack == null) return;
    try {
      await _music.pause();
      _pausedByLifecycle = true;
    } catch (_) {}
  }

  /// App came back: resume only if we paused it and music is still wanted.
  Future<void> onAppResumed() async {
    if (_disposed || !musicOn || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    try {
      await _music.resume();
    } catch (_) {
      // Resume failed (e.g. player was released) — restart the track.
      final track = _currentTrack;
      _currentTrack = null;
      if (track == 'menu') {
        await startMenuMusic();
      } else if (track == 'game') {
        await startGameMusic();
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _sfx.dispose();
      await _music.dispose();
    } catch (_) {}
  }
}
