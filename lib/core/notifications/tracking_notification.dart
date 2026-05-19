import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// A persistent "we're recording your location" banner that mirrors the
/// active track recordings. Mounted as a regular Android notification
/// (separate from geolocator's foreground-service indicator) so we control
/// its lock-screen visibility, prominence, and copy.
class TrackingNotification {
  TrackingNotification._();

  static final TrackingNotification instance = TrackingNotification._();

  static const _notificationId = 1001;
  static const _channelId = 'mappy_tracking_banner';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    // Use the launcher mipmap so the banner is unmistakably ours.
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(init);

    // On Android 13+ we must request POST_NOTIFICATIONS at runtime. The app
    // already declares the permission in the manifest; this prompts the user.
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      try {
        await android.requestNotificationsPermission();
      } catch (_) {
        // Older OS / unsupported — ignore.
      }
    }
    _initialized = true;
  }

  /// Show or update the tracking banner. Safe to call repeatedly with new
  /// contents — Android coalesces by [_notificationId].
  Future<void> show({required String title, required String body}) async {
    await _ensureInit();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Active tracking',
        channelDescription:
            'Shown while Mappy is recording your GPS track in the background.',
        importance: Importance.high,
        priority: Priority.high,
        // PUBLIC means the full notification (title + body) renders on the
        // lock screen — that's the explicit point of this banner.
        visibility: NotificationVisibility.public,
        ongoing: true,
        autoCancel: false,
        category: AndroidNotificationCategory.service,
        showWhen: true,
        usesChronometer: true,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
        ),
        ticker: 'Recording GPS track',
      ),
    );
    try {
      await _plugin.show(_notificationId, title, body, details);
    } catch (e, st) {
      debugPrint('TrackingNotification.show failed: $e\n$st');
    }
  }

  /// Dismiss the banner. Safe to call when nothing is showing.
  Future<void> cancel() async {
    try {
      await _plugin.cancel(_notificationId);
    } catch (e) {
      debugPrint('TrackingNotification.cancel failed: $e');
    }
  }
}
