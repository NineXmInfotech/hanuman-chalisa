import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'main.dart';

/// Daily / weekly reminder notifications to recite the Chalisa.
class ReminderService {
  ReminderService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(_guessLocation());
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(const InitializationSettings(android: android));
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// Picks a time zone matching the phone's current offset (India → Asia/Kolkata).
  static tz.Location _guessLocation() {
    final offset = DateTime.now().timeZoneOffset;
    if (offset == const Duration(hours: 5, minutes: 30)) {
      return tz.getLocation('Asia/Kolkata');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final loc in tz.timeZoneDatabase.locations.values) {
      if (loc.timeZone(now).offset == offset.inMilliseconds) return loc;
    }
    return tz.UTC;
  }

  static Future<bool> requestPermission() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Replaces all reminders with one per selected weekday (1 = Monday … 7 = Sunday).
  static Future<void> schedule({
    required bool enabled,
    required int hour,
    required int minute,
    required List<int> weekdays,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      if (!enabled) return;
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'chalisa_reminder',
          'Hanuman Chalisa reminder',
          channelDescription: 'Reminder to recite the Hanuman Chalisa',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
      for (final day in weekdays) {
        await _plugin.zonedSchedule(
          day,
          t('reminderTitle'),
          t('reminderBody'),
          _next(day, hour, minute),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    } catch (_) {}
  }

  static tz.TZDateTime _next(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var date = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (date.weekday != weekday || !date.isAfter(now)) {
      date = date.add(const Duration(days: 1));
    }
    return date;
  }
}

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  late bool _enabled = settings.reminderOn;
  late TimeOfDay _time =
      TimeOfDay(hour: settings.reminderHour, minute: settings.reminderMinute);
  late final Set<int> _days = settings.reminderDays.toSet();

  static const _dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  Future<void> _save() async {
    if (_enabled) await ReminderService.requestPermission();
    final days = _days.toList()..sort();
    settings.setReminder(_enabled, _time.hour, _time.minute, days);
    await ReminderService.schedule(
        enabled: _enabled, hour: _time.hour, minute: _time.minute, weekdays: days);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_enabled ? t('reminderSaved') : t('reminderOff'))),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(t('reminder'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SwitchListTile(
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
            title: Text(t('reminderEnable'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          Opacity(
            opacity: _enabled ? 1 : 0.4,
            child: IgnorePointer(
              ignoring: !_enabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Material(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () async {
                        final picked =
                            await showTimePicker(context: context, initialTime: _time);
                        if (picked != null) setState(() => _time = picked);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            const Icon(Icons.alarm_rounded, size: 32),
                            const SizedBox(width: 16),
                            Text(t('reminderTime'), style: const TextStyle(fontSize: 16)),
                            const Spacer(),
                            Text(_time.format(context),
                                style: const TextStyle(
                                    fontSize: 26, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(t('reminderDays'),
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (int d = 1; d <= 7; d++)
                        FilterChip(
                          label: Text(t(_dayKeys[d - 1])),
                          selected: _days.contains(d),
                          onSelected: (on) => setState(() {
                            if (on) {
                              _days.add(d);
                            } else if (_days.length > 1) {
                              _days.remove(d);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _save,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(t('save'), style: const TextStyle(fontSize: 17)),
            ),
          ),
        ],
      ),
    );
  }
}
