import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/segment.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));

    // Safety alert channel — max priority, vibration
    const safetyChannel = AndroidNotificationChannel(
      'radioscribe_safety',
      'Safety Alerts',
      description: 'Critical safety keywords detected on radio',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
    );

    // Warning channel — high priority
    const warningChannel = AndroidNotificationChannel(
      'radioscribe_warning',
      'Warnings',
      description: 'Warning keywords detected on radio',
      importance: Importance.high,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(safetyChannel);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(warningChannel);

    _initialized = true;
  }

  Future<void> showAlert({
    required SegmentAlert alert,
    required List<String> keywords,
    required String text,
  }) async {
    if (!_initialized) await init();
    if (alert == SegmentAlert.none) return;

    final isSafety = alert == SegmentAlert.safety;
    final id = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
    final title = isSafety ? '🚨 SAFETY ALERT' : '⚠️ WARNING';
    final keywordStr = keywords.join(', ').toUpperCase();
    final body = '$keywordStr — ${text.length > 80 ? '${text.substring(0, 80)}…' : text}';

    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          isSafety ? 'radioscribe_safety' : 'radioscribe_warning',
          isSafety ? 'Safety Alerts' : 'Warnings',
          importance: isSafety ? Importance.max : Importance.high,
          priority: isSafety ? Priority.max : Priority.high,
          enableVibration: true,
          ticker: title,
        ),
      ),
    );
  }
}
