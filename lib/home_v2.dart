import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'chalisa_data.dart';
import 'main.dart';
import 'media.dart';
import 'reminder.dart';
import 'strings.dart';

const Color _gold = Color(0xFFE0A526);
const Color _goldLight = Color(0xFFFFE08A);
const Color _goldDark = Color(0xFF9C6A0E);
const Color _maroon = Color(0xFF7B1E12);
const Color _cream = Color(0xFFFFF4DC);

// ---------------------------------------------------------------------------
// Shared recitation state (keeps playing while you move between screens)
// ---------------------------------------------------------------------------

class Recitation extends ChangeNotifier {
  Recitation._();
  static final Recitation instance = Recitation._();

  AudioPlayer? _music;
  bool _musicLoaded = false;
  Timer? _timer;
  final List<double> _ends = _computeEnds();

  int current = 0;
  int round = 1;
  bool playing = false;
  bool started = false;
  Duration elapsed = Duration.zero;
  VoidCallback? onPathsComplete;

  Duration get total => Duration(minutes: settings.listenMinutes);

  static List<double> _computeEnds() {
    final weights = allVerses.map((v) => v.hindi.length.toDouble()).toList();
    final sum = weights.fold<double>(0, (a, b) => a + b);
    double running = 0;
    return [for (final w in weights) (running += w) / sum];
  }

  Future<void> _ensureMusic() async {
    if (_musicLoaded || MediaLibrary.music.isEmpty) return;
    try {
      final player = AudioPlayer();
      _music = player;
      final path = MediaLibrary.music[settings.musicTrack % MediaLibrary.music.length];
      await player.setAudioSource(AudioSource.asset(
        path,
        tag: MediaItem(
          id: path,
          title: t('appTitle'),
          artist: 'NineXm Infotech',
          album: t('jaiShriRam'),
        ),
      ));
      await player.setLoopMode(LoopMode.one);
      _musicLoaded = true;
    } catch (_) {
      _music = null;
      _musicLoaded = false;
    }
  }

  /// Frees the music player so another screen can use audio.
  Future<void> releaseMusic() async {
    stop();
    try {
      await _music?.dispose();
    } catch (_) {}
    _music = null;
    _musicLoaded = false;
  }

  Future<void> play() async {
    if (!started) {
      round = 1;
      elapsed = Duration.zero;
      current = 0;
    }
    playing = true;
    started = true;
    notifyListeners();
    try {
      WakelockPlus.enable();
    } catch (_) {}
    await _ensureMusic();
    if (playing && settings.musicOn) {
      try {
        _music?.play();
      } catch (_) {}
    }
    _startTimer();
  }

  void pause() {
    _timer?.cancel();
    _music?.pause();
    playing = false;
    notifyListeners();
    try {
      WakelockPlus.disable();
    } catch (_) {}
  }

  void stop() {
    _timer?.cancel();
    _music?.pause();
    _music?.seek(Duration.zero);
    playing = false;
    started = false;
    current = 0;
    round = 1;
    elapsed = Duration.zero;
    notifyListeners();
    try {
      WakelockPlus.disable();
    } catch (_) {}
  }

  void toggleMusic() {
    settings.setMusicOn(!settings.musicOn);
    if (settings.musicOn && playing) {
      _music?.play();
    } else {
      _music?.pause();
    }
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    const tick = Duration(milliseconds: 250);
    _timer = Timer.periodic(tick, (_) {
      elapsed += tick;
      if (elapsed >= total) {
        settings.completePath();
        if (round < settings.repeatCount) {
          round++;
          elapsed = Duration.zero;
          current = 0;
          notifyListeners();
          return;
        }
        stop();
        onPathsComplete?.call();
        return;
      }
      final share = elapsed.inMilliseconds / total.inMilliseconds;
      var index = _ends.indexWhere((e) => share < e);
      if (index < 0) index = allVerses.length - 1;
      current = index;
      notifyListeners();
    });
  }
}

String _verseIn(int script, Verse v) => [v.hindi, v.gujarati, v.roman][script];

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------

class _Petal {
  _Petal(math.Random r)
      : x = r.nextDouble(),
        delay = r.nextDouble() * 0.45,
        speed = 0.55 + r.nextDouble() * 0.45,
        size = 20 + r.nextDouble() * 16,
        spin = (r.nextDouble() - 0.5) * 6,
        drift = (r.nextDouble() - 0.5) * 0.12,
        emoji = const ['🌼', '🌺', '🌸', '🏵️'][r.nextInt(4)];

  final double x, delay, speed, size, spin, drift;
  final String emoji;
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  final Recitation _rec = Recitation.instance;
  final ap.AudioPlayer _bell = ap.AudioPlayer();
  final ap.AudioPlayer _shankh = ap.AudioPlayer();
  final math.Random _random = math.Random();

  late final TabController _tabs = TabController(length: 6, vsync: this, initialIndex: 1);
  late final AnimationController _petalCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
  late final AnimationController _aartiCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3400));
  late final AnimationController _flicker =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420))
        ..repeat(reverse: true);
  late final AnimationController _swing =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  List<_Petal> _petals = [];
  int _aartiRounds = 0;
  Rect _frameRect = Rect.zero;

  @override
  void initState() {
    super.initState();
    _rec.onPathsComplete = _showDone;
    _aartiCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _aartiRounds--;
        if (_aartiRounds > 0 && mounted) {
          _ringBell();
          _aartiCtrl.forward(from: 0);
        } else if (mounted) {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _petalCtrl.dispose();
    _aartiCtrl.dispose();
    _flicker.dispose();
    _swing.dispose();
    _bell.dispose();
    _shankh.dispose();
    super.dispose();
  }

  void _showDone() {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('pathDoneMsg')),
        content: Text(t('pathCounted')),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t('ok')),
          ),
        ],
      ),
    );
  }

  Future<void> _ringBell() async {
    HapticFeedback.lightImpact();
    _swing.forward(from: 0);
    try {
      await _bell.stop();
      await _bell.play(ap.AssetSource('sounds/bell.mp3'));
    } catch (_) {}
  }

  Future<void> _blowShankh() async {
    HapticFeedback.mediumImpact();
    try {
      await _shankh.stop();
      await _shankh.play(ap.AssetSource('sounds/shankh.mp3'));
    } catch (_) {}
  }

  void _showerPetals() {
    HapticFeedback.selectionClick();
    setState(() => _petals = List.generate(40, (_) => _Petal(_random)));
    _petalCtrl.forward(from: 0);
  }

  void _startAarti() {
    if (_aartiCtrl.isAnimating) return;
    _aartiRounds = 3;
    _ringBell();
    setState(() {});
    _aartiCtrl.forward(from: 0);
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  // ----- pieces -----

  Widget _diyaIcon(double size) {
    return AnimatedBuilder(
      animation: _flicker,
      builder: (context, _) {
        final glow = 0.55 + 0.45 * _flicker.value;
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFB300).withOpacity(0.5 * glow),
                blurRadius: 18 + 10 * glow,
                spreadRadius: 2 + 3 * glow,
              ),
            ],
          ),
          child: Text('🪔', style: TextStyle(fontSize: size)),
        );
      },
    );
  }

  Widget _frame() {
    return LayoutBuilder(builder: (context, box) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: const LinearGradient(
                  colors: [_goldDark, _goldLight, _gold, _goldLight, _goldDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 3))],
              ),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: _maroon, width: 3),
                  color: const Color(0xFF2B140B),
                ),
                child: GestureDetector(
                  onTap: _showerPetals,
                  child: const RectSlideshow(),
                ),
              ),
            ),
          ),
          // hanging bells
          for (final left in [true, false])
            Positioned(
              top: -4,
              left: left ? 2 : null,
              right: left ? null : 2,
              child: GestureDetector(
                onTap: _ringBell,
                child: AnimatedBuilder(
                  animation: _swing,
                  builder: (context, child) {
                    final v = _swing.value;
                    final angle = math.sin(v * math.pi * 6) * 0.35 * (1 - v);
                    return Transform.rotate(
                      angle: left ? angle : -angle,
                      alignment: Alignment.topCenter,
                      child: child,
                    );
                  },
                  child: const Text('🔔', style: TextStyle(fontSize: 40)),
                ),
              ),
            ),
          // shankh bottom-left
          Positioned(
            bottom: -2,
            left: 0,
            child: GestureDetector(
              onTap: _blowShankh,
              child: const Text('🐚', style: TextStyle(fontSize: 42)),
            ),
          ),
          // marigold bottom-right
          Positioned(
            bottom: -2,
            right: 0,
            child: GestureDetector(
              onTap: _showerPetals,
              child: const Text('🌼', style: TextStyle(fontSize: 42)),
            ),
          ),
        ],
      );
    });
  }

  Widget _roundButton(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color ?? const Color(0xFFF57C00),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(fontSize: 12, color: _maroon, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _homeTab() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _rec.playing
            ? _roundButton(Icons.pause_rounded, t('pause'), _rec.pause)
            : _roundButton(Icons.play_arrow_rounded, _rec.started ? t('resume') : t('play'), _rec.play),
        _roundButton(Icons.stop_rounded, t('stop'), _rec.stop, color: const Color(0xFFC62828)),
        GestureDetector(
          onTap: _startAarti,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _diyaIcon(38),
              Text(t('aarti'), style: const TextStyle(fontSize: 12, color: _maroon, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        _roundButton(settings.musicOn ? Icons.music_note_rounded : Icons.music_off_rounded, t('music'),
            () => setState(_rec.toggleMusic),
            color: const Color(0xFF6D4C41)),
        _roundButton(Icons.more_vert_rounded, t('more'), () => _open(const MoreScreen()),
            color: const Color(0xFF8D6E63)),
      ],
    );
  }

  Widget _numberChoices(List<int> values, int selected, ValueChanged<int> onPick, {String suffix = ''}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final v in values)
          InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () => onPick(v),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                '$v$suffix',
                style: TextStyle(
                  fontSize: v == selected ? 30 : 24,
                  fontWeight: v == selected ? FontWeight.bold : FontWeight.w500,
                  color: v == selected ? const Color(0xFFC62828) : const Color(0xFF2E5E4E),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _repeatTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _numberChoices(const [1, 3, 7, 11], settings.repeatCount,
            (v) => setState(() => settings.setRepeatCount(v))),
        Text('${t('repeat')}: ${_rec.round} / ${settings.repeatCount}',
            style: const TextStyle(color: _maroon, fontSize: 13)),
      ],
    );
  }

  Widget _picturesTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _numberChoices(const [5, 10, 30, 60], settings.slideSeconds,
            (v) => setState(() => settings.setSlideSeconds(v)),
            suffix: 's'),
        Text(t('slideEvery'), style: const TextStyle(color: _maroon, fontSize: 13)),
      ],
    );
  }

  Widget _lyricTab(int script) {
    final verse = allVerses[_rec.current];
    final lines = _verseIn(script, verse).split('\n');
    return InkWell(
      onTap: () => _open(LyricsScreen(script: script)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(lines.first,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 17,
                  color: _rec.started ? const Color(0xFFC62828) : _maroon,
                  fontWeight: FontWeight.w600)),
          if (lines.length > 1)
            Text(lines[1],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, color: _maroon, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            '${_rec.round}/${settings.repeatCount}    ${formatTime(_rec.elapsed)} / ${formatTime(_rec.total)}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabLabels = [t('tabRepeat'), t('tabHome'), 'हिंदी पाठ', 'ગુજરાતી પાઠ', 'English', t('tabPictures')];
    return Scaffold(
      backgroundColor: _cream,
      body: ListenableBuilder(
        listenable: _rec,
        builder: (context, _) {
          return LayoutBuilder(builder: (context, screen) {
            return Stack(
              children: [
                SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(builder: (context, box) {
                          _frameRect = Rect.fromLTWH(0, 0, box.maxWidth, box.maxHeight);
                          return _frame();
                        }),
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFFCC80), Color(0xFFF9A825), Color(0xFFEF8F00)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Column(
                          children: [
                            TabBar(
                              controller: _tabs,
                              isScrollable: true,
                              tabAlignment: TabAlignment.center,
                              labelColor: _maroon,
                              unselectedLabelColor: const Color(0xFF8A5A2B),
                              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              indicatorColor: _maroon,
                              dividerColor: Colors.transparent,
                              tabs: [for (final l in tabLabels) Tab(text: l, height: 36)],
                            ),
                            SizedBox(
                              height: 96,
                              child: TabBarView(
                                controller: _tabs,
                                children: [
                                  _repeatTab(),
                                  _homeTab(),
                                  _lyricTab(0),
                                  _lyricTab(1),
                                  _lyricTab(2),
                                  _picturesTab(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        color: _cream,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          t('appTitle'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'serif',
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _maroon,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Aarti diya circling the picture
                if (_aartiCtrl.isAnimating)
                  AnimatedBuilder(
                    animation: _aartiCtrl,
                    builder: (context, _) {
                      final top = MediaQuery.of(context).padding.top;
                      final r = _frameRect;
                      final c = Offset(r.center.dx, r.center.dy + top);
                      final a = math.pi / 2 + _aartiCtrl.value * math.pi * 2;
                      final pos = Offset(c.dx + math.cos(a) * r.width * 0.36,
                          c.dy + math.sin(a) * r.height * 0.40);
                      return Positioned(
                        left: pos.dx - 28,
                        top: pos.dy - 28,
                        child: IgnorePointer(child: _diyaIcon(44)),
                      );
                    },
                  ),

                // Flower shower
                if (_petals.isNotEmpty)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _petalCtrl,
                        builder: (context, _) {
                          final p = _petalCtrl.value;
                          final w = screen.maxWidth;
                          final h = screen.maxHeight;
                          return Stack(
                            children: [
                              for (final f in _petals)
                                if (p > f.delay && p < 1)
                                  Builder(builder: (context) {
                                    final local = ((p - f.delay) / (1 - f.delay)) * f.speed * 1.6;
                                    final y = -40 + local * (h + 80);
                                    final x = (f.x + math.sin(local * 6) * f.drift) * w;
                                    return Positioned(
                                      left: x - f.size / 2,
                                      top: y,
                                      child: Transform.rotate(
                                        angle: local * f.spin,
                                        child: Text(f.emoji, style: TextStyle(fontSize: f.size)),
                                      ),
                                    );
                                  }),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
              ],
            );
          });
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Picture slideshow filling the frame
// ---------------------------------------------------------------------------

class RectSlideshow extends StatefulWidget {
  const RectSlideshow({super.key});

  @override
  State<RectSlideshow> createState() => _RectSlideshowState();
}

class _RectSlideshowState extends State<RectSlideshow> {
  Timer? _timer;
  int _index = 0;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _seconds = settings.slideSeconds;
    if (MediaLibrary.images.length < 2) return;
    _timer = Timer.periodic(Duration(seconds: _seconds), (_) {
      if (!mounted) return;
      if (_seconds != settings.slideSeconds) {
        _schedule();
        return;
      }
      setState(() => _index = (_index + 1) % MediaLibrary.images.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_seconds != settings.slideSeconds) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _schedule();
      });
    }
    final images = MediaLibrary.images;
    if (images.isEmpty) {
      return Center(child: Image.asset('assets/icon/icon_foreground.png'));
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 1000),
      child: SizedBox.expand(
        key: ValueKey(_index),
        child: Image.asset(
          images[_index % images.length],
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full lyrics page
// ---------------------------------------------------------------------------

class _BackHeader extends StatelessWidget {
  const _BackHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(10, MediaQuery.of(context).padding.top + 8, 10, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFFFE0A3), Color(0xFFFFC56B)]),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Row(
        children: [
          Material(
            color: const Color(0xFFE65100),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    Text(t('back'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(width: 1.5, height: 26, color: _maroon.withOpacity(0.4)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: const TextStyle(fontSize: 18, color: _maroon, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class LyricsScreen extends StatefulWidget {
  const LyricsScreen({super.key, required this.script});

  final int script; // 0 Hindi, 1 Gujarati, 2 English letters

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  bool _meanings = false;

  @override
  Widget build(BuildContext context) {
    final titles = ['हिंदी में पाठ', 'ગુજરાતીમાં પાઠ', 'Lyrics in English'];
    final rec = Recitation.instance;
    return Scaffold(
      body: Column(
        children: [
          _BackHeader(title: titles[widget.script]),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0xFFFFF8D6), Color(0xFFFFD54F), Color(0xFFF9A825)],
                  stops: [0.0, 0.6, 1.0],
                  radius: 1.1,
                ),
              ),
              child: ListenableBuilder(
                listenable: rec,
                builder: (context, _) {
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                    itemCount: allVerses.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Align(
                          alignment: Alignment.centerRight,
                          child: FilterChip(
                            label: Text(t('meaning')),
                            selected: _meanings,
                            onSelected: (v) => setState(() => _meanings = v),
                          ),
                        );
                      }
                      final v = allVerses[i - 1];
                      final active = rec.started && rec.current == i - 1;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          children: [
                            Text(
                              _verseIn(widget.script, v),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 19 * settings.fontScale,
                                height: 1.55,
                                color: active ? const Color(0xFFC62828) : const Color(0xFF4E2A12),
                                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                            if (_meanings)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  verseMeaning(v),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 14 * settings.fontScale,
                                      color: const Color(0xFF6D4C41),
                                      fontStyle: FontStyle.italic),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// More features
// ---------------------------------------------------------------------------

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  late int _alarmMode = settings.alarmMode; // 0 off, 1 once, 2 daily
  late TimeOfDay _time = TimeOfDay(hour: settings.reminderHour, minute: settings.reminderMinute);

  Future<void> _applyAlarm() async {
    if (_alarmMode != 0) await ReminderService.requestPermission();
    settings.setAlarm(_alarmMode, _time.hour, _time.minute);
    await ReminderService.scheduleSimple(mode: _alarmMode, hour: _time.hour, minute: _time.minute);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_alarmMode == 0 ? t('reminderOff') : t('reminderSaved'))),
    );
  }

  Widget _section({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x33000000))),
      ),
      child: child,
    );
  }

  Widget _link(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFE65100)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87);
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3D6),
      body: Column(
        children: [
          _BackHeader(title: t('moreFeatures')),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _section(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(t('setAlarm'), style: label)),
                          Checkbox(
                            value: _alarmMode != 0,
                            onChanged: (v) {
                              setState(() => _alarmMode = v == true ? 2 : 0);
                              _applyAlarm();
                            },
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Radio<int>(
                            value: 1,
                            groupValue: _alarmMode,
                            onChanged: (v) {
                              setState(() => _alarmMode = 1);
                              _applyAlarm();
                            },
                          ),
                          Text(t('oneTime')),
                          const SizedBox(width: 16),
                          Radio<int>(
                            value: 2,
                            groupValue: _alarmMode,
                            onChanged: (v) {
                              setState(() => _alarmMode = 2);
                              _applyAlarm();
                            },
                          ),
                          Text(t('repeatDaily')),
                        ],
                      ),
                      Row(
                        children: [
                          Text('${t('reminderTime')} :-  ${_time.format(context)}',
                              style: const TextStyle(fontSize: 16)),
                          const Spacer(),
                          OutlinedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(context: context, initialTime: _time);
                              if (picked != null) {
                                setState(() {
                                  _time = picked;
                                  if (_alarmMode == 0) _alarmMode = 2;
                                });
                                _applyAlarm();
                              }
                            },
                            child: Text(t('changeTime')),
                          ),
                        ],
                      ),
                      Text(t('alarmHint'), style: const TextStyle(fontSize: 13, color: Colors.black54)),
                    ],
                  ),
                ),
                _section(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('language'), style: label),
                      const SizedBox(height: 8),
                      SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: [
                          for (int i = 0; i < langNames.length; i++)
                            ButtonSegment(value: i, label: Text(langNames[i])),
                        ],
                        selected: {settings.lang},
                        onSelectionChanged: (s) => setState(() => settings.setLang(s.first)),
                      ),
                    ],
                  ),
                ),
                _section(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('pace'), style: label),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final m in const [6, 8, 10])
                            ChoiceChip(
                              label: Text('$m ${t('min')}'),
                              selected: settings.listenMinutes == m,
                              onSelected: (_) {
                                Recitation.instance.stop();
                                setState(() => settings.setListenMinutes(m));
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                _section(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${t('paths')}: ${settings.pathCount}    •    ${t('totalJap')}: ${settings.totalJap}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                _link(Icons.menu_book_rounded, t('readMeaning'), () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const ReaderScreen()))),
                _link(Icons.touch_app_rounded, '${t('counter')} / ${t('ramMode')}', () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const CounterScreen()))),
                _link(Icons.timer_rounded, t('timed'), () async {
                  await Recitation.instance.releaseMusic();
                  if (!context.mounted) return;
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TimedChoiceScreen()));
                }),
                _link(Icons.info_outline_rounded, t('about'), () => showAboutDialog(
                      context: context,
                      applicationName: t('appTitle'),
                      applicationVersion: '3.1',
                      applicationIcon: const Text('🚩', style: TextStyle(fontSize: 32)),
                      applicationLegalese: '© 2026 NineXm Infotech',
                      children: [const SizedBox(height: 16), Text(t('aboutText'))],
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
