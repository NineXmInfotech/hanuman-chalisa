import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'chalisa_data.dart';
import 'strings.dart';

late final AppSettings settings;

const Color saffron = Color(0xFFE65100);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Show any unexpected error on screen instead of a blank page.
  ErrorWidget.builder =
      (details) => _ErrorView(message: details.exceptionAsString());

  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance()
        .timeout(const Duration(seconds: 3));
  } catch (_) {
    prefs = null; // app still works, progress just isn't saved
  }
  settings = AppSettings(prefs);

  runApp(const ChalisaApp());
}

// ---------------------------------------------------------------------------
// Text helpers
// ---------------------------------------------------------------------------

String t(String key) {
  final values = appStrings[key];
  if (values == null) return key;
  return values[settings.lang];
}

String verseText(Verse v) => [v.hindi, v.gujarati, v.roman][settings.lang];

String verseMeaning(Verse v) =>
    [v.meaningHi, v.meaningGu, v.meaningEn][settings.lang];

String verseLabel(Verse v) => v.kind == VerseKind.doha
    ? t('doha')
    : '${t('chaupai')} ${v.number}';

String formatTime(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFFFFF3E0),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Something went wrong. Please send this message to the developer:\n\n$message',
              style: const TextStyle(color: Color(0xFF5D4037), fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings & saved progress
// ---------------------------------------------------------------------------

class AppSettings extends ChangeNotifier {
  AppSettings(SharedPreferences? prefs)
      : _prefs = prefs,
        lang = _validLang(prefs?.getInt('lang')),
        fontScale = prefs?.getDouble('fontScale') ?? 1.0,
        showAllMeanings = prefs?.getBool('showAllMeanings') ?? false,
        themeIndex = prefs?.getInt('themeIndex') ?? 0,
        pathCount = prefs?.getInt('pathCount') ?? 0,
        malaTarget = prefs?.getInt('malaTarget') ?? 108,
        counter = prefs?.getInt('counter') ?? 0,
        malaRounds = prefs?.getInt('malaRounds') ?? 0;

  static int _validLang(int? value) {
    if (value == null || value < 0 || value > 2) return 0;
    return value;
  }

  final SharedPreferences? _prefs;

  int lang; // 0 = Hindi, 1 = Gujarati, 2 = English
  double fontScale;
  bool showAllMeanings;
  int themeIndex; // 0 = system, 1 = light, 2 = dark
  int pathCount;
  int malaTarget;
  int counter;
  int malaRounds;

  ThemeMode get themeMode {
    if (themeIndex == 1) return ThemeMode.light;
    if (themeIndex == 2) return ThemeMode.dark;
    return ThemeMode.system;
  }

  void setLang(int value) {
    lang = _validLang(value);
    _prefs?.setInt('lang', lang);
    notifyListeners();
  }

  void setThemeIndex(int value) {
    themeIndex = value;
    _prefs?.setInt('themeIndex', value);
    notifyListeners();
  }

  void changeFont(double delta) {
    double next = fontScale + delta;
    if (next < 0.8) next = 0.8;
    if (next > 2.0) next = 2.0;
    fontScale = next;
    _prefs?.setDouble('fontScale', fontScale);
    notifyListeners();
  }

  void toggleAllMeanings() {
    showAllMeanings = !showAllMeanings;
    _prefs?.setBool('showAllMeanings', showAllMeanings);
    notifyListeners();
  }

  void completePath() {
    pathCount++;
    _prefs?.setInt('pathCount', pathCount);
    notifyListeners();
  }

  void setMalaTarget(int value) {
    malaTarget = value;
    if (counter >= malaTarget) counter = 0;
    _prefs?.setInt('malaTarget', malaTarget);
    _prefs?.setInt('counter', counter);
    notifyListeners();
  }

  /// Returns true when a full mala round has just been completed.
  bool increment() {
    counter++;
    bool roundDone = false;
    if (counter >= malaTarget) {
      counter = 0;
      malaRounds++;
      roundDone = true;
      _prefs?.setInt('malaRounds', malaRounds);
    }
    _prefs?.setInt('counter', counter);
    notifyListeners();
    return roundDone;
  }

  void resetCounter() {
    counter = 0;
    malaRounds = 0;
    _prefs?.setInt('counter', 0);
    _prefs?.setInt('malaRounds', 0);
    notifyListeners();
  }
}

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

class ChalisaApp extends StatelessWidget {
  const ChalisaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'Hanuman Chalisa',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: saffron),
            scaffoldBackgroundColor: const Color(0xFFFFF8F0),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: saffron,
              brightness: Brightness.dark,
            ),
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Home
// ---------------------------------------------------------------------------

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(
                    24, MediaQuery.of(context).padding.top + 12, 8, 28),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF8F00), Color(0xFFD84315)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t('jaiShriRam'),
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        const _LanguageMenu(),
                        const _ThemeMenu(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('🚩', style: TextStyle(fontSize: 44)),
                    const SizedBox(height: 8),
                    Text(
                      t('appTitle'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                              label: t('paths'),
                              value: '${settings.pathCount}'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatTile(
                              label: t('rounds'),
                              value: '${settings.malaRounds}'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _BigButton(
                      icon: Icons.menu_book_rounded,
                      title: t('read'),
                      subtitle: t('readSub'),
                      color: scheme.primary,
                      onTap: () => _open(context, const ReaderScreen()),
                    ),
                    const SizedBox(height: 12),
                    _BigButton(
                      icon: Icons.headphones_rounded,
                      title: t('listen'),
                      subtitle: t('listenSub'),
                      color: const Color(0xFFC62828),
                      onTap: () => _open(context, const PathPlayerScreen()),
                    ),
                    const SizedBox(height: 12),
                    _BigButton(
                      icon: Icons.timer_rounded,
                      title: t('timed'),
                      subtitle: t('timedSub'),
                      color: const Color(0xFF6D4C41),
                      onTap: () => _open(context, const TimedChoiceScreen()),
                    ),
                    const SizedBox(height: 12),
                    _BigButton(
                      icon: Icons.touch_app_rounded,
                      title: t('counter'),
                      subtitle: t('counterSub'),
                      color: scheme.tertiary,
                      onTap: () => _open(context, const CounterScreen()),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      t('author'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      icon: const Icon(Icons.translate_rounded, color: Colors.white),
      tooltip: t('language'),
      initialValue: settings.lang,
      onSelected: settings.setLang,
      itemBuilder: (context) => [
        for (int i = 0; i < langNames.length; i++)
          PopupMenuItem(value: i, child: Text(langNames[i])),
      ],
    );
  }
}

class _ThemeMenu extends StatelessWidget {
  const _ThemeMenu();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      icon: const Icon(Icons.brightness_6_rounded, color: Colors.white),
      tooltip: t('theme'),
      initialValue: settings.themeIndex,
      onSelected: settings.setThemeIndex,
      itemBuilder: (context) => [
        PopupMenuItem(value: 0, child: Text(t('themeSystem'))),
        PopupMenuItem(value: 1, child: Text(t('themeLight'))),
        PopupMenuItem(value: 2, child: Text(t('themeDark'))),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: scheme.onPrimaryContainer),
          ),
          Text(label, style: TextStyle(color: scheme.onPrimaryContainer)),
        ],
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: color,
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reader
// ---------------------------------------------------------------------------

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final Set<int> _open = <int>{};

  void _finish() {
    settings.completePath();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('pathDoneMsg'))),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(
            title: Text(t('read')),
            actions: [
              IconButton(
                tooltip: t('smaller'),
                icon: const Icon(Icons.text_decrease_rounded),
                onPressed: () => settings.changeFont(-0.1),
              ),
              IconButton(
                tooltip: t('larger'),
                icon: const Icon(Icons.text_increase_rounded),
                onPressed: () => settings.changeFont(0.1),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'meaning') settings.toggleAllMeanings();
                  if (value.startsWith('lang')) {
                    settings.setLang(int.parse(value.substring(4)));
                  }
                },
                itemBuilder: (context) => [
                  CheckedPopupMenuItem(
                    value: 'meaning',
                    checked: settings.showAllMeanings,
                    child: Text(t('showAll')),
                  ),
                  const PopupMenuDivider(),
                  for (int i = 0; i < langNames.length; i++)
                    CheckedPopupMenuItem(
                      value: 'lang$i',
                      checked: settings.lang == i,
                      child: Text(langNames[i]),
                    ),
                ],
              ),
            ],
          ),
          body: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: allVerses.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    t('tapHint'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                );
              }
              if (index == allVerses.length + 1) {
                return Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Column(
                    children: [
                      Text(
                        t('siyavar'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 18 * settings.fontScale,
                            fontWeight: FontWeight.w600,
                            color: scheme.primary),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _finish,
                        icon: const Icon(Icons.check_circle_rounded),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          child: Text(t('pathDone'),
                              style: const TextStyle(fontSize: 17)),
                        ),
                      ),
                    ],
                  ),
                );
              }
              final i = index - 1;
              return _VerseCard(
                verse: allVerses[i],
                expanded: settings.showAllMeanings || _open.contains(i),
                onTap: () => setState(() {
                  if (!_open.remove(i)) _open.add(i);
                }),
              );
            },
          ),
        );
      },
    );
  }
}

class _VerseCard extends StatelessWidget {
  const _VerseCard({
    super.key,
    required this.verse,
    required this.expanded,
    this.highlighted = false,
    this.onTap,
  });

  final Verse verse;
  final bool expanded;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDoha = verse.kind == VerseKind.doha;

    Color background;
    Color textColor = scheme.onSurface;
    if (highlighted) {
      background = scheme.primary;
      textColor = scheme.onPrimary;
    } else if (isDoha) {
      background = scheme.primaryContainer;
    } else {
      background = scheme.surfaceContainerLow;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: highlighted ? 4 : 0,
      color: background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                verseLabel(verse),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: highlighted ? scheme.onPrimary : scheme.primary,
                    letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                verseText(verse),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20 * settings.fontScale,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      verseMeaning(verse),
                      style: TextStyle(
                        fontSize: 15 * settings.fontScale,
                        height: 1.45,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                crossFadeState: expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timed path: choose duration
// ---------------------------------------------------------------------------

class TimedChoiceScreen extends StatelessWidget {
  const TimedChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget option({
      required IconData icon,
      required String title,
      required String subtitle,
      required Widget screen,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _BigButton(
          icon: icon,
          title: title,
          subtitle: subtitle,
          color: scheme.primary,
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => screen)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(t('timed'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              t('chooseTime'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
          option(
            icon: Icons.headphones_rounded,
            title: t('normal'),
            subtitle: t('normalSub'),
            screen: const PathPlayerScreen(),
          ),
          for (final minutes in const [3, 6, 10])
            option(
              icon: Icons.timer_rounded,
              title: '$minutes ${t('minutes')}',
              subtitle: t('minutesSub'),
              screen: PathPlayerScreen(duration: Duration(minutes: minutes)),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Path player: listen (audio) or timed (silent pacer)
// ---------------------------------------------------------------------------

class PathPlayerScreen extends StatefulWidget {
  /// When null, the Chalisa is recited aloud verse by verse.
  /// Otherwise verses are highlighted so the path ends in [duration].
  const PathPlayerScreen({super.key, this.duration});

  final Duration? duration;

  @override
  State<PathPlayerScreen> createState() => _PathPlayerScreenState();
}

class _PathPlayerScreenState extends State<PathPlayerScreen> {
  final List<GlobalKey> _keys =
      List.generate(allVerses.length, (_) => GlobalKey());

  FlutterTts? _tts;
  bool _ttsReady = false;
  bool _noVoice = false;

  int _current = 0;
  bool _playing = false;
  bool _started = false;
  bool _finished = false;
  int _runId = 0;

  Timer? _timer;
  Duration _elapsed = Duration.zero;
  late final List<double> _ends; // cumulative share of total time per verse

  bool get _audioMode => widget.duration == null;

  @override
  void initState() {
    super.initState();

    // Longer verses get proportionally more time in timed mode.
    final weights =
        allVerses.map((v) => v.hindi.length.toDouble()).toList();
    final total = weights.fold<double>(0, (a, b) => a + b);
    double running = 0;
    _ends = [
      for (final w in weights) (running += w) / total,
    ];

    try {
      WakelockPlus.enable();
    } catch (_) {}

    if (_audioMode) _initTts();
  }

  Future<void> _initTts() async {
    try {
      final tts = FlutterTts();
      await tts.awaitSpeakCompletion(true);
      final available = await tts.isLanguageAvailable('hi-IN');
      if (available == false) {
        if (mounted) setState(() => _noVoice = true);
      }
      await tts.setLanguage('hi-IN');
      await tts.setSpeechRate(0.42);
      await tts.setPitch(1.0);
      _tts = tts;
      if (mounted) setState(() => _ttsReady = true);
    } catch (_) {
      if (mounted) setState(() => _noVoice = true);
    }
  }

  @override
  void dispose() {
    _runId++;
    _timer?.cancel();
    _tts?.stop();
    try {
      WakelockPlus.disable();
    } catch (_) {}
    super.dispose();
  }

  void _scrollTo(int index) {
    final ctx = _keys[index].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      alignment: 0.3,
    );
  }

  void _play() {
    if (_finished) _resetState();
    setState(() {
      _playing = true;
      _started = true;
    });
    if (_audioMode) {
      _speakLoop();
    } else {
      _startTimer();
    }
  }

  void _pause() {
    _runId++;
    _timer?.cancel();
    _tts?.stop();
    setState(() => _playing = false);
  }

  void _resetState() {
    _runId++;
    _timer?.cancel();
    _tts?.stop();
    _current = 0;
    _elapsed = Duration.zero;
    _finished = false;
    _playing = false;
    _started = false;
  }

  void _restart() {
    setState(_resetState);
    _scrollTo(0);
  }

  Future<void> _speakLoop() async {
    final tts = _tts;
    if (tts == null) return;
    final id = ++_runId;
    int quickFailures = 0;

    while (mounted && _playing && id == _runId && _current < allVerses.length) {
      _scrollTo(_current);
      final started = DateTime.now();
      dynamic result;
      try {
        result = await tts.speak(allVerses[_current].hindi.replaceAll('\n', ' '));
      } catch (_) {
        result = 0;
      }
      if (!mounted || !_playing || id != _runId) return;

      final tookMs = DateTime.now().difference(started).inMilliseconds;
      if (result != 1 || tookMs < 400) {
        quickFailures++;
        if (quickFailures >= 2) {
          setState(() {
            _playing = false;
            _noVoice = true;
          });
          return;
        }
        continue; // retry the same verse once
      }
      quickFailures = 0;
      setState(() => _current++);
    }

    if (mounted && id == _runId && _current >= allVerses.length) {
      _complete();
    }
  }

  void _startTimer() {
    final total = widget.duration!;
    const tick = Duration(milliseconds: 250);
    _timer?.cancel();
    _scrollTo(_current);
    _timer = Timer.periodic(tick, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _elapsed += tick;
      if (_elapsed >= total) {
        timer.cancel();
        setState(() {
          _elapsed = total;
          _current = allVerses.length - 1;
        });
        _complete();
        return;
      }
      final share = _elapsed.inMilliseconds / total.inMilliseconds;
      int index = _ends.indexWhere((end) => share < end);
      if (index < 0) index = allVerses.length - 1;
      if (index != _current) {
        setState(() => _current = index);
        _scrollTo(index);
      } else {
        setState(() {}); // update countdown
      }
    });
  }

  void _complete() {
    if (_finished) return;
    setState(() {
      _finished = true;
      _playing = false;
    });
    settings.completePath();
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = _audioMode
        ? t('listen')
        : '${widget.duration!.inMinutes} ${t('minutes')}';

    final double progress;
    final String status;
    if (_audioMode) {
      final done = _finished ? allVerses.length : _current;
      progress = done / allVerses.length;
      final shown = _current < allVerses.length ? _current + 1 : allVerses.length;
      status = '${t('verse')} $shown / ${allVerses.length}';
    } else {
      final total = widget.duration!;
      progress = _elapsed.inMilliseconds / total.inMilliseconds;
      status = '${t('timeLeft')}  ${formatTime(total - _elapsed)}';
    }

    final canPlay = !_audioMode || (_ttsReady && !_noVoice);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: t('smaller'),
            icon: const Icon(Icons.text_decrease_rounded),
            onPressed: () => setState(() => settings.changeFont(-0.1)),
          ),
          IconButton(
            tooltip: t('larger'),
            icon: const Icon(Icons.text_increase_rounded),
            onPressed: () => setState(() => settings.changeFont(0.1)),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_noVoice)
            MaterialBanner(
              content: Text(t('noVoice')),
              leading: const Icon(Icons.record_voice_over_rounded),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _noVoice = false),
                  child: Text(t('ok')),
                ),
              ],
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                children: [
                  for (int i = 0; i < allVerses.length; i++)
                    _VerseCard(
                      key: _keys[i],
                      verse: allVerses[i],
                      highlighted: _started && i == _current && !_finished,
                      expanded: _started && i == _current && !_finished,
                    ),
                  const SizedBox(height: 16),
                  Text(
                    t('siyavar'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary),
                  ),
                ],
              ),
            ),
          ),
          Material(
            elevation: 8,
            color: scheme.surfaceContainer,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0).toDouble(),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(status,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                              if (_audioMode)
                                Text(t('voiceNote'),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: t('restart'),
                          icon: const Icon(Icons.replay_rounded),
                          onPressed: _started ? _restart : null,
                        ),
                        const SizedBox(width: 8),
                        FloatingActionButton(
                          heroTag: null,
                          onPressed: !canPlay
                              ? null
                              : (_playing ? _pause : _play),
                          tooltip: _playing
                              ? t('pause')
                              : (_started && !_finished
                                  ? t('resume')
                                  : t('play')),
                          child: Icon(
                            _playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 34,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mala counter
// ---------------------------------------------------------------------------

class CounterScreen extends StatelessWidget {
  const CounterScreen({super.key});

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('resetQ')),
        content: Text(t('resetMsg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t('reset')),
          ),
        ],
      ),
    );
    if (ok == true) settings.resetCounter();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(t('counter')),
        actions: [
          IconButton(
            tooltip: t('reset'),
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: () => _confirmReset(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          final progress = settings.counter / settings.malaTarget;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 11, label: Text('11')),
                      ButtonSegment(value: 21, label: Text('21')),
                      ButtonSegment(value: 108, label: Text('108')),
                    ],
                    selected: {settings.malaTarget},
                    onSelectionChanged: (s) => settings.setMalaTarget(s.first),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${t('roundsDone')}: ${settings.malaRounds}',
                    style:
                        TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
                  ),
                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          final done = settings.increment();
                          if (done) {
                            HapticFeedback.heavyImpact();
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(t('roundDone'))),
                            );
                          } else {
                            HapticFeedback.lightImpact();
                          }
                        },
                        child: SizedBox(
                          width: 260,
                          height: 260,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 260,
                                height: 260,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 12,
                                  backgroundColor:
                                      scheme.surfaceContainerHighest,
                                ),
                              ),
                              Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: scheme.primary,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${settings.counter}',
                                      style: TextStyle(
                                        fontSize: 64,
                                        fontWeight: FontWeight.bold,
                                        color: scheme.onPrimary,
                                      ),
                                    ),
                                    Text(
                                      '/ ${settings.malaTarget}',
                                      style: TextStyle(
                                          fontSize: 16,
                                          color: scheme.onPrimary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    t('tapCircle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
