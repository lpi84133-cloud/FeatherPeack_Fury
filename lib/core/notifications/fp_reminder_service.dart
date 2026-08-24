import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules and cancels the user's daily hiking reminder.
///
/// These are LOCAL notifications only — generated entirely on-device by the OS
/// scheduler, with no network dependency. They are isolated to a dedicated
/// channel id ('fp_hiking_daily') and have nothing to do with remote / Firebase
/// push notifications: iOS sandboxes notifications per bundle identifier, so
/// the two systems cannot interfere with each other.
///
/// Permission is never requested on launch — it is requested the moment the
/// user turns the toggle on for the first time.
class FpReminderService {
  FpReminderService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Stable numeric id kept far from 0 to avoid accidental collisions.
  static const _id = 73;
  static const _channelId = 'fp_hiking_daily';

  static bool _ready = false;

  static Future<void> _ensureReady() async {
    if (_ready) return;

    tz_data.initializeTimeZones();
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));

    await _plugin.initialize(
      settings: const InitializationSettings(
        iOS: DarwinInitializationSettings(
          // Permissions are requested separately, only when the user opts in.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    _ready = true;
  }

  /// Asks iOS for notification permission. Returns true if granted.
  static Future<bool> requestPermission() async {
    await _ensureReady();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            sound: true,
            badge: true,
          ) ??
          false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    return false;
  }

  /// Cancels any existing reminder and schedules a new one at [hour]:[minute]
  /// every day. [DateTimeComponents.time] tells the OS to repeat it daily at
  /// the same local time without any extra scheduling on our side.
  static Future<void> schedule(int hour, int minute) async {
    await _ensureReady();
    await _plugin.cancel(id: _id);
    await _plugin.zonedSchedule(
      id: _id,
      title: _pickTitle(),
      body: _pickBody(),
      scheduledDate: _nextOccurrence(hour, minute),
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(
          categoryIdentifier: _channelId,
        ),
        android: AndroidNotificationDetails(
          _channelId,
          'Daily hiking reminder',
          channelDescription:
              'A daily nudge to keep your trip plans up to date.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Cancels the scheduled reminder without touching saved settings.
  static Future<void> cancel() async {
    await _ensureReady();
    await _plugin.cancel(id: _id);
  }

  static tz.TZDateTime _nextOccurrence(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var target = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }

  // Seven titles, seven bodies — one pair per weekday so the message
  // varies throughout the week without repeating two days in a row.
  static const _titles = [
    'Your trail is waiting.',
    'Pack check before the path.',
    'Good trips start with good prep.',
    'One plan, one less thing to worry about.',
    'Ready when the weather is.',
    'A minute now, a smooth start on the day.',
    'The mountain won\'t plan itself.',
  ];

  static const _bodies = [
    'Open Featherpeak and check your gear list before the weather changes.',
    'A well-planned hike starts the night before — is your kit sorted?',
    'Check your open trips. A small update now beats a scramble at the trailhead.',
    'Gear listed, water checked, budget set. Your pack is ready when you are.',
    'Even a day hike deserves a plan. Finish the last few details.',
    'Don\'t leave the weight check for the car park. A quick look saves your back.',
    'Your next trail won\'t plan itself. Five minutes today saves an hour tomorrow.',
  ];

  static String _pickTitle() =>
      _titles[DateTime.now().weekday % _titles.length];

  static String _pickBody() =>
      _bodies[(DateTime.now().day + DateTime.now().month) % _bodies.length];
}
