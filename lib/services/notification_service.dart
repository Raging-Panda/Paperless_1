import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── Notification IDs ──────────────────────────────────────────────────────
  static const int _streakId = 1;
  static const int _returnBase = 100; // 100 + (receiptId % 100)
  static const int _budgetBase = 200; // 200 + (category.hashCode % 100)

  // ── Android channels ──────────────────────────────────────────────────────
  static const _streakDetails = AndroidNotificationDetails(
    'streak_reminders',
    'Streak Reminders',
    channelDescription: 'Daily reminders to maintain your scan streak',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _returnDetails = AndroidNotificationDetails(
    'receipt_reminders',
    'Receipt Reminders',
    channelDescription: 'Return window and warranty expiry reminders',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static const _budgetDetails = AndroidNotificationDetails(
    'budget_alerts',
    'Budget Alerts',
    channelDescription:
        'Alerts when spending approaches or exceeds budget limits',
    importance: Importance.high,
    priority: Priority.high,
  );

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios));
    _initialized = true;
  }

  /// Request notification permission from the OS.
  /// On Android this shows the system dialog once; on iOS it shows it once too.
  Future<void> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
      return;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      await ios.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  // ── Streak reminder ───────────────────────────────────────────────────────

  /// Schedule a streak-at-risk notification for 7 pm tomorrow.
  /// Cancels any existing streak notification first.
  /// Call after every successful receipt save.
  Future<void> scheduleStreakReminder(int streakDays) async {
    if (streakDays <= 0) return;
    await cancelStreakReminder();
    final now = DateTime.now();
    final tomorrow7pm =
        DateTime(now.year, now.month, now.day + 1, 19, 0);
    await _plugin.zonedSchedule(
      _streakId,
      '🔥 Streak at risk!',
      'Your $streakDays-day streak is at risk. Scan a receipt today to keep it going!',
      tz.TZDateTime.from(tomorrow7pm, tz.local),
      const NotificationDetails(
          android: _streakDetails, iOS: DarwinNotificationDetails()),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancel the streak-at-risk notification (called when user scans).
  Future<void> cancelStreakReminder() => _plugin.cancel(_streakId);

  // ── Return window reminder ────────────────────────────────────────────────

  /// Schedule a notification 28 days after the receipt date (2 days before
  /// the standard 30-day return window closes).
  Future<void> scheduleReturnReminder(
      int receiptId, String storeName, DateTime receiptDate) async {
    final reminderDate = receiptDate.add(const Duration(days: 28));
    if (!reminderDate.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      _returnBase + (receiptId.abs() % 100),
      '⏰ Return window closing soon',
      'You have 2 days left to return items from $storeName.',
      tz.TZDateTime.from(reminderDate, tz.local),
      const NotificationDetails(
          android: _returnDetails, iOS: DarwinNotificationDetails()),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ── Budget alert ──────────────────────────────────────────────────────────

  /// Show an immediate notification if [spent] has crossed 80 % or 100 %
  /// of [budget] for the given [category].
  Future<void> checkBudgetAlert(
      String category, double spent, double budget) async {
    if (budget <= 0) return;
    final pct = spent / budget;
    if (pct < 0.8) return;
    final exceeded = pct >= 1.0;
    final pctLabel = '${(pct * 100).round()}%';
    await _plugin.show(
      _budgetBase + (category.hashCode.abs() % 100),
      exceeded ? '🚨 Budget exceeded' : '⚠️ Budget alert',
      exceeded
          ? "You've exceeded your $category budget."
          : "You've used $pctLabel of your $category budget.",
      const NotificationDetails(
          android: _budgetDetails, iOS: DarwinNotificationDetails()),
    );
  }
}
