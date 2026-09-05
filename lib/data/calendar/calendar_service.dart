import 'package:device_calendar/device_calendar.dart';

/// Cihaz takvimini okur. Ürünün "dolu açılma" numarası burada.
///
/// Takvim verisi uygulamaya kopyalanmaz; her açılışta cihazdan okunur. Kopya
/// tutmak eşitleme sorunu doğurur ve gizlilik vaadini zayıflatır.
class CalendarService {
  CalendarService([DeviceCalendarPlugin? plugin])
    : _plugin = plugin ?? DeviceCalendarPlugin();

  final DeviceCalendarPlugin _plugin;

  /// Yalnızca sorar, istemez: açılışta kullanılır.
  Future<bool> hasPermission() async {
    final has = await _plugin.hasPermissions();
    return has.isSuccess && (has.data ?? false);
  }

  /// İzin ister; verilmişse true. İzin isteği kurulumda değil, kullanıcı
  /// "takvimimi bağla" dediği anda yapılır — o an ne için istendiği açık.
  Future<bool> ensurePermission() async {
    final has = await _plugin.hasPermissions();
    if (has.isSuccess && (has.data ?? false)) return true;
    final asked = await _plugin.requestPermissions();
    return asked.isSuccess && (asked.data ?? false);
  }

  /// Günün etkinlikleri, tüm takvimlerden, başlangıca göre sıralı.
  Future<List<CalendarEvent>> eventsOn(DateTime day) async {
    final calendars = await _plugin.retrieveCalendars();
    if (!calendars.isSuccess || calendars.data == null) return const [];

    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final out = <CalendarEvent>[];

    for (final cal in calendars.data!) {
      final result = await _plugin.retrieveEvents(
        cal.id,
        RetrieveEventsParams(startDate: start, endDate: end),
      );
      for (final e in result.data ?? const <Event>[]) {
        if (e.start == null) continue;
        out.add(
          CalendarEvent(
            id: e.eventId ?? '${cal.id}-${e.start}',
            title: e.title ?? '(no title)',
            start: e.start!.toLocal(),
            end: (e.end ?? e.start!).toLocal(),
            allDay: e.allDay ?? false,
            calendarName: cal.name ?? '',
            colorValue: cal.color,
          ),
        );
      }
    }
    out.sort((a, b) => a.start.compareTo(b.start));
    return out;
  }
}

/// Akışta gösterilen sadeleştirilmiş etkinlik. Eklentinin `Event` tipi
/// arayüze sızmaz; eklenti değişirse yalnızca bu dosya değişir.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
    required this.calendarName,
    this.colorValue,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String calendarName;
  final int? colorValue;
}
