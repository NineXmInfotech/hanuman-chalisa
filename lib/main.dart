import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chalisa_data.dart';

late final AppSettings settings;

const Color saffron = Color(0xFFE65100);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  settings = AppSettings(prefs);
  runApp(const ChalisaApp());
}

// ---------------------------------------------------------------------------
// Settings & saved progress
// ---------------------------------------------------------------------------

class AppSettings extends ChangeNotifier {
  AppSettings(SharedPreferences prefs)
      : _prefs = prefs,
        fontScale = prefs.getDouble('fontScale') ?? 1.0,
        showRoman = prefs.getBool('showRoman') ?? false,
        showAllMeanings = prefs.getBool('showAllMeanings') ?? false,
        themeIndex = prefs.getInt('themeIndex') ?? 0,
        pathCount = prefs.getInt('pathCount') ?? 0,
        malaTarget = prefs.getInt('malaTarget') ?? 108,
        counter = prefs.getInt('counter') ?? 0,
        malaRounds = prefs.getInt('malaRounds') ?? 0;

  final SharedPreferences _prefs;

  double fontScale;
  bool showRoman;
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

  void setThemeIndex(int value) {
    themeIndex = value;
    _prefs.setInt('themeIndex', value);
    notifyListeners();
  }

  void changeFont(double delta) {
    double next = fontScale + delta;
    if (next < 0.8) next = 0.8;
    if (next > 2.0) next = 2.0;
    fontScale = next;
    _prefs.setDouble('fontScale', fontScale);
    notifyListeners();
  }

  void toggleRoman() {
    showRoman = !showRoman;
    _prefs.setBool('showRoman', showRoman);
    notifyListeners();
  }

  void toggleAllMeanings() {
    showAllMeanings = !showAllMeanings;
    _prefs.setBool('showAllMeanings', showAllMeanings);
    notifyListeners();
  }

  void completePath() {
    pathCount++;
    _prefs.setInt('pathCount', pathCount);
    notifyListeners();
  }

  void setMalaTarget(int value) {
    malaTarget = value;
    if (counter >= malaTarget) counter = 0;
    _prefs.setInt('malaTarget', malaTarget);
    _prefs.setInt('counter', counter);
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
      _prefs.setInt('malaRounds', malaRounds);
    }
    _prefs.setInt('counter', counter);
    notifyListeners();
    return roundDone;
  }

  void resetCounter() {
    counter = 0;
    malaRounds = 0;
    _prefs.setInt('counter', 0);
    _prefs.setInt('malaRounds', 0);
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
                    24, MediaQuery.of(context).padding.top + 16, 8, 32),
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
                        const Expanded(
                          child: Text(
                            'जय श्री राम',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        _ThemeMenu(),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '🚩',
                      style: TextStyle(fontSize: 48),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'श्री हनुमान चालीसा',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Shri Hanuman Chalisa',
                      style: TextStyle(color: Colors.white, fontSize: 18),
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
                            label: 'Paths completed',
                            value: '${settings.pathCount}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatTile(
                            label: 'Mala rounds',
                            value: '${settings.malaRounds}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _BigButton(
                      icon: Icons.menu_book_rounded,
                      title: 'Read Chalisa',
                      subtitle: 'With meaning of every verse',
                      color: scheme.primary,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ReaderScreen()),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _BigButton(
                      icon: Icons.touch_app_rounded,
                      title: 'Mala Counter',
                      subtitle: 'Count 11, 21 or 108 recitations',
                      color: scheme.tertiary,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const CounterScreen()),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Composed by Goswami Tulsidas',
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

class _ThemeMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      icon: const Icon(Icons.brightness_6_rounded, color: Colors.white),
      tooltip: 'Theme',
      initialValue: settings.themeIndex,
      onSelected: settings.setThemeIndex,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 0, child: Text('System default')),
        PopupMenuItem(value: 1, child: Text('Light')),
        PopupMenuItem(value: 2, child: Text('Dark')),
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
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: color,
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w600)),
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
      SnackBar(
        content: Text(
            'जय बजरंगबली! 🙏  Path ${settings.pathCount} completed'),
      ),
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
            title: const Text('हनुमान चालीसा'),
            actions: [
              IconButton(
                tooltip: 'Smaller text',
                icon: const Icon(Icons.text_decrease_rounded),
                onPressed: () => settings.changeFont(-0.1),
              ),
              IconButton(
                tooltip: 'Larger text',
                icon: const Icon(Icons.text_increase_rounded),
                onPressed: () => settings.changeFont(0.1),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'script') settings.toggleRoman();
                  if (value == 'meaning') settings.toggleAllMeanings();
                },
                itemBuilder: (context) => [
                  CheckedPopupMenuItem(
                    value: 'script',
                    checked: settings.showRoman,
                    child: const Text('English letters'),
                  ),
                  CheckedPopupMenuItem(
                    value: 'meaning',
                    checked: settings.showAllMeanings,
                    child: const Text('Show all meanings'),
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
                    settings.showRoman
                        ? 'Tap any verse to see its meaning'
                        : 'अर्थ देखने के लिए किसी भी पंक्ति पर टैप करें',
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
                        '॥ सियावर रामचंद्र की जय ॥',
                        style: TextStyle(
                            fontSize: 18 * settings.fontScale,
                            fontWeight: FontWeight.w600,
                            color: scheme.primary),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _finish,
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          child: Text('Path complete',
                              style: TextStyle(fontSize: 17)),
                        ),
                      ),
                    ],
                  ),
                );
              }
              final i = index - 1;
              final verse = allVerses[i];
              final expanded = settings.showAllMeanings || _open.contains(i);
              return _VerseCard(
                verse: verse,
                expanded: expanded,
                onTap: () => setState(() {
                  if (_open.contains(i)) {
                    _open.remove(i);
                  } else {
                    _open.add(i);
                  }
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
    required this.verse,
    required this.expanded,
    required this.onTap,
  });

  final Verse verse;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDoha = verse.kind == VerseKind.doha;
    final label = isDoha
        ? (settings.showRoman ? 'Doha' : 'दोहा')
        : (settings.showRoman ? 'Chaupai ${verse.number}' : 'चौपाई ${verse.number}');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      color: isDoha ? scheme.primaryContainer : scheme.surfaceContainerLow,
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
                label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                    letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                settings.showRoman ? verse.roman : verse.hindi,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20 * settings.fontScale,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
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
                      verse.meaning,
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
// Mala counter
// ---------------------------------------------------------------------------

class CounterScreen extends StatelessWidget {
  const CounterScreen({super.key});

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset counter?'),
        content: const Text('This clears the current count and mala rounds.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
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
        title: const Text('Mala Counter'),
        actions: [
          IconButton(
            tooltip: 'Reset',
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
                    'Rounds completed: ${settings.malaRounds}',
                    style: TextStyle(
                        fontSize: 16, color: scheme.onSurfaceVariant),
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
                              const SnackBar(
                                  content: Text('Mala round complete 🙏')),
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
                                      'of ${settings.malaTarget}',
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
                    'Tap the circle after each recitation',
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
