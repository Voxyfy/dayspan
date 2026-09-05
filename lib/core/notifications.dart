import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Yerel bildirim sarmalayıcısı.
///
/// [initialize] çağrılmadan tamamen sessizdir: eklenti kanalı olmayan test
/// ortamında her çağrı `MissingPluginException` fırlatır ve widget testleri
/// uygulamayı kuramazdı. Yalnızca `main()` uyandırır.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Sabah özetinin sabit kimliği; her planlama öncekinin üstüne yazar.
  static const morningBriefId = 1;

  /// Hatırlatıcı kimlikleri bu değerden başlar; altındakiler tekil
  /// bildirimlere (özet) ayrılmıştır. [cancelReminders] bu sınıra bakar.
  static const reminderIdBase = 10000;

  /// iOS bekleyen bildirim sayısını 64'te kesiyor; özet ve pay bırakılır.
  static const maxPendingReminders = 56;

  static const _channelId = 'dayspan_brief';
  static const _channelName = 'Morning brief';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  bool get isReady => _ready;

  Future<void> initialize() async {
    try {
      tz_data.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          iOS: DarwinInitializationSettings(
            // İzin, kullanıcı özeti açtığı anda istenir; açılışta değil.
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _ready = true;
    } catch (error, stack) {
      debugPrint('Notifications unavailable: $error\n$stack');
      _ready = false;
    }
  }

  Future<bool> requestPermission() async {
    if (!_ready) return false;
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? false;
  }

  /// Sabah özetini bir sonraki [hour]:00'a kurar; önceki iptal edilir.
  ///
  /// Tekrarlayan bildirim yerine tek atış: metin o günün verisine göre
  /// yazılıyor ve uygulama her açıldığında yeniden kuruluyor. Tekrarlayan
  /// bildirim aynı metni her sabah okurdu.
  Future<void> scheduleMorningBrief({
    required int hour,
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    await _plugin.cancel(id: morningBriefId);

    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id: morningBriefId,
      title: title,
      body: body,
      scheduledDate: at,
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Tek atış hatırlatıcı; [at] geçmişteyse kurulmaz.
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    if (!_ready) return;
    final when = tz.TZDateTime.from(at, tz.local);
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) return;
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: when,
      notificationDetails: _reminderDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Tekrarlayan hatırlatıcı: [weekday] verilirse (1 = pazartesi … 7 = pazar)
  /// o gün aynı saatte her hafta, verilmezse her gün.
  Future<void> scheduleRepeating({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    int? weekday,
  }) async {
    if (!_ready) return;
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (weekday != null) {
      at = at.add(Duration(days: (weekday - at.weekday) % 7));
    }
    if (!at.isAfter(now)) at = at.add(Duration(days: weekday == null ? 1 : 7));
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: at,
      notificationDetails: _reminderDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: weekday == null
          ? DateTimeComponents.time
          : DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// Tüm hatırlatıcıları kaldırır, özete dokunmaz. Planlayıcı her veri
  /// değişiminde önce bunu çağırır, sonra hepsini yeniden kurar: tek tek
  /// fark almak yerine sıfırdan kurmak, kaçan bir iptal bırakmaz.
  Future<void> cancelReminders() async {
    if (!_ready) return;
    final pending = await _plugin.pendingNotificationRequests();
    for (final p in pending) {
      if (p.id >= reminderIdBase) await _plugin.cancel(id: p.id);
    }
  }

  static const _reminderDetails = NotificationDetails(
    iOS: DarwinNotificationDetails(
      interruptionLevel: InterruptionLevel.timeSensitive,
    ),
    android: AndroidNotificationDetails(
      _reminderChannelId,
      _reminderChannelName,
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static const _reminderChannelId = 'dayspan_reminders';
  static const _reminderChannelName = 'Reminders';

  Future<void> cancelMorningBrief() async {
    if (!_ready) return;
    await _plugin.cancel(id: morningBriefId);
  }
}
