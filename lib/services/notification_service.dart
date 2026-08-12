import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper around flutter_local_notifications for the "you've crossed
/// your estimate" alert. Permission is only ever requested when
/// [requestPermissionOnce] is called explicitly (the first time a timer
/// starts) — never during [_ensureInitialized], so nothing prompts the user
/// just from launching the app.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _channelId = 'estimate_alerts';
  static const _channelName = 'Estimate alerts';
  static const _channelDescription =
      'Alerts when a running timer crosses its estimate';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _permissionRequested = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    // requestAlertPermission etc. default to true on iOS/macOS, which would
    // prompt during initialize() — turn that off so requestPermissionOnce()
    // controls the timing instead.
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      ),
    );
  }

  /// Requests notification permission. Only prompts the user the first time
  /// it's called per app run; safe to call from every timer start.
  Future<void> requestPermissionOnce() async {
    if (_permissionRequested) return;
    _permissionRequested = true;
    await _ensureInitialized();

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> showOverEstimate({
    required String taskName,
    required String estimateLabel,
  }) async {
    await _ensureInitialized();
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      id: taskName.hashCode,
      title: 'Over estimate',
      body: 'Over your $estimateLabel estimate for "$taskName".',
      notificationDetails: details,
    );
  }
}
