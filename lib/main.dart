import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, File, Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:tray_manager/tray_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  try {
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
  } catch (_) {}

  if (isWindowsDesktop) {
    await setupSafeWindowsWindow();
  }

  await LocalNotify.init();
  runApp(const LunarFamilyApp());
}

bool get isWindowsDesktop => !kIsWeb && Platform.isWindows;
bool get isAndroid => !kIsWeb && Platform.isAndroid;
bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

Future<void> setupSafeWindowsWindow() async {
  await windowManager.ensureInitialized();

  Size windowSize = const Size(1180, 760);
  Offset windowPosition = const Offset(40, 40);

  try {
    final display = await screenRetriever.getPrimaryDisplay();
    final visibleSize = display.visibleSize ?? display.size;
    final visiblePosition = display.visiblePosition ?? Offset.zero;

    final safeWidth = max(720.0, min(1180.0, visibleSize.width - 40.0));
    final safeHeight = max(520.0, min(760.0, visibleSize.height - 70.0));

    windowSize = Size(safeWidth, safeHeight);

    final dx = visiblePosition.dx + max(8.0, (visibleSize.width - safeWidth) / 2);
    final dy = visiblePosition.dy + max(8.0, (visibleSize.height - safeHeight) / 2);
    windowPosition = Offset(dx, dy);
  } catch (_) {
    windowSize = const Size(1100, 700);
    windowPosition = const Offset(40, 40);
  }

  final options = WindowOptions(
    title: 'Lịch âm gia tộc',
    size: windowSize,
    minimumSize: const Size(720, 520),
    center: false,
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.normal,
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setTitle('Lịch âm gia tộc');
    await windowManager.setResizable(true);
    await windowManager.setMinimizable(true);
    await windowManager.setMaximizable(true);
    await windowManager.setFullScreen(false);
    await windowManager.unmaximize();
    await windowManager.setSize(windowSize);
    await windowManager.setPosition(windowPosition);
    await windowManager.show();
    await windowManager.focus();
  });
}



Future<String> resolveWindowsTrayIconPath() async {
  if (!isWindowsDesktop) return 'assets/icons/app_icon.ico';

  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final currentDir = Directory.current.path;

  final candidates = <String>[
    '$exeDir\\data\\flutter_assets\\assets\\icons\\app_icon.ico',
    '$exeDir\\assets\\icons\\app_icon.ico',
    '$currentDir\\assets\\icons\\app_icon.ico',
    'assets\\icons\\app_icon.ico',
    'assets/icons/app_icon.ico',
  ];

  for (final path in candidates) {
    try {
      if (File(path).existsSync()) return path;
    } catch (_) {}
  }

  return candidates.first;
}

enum CalendarViewMode { week, month, year, fiveYear, events, stats, google }
enum RepeatType { monthly, quarterly, yearly }

String modeLabel(CalendarViewMode m) {
  switch (m) {
    case CalendarViewMode.week:
      return 'Tuần';
    case CalendarViewMode.month:
      return 'Tháng';
    case CalendarViewMode.year:
      return 'Năm';
    case CalendarViewMode.fiveYear:
      return '5 năm';
    case CalendarViewMode.events:
      return 'Danh sách sự kiện';
    case CalendarViewMode.stats:
      return 'Thống kê năm';
    case CalendarViewMode.google:
      return 'Google';
  }
}

String repeatLabel(RepeatType r) {
  switch (r) {
    case RepeatType.monthly:
      return 'Hằng tháng âm';
    case RepeatType.quarterly:
      return 'Hằng quý âm';
    case RepeatType.yearly:
      return 'Hằng năm âm';
  }
}

String two(int n) => n.toString().padLeft(2, '0');
String fmtDate(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';
String fmtDateTime(DateTime d) => '${fmtDate(d)} ${two(d.hour)}:${two(d.minute)}';
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

class LunarDate {
  final int day;
  final int month;
  final int year;
  final bool leap;

  const LunarDate(this.day, this.month, this.year, [this.leap = false]);

  String get text => '$day/$month/$year${leap ? ' nhuận' : ''}';
}

class LunarCalc {
  static const double pi = 3.141592653589793;
  static const double timeZone = 7.0;

  static int jdFromDate(int dd, int mm, int yy) {
    final a = ((14 - mm) / 12).floor();
    final y = yy + 4800 - a;
    final m = mm + 12 * a - 3;
    var jd = dd +
        (((153 * m + 2) / 5).floor()) +
        365 * y +
        (y / 4).floor() -
        (y / 100).floor() +
        (y / 400).floor() -
        32045;
    if (jd < 2299161) {
      jd = dd + (((153 * m + 2) / 5).floor()) + 365 * y + (y / 4).floor() - 32083;
    }
    return jd;
  }

  static List<int> jdToDate(int jd) {
    int a, b, c;
    if (jd > 2299160) {
      a = jd + 32044;
      b = ((4 * a + 3) / 146097).floor();
      c = a - ((b * 146097) / 4).floor();
    } else {
      b = 0;
      c = jd + 32082;
    }
    final d = ((4 * c + 3) / 1461).floor();
    final e = c - ((1461 * d) / 4).floor();
    final m = ((5 * e + 2) / 153).floor();
    final day = e - ((153 * m + 2) / 5).floor() + 1;
    final month = m + 3 - 12 * (m / 10).floor();
    final year = b * 100 + d - 4800 + (m / 10).floor();
    return [day, month, year];
  }

  static double newMoon(int k) {
    final t = k / 1236.85;
    final t2 = t * t;
    final t3 = t2 * t;
    final dr = pi / 180;
    var jd1 = 2415020.75933 +
        29.53058868 * k +
        0.0001178 * t2 -
        0.000000155 * t3 +
        0.00033 * sin((166.56 + 132.87 * t - 0.009173 * t2) * dr);
    final m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3;
    final mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3;
    final f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3;
    var c1 = (0.1734 - 0.000393 * t) * sin(m * dr) +
        0.0021 * sin(2 * dr * m) -
        0.4068 * sin(mpr * dr) +
        0.0161 * sin(2 * dr * mpr) -
        0.0004 * sin(3 * dr * mpr) +
        0.0104 * sin(2 * dr * f) -
        0.0051 * sin((m + mpr) * dr) -
        0.0074 * sin((m - mpr) * dr) +
        0.0004 * sin((2 * f + m) * dr) -
        0.0004 * sin((2 * f - m) * dr) -
        0.0006 * sin((2 * f + mpr) * dr) +
        0.0010 * sin((2 * f - mpr) * dr) +
        0.0005 * sin((2 * mpr + m) * dr);
    final deltaT = t < -11
        ? 0.001 + 0.000839 * t + 0.0002261 * t2 - 0.00000845 * t3 - 0.000000081 * t * t3
        : -0.000278 + 0.000265 * t + 0.000262 * t2;
    return jd1 + c1 - deltaT;
  }

  static double sunLongitude(double jdn) {
    final t = (jdn - 2451545.0) / 36525;
    final t2 = t * t;
    final dr = pi / 180;
    final m = 357.52910 + 35999.05030 * t - 0.0001559 * t2 - 0.00000048 * t * t2;
    final l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2;
    var dl = (1.914600 - 0.004817 * t - 0.000014 * t2) * sin(dr * m);
    dl += (0.019993 - 0.000101 * t) * sin(2 * dr * m) + 0.000290 * sin(3 * dr * m);
    var l = l0 + dl;
    l = l * dr;
    l = l - pi * 2 * (l / (pi * 2)).floor();
    return l;
  }

  static int getNewMoonDay(int k) => (newMoon(k) + 0.5 + timeZone / 24).floor();
  static int getSunLongitude(int dayNumber) => (sunLongitude(dayNumber - 0.5 - timeZone / 24) / pi * 6).floor();

  static int getLunarMonth11(int yy) {
    final off = jdFromDate(31, 12, yy) - 2415021;
    final k = (off / 29.530588853).floor();
    var nm = getNewMoonDay(k);
    final sunLong = getSunLongitude(nm);
    if (sunLong >= 9) nm = getNewMoonDay(k - 1);
    return nm;
  }

  static int getLeapMonthOffset(int a11) {
    final k = ((a11 - 2415021.076998695) / 29.530588853 + 0.5).floor();
    var last = 0;
    var i = 1;
    var arc = getSunLongitude(getNewMoonDay(k + i));
    do {
      last = arc;
      i++;
      arc = getSunLongitude(getNewMoonDay(k + i));
    } while (arc != last && i < 14);
    return i - 1;
  }

  static LunarDate solarToLunar(DateTime date) {
    final dayNumber = jdFromDate(date.day, date.month, date.year);
    final k = ((dayNumber - 2415021.076998695) / 29.530588853).floor();
    var monthStart = getNewMoonDay(k + 1);
    if (monthStart > dayNumber) monthStart = getNewMoonDay(k);

    var a11 = getLunarMonth11(date.year);
    int b11;
    int lunarYear;
    if (a11 >= monthStart) {
      lunarYear = date.year;
      a11 = getLunarMonth11(date.year - 1);
      b11 = getLunarMonth11(date.year);
    } else {
      lunarYear = date.year + 1;
      b11 = getLunarMonth11(date.year + 1);
    }

    final lunarDay = dayNumber - monthStart + 1;
    final diff = ((monthStart - a11) / 29).floor();
    var lunarLeap = false;
    var lunarMonth = diff + 11;

    if (b11 - a11 > 365) {
      final leapMonthDiff = getLeapMonthOffset(a11);
      if (diff >= leapMonthDiff) {
        lunarMonth = diff + 10;
        if (diff == leapMonthDiff) lunarLeap = true;
      }
    }

    if (lunarMonth > 12) lunarMonth -= 12;
    if (lunarMonth >= 11 && diff < 4) lunarYear -= 1;
    return LunarDate(lunarDay, lunarMonth, lunarYear, lunarLeap);
  }

  static DateTime? lunarToSolar(int lunarDay, int lunarMonth, int lunarYear, bool lunarLeap) {
    try {
      int a11;
      int b11;
      if (lunarMonth < 11) {
        a11 = getLunarMonth11(lunarYear - 1);
        b11 = getLunarMonth11(lunarYear);
      } else {
        a11 = getLunarMonth11(lunarYear);
        b11 = getLunarMonth11(lunarYear + 1);
      }

      final k = ((a11 - 2415021.076998695) / 29.530588853 + 0.5).floor();
      var off = lunarMonth - 11;
      if (off < 0) off += 12;

      if (b11 - a11 > 365) {
        final leapOff = getLeapMonthOffset(a11);
        var leapMonth = leapOff - 2;
        if (leapMonth < 0) leapMonth += 12;
        if (lunarLeap && lunarMonth != leapMonth) return null;
        if (lunarLeap || off >= leapOff) off += 1;
      }

      final monthStart = getNewMoonDay(k + off);
      final solar = jdToDate(monthStart + lunarDay - 1);
      return DateTime(solar[2], solar[1], solar[0]);
    } catch (_) {
      return null;
    }
  }
}

class FamilyEvent {
  final String id;
  final String title;
  final String note;
  final int lunarDay;
  final int lunarMonth;
  final bool leap;
  final int hour;
  final int minute;
  final RepeatType repeat;
  final int remindBeforeDays;
  final int remindBeforeHours;

  const FamilyEvent({
    required this.id,
    required this.title,
    required this.note,
    required this.lunarDay,
    required this.lunarMonth,
    required this.leap,
    required this.hour,
    required this.minute,
    required this.repeat,
    required this.remindBeforeDays,
    required this.remindBeforeHours,
  });

  FamilyEvent copyWith({
    String? id,
    String? title,
    String? note,
    int? lunarDay,
    int? lunarMonth,
    bool? leap,
    int? hour,
    int? minute,
    RepeatType? repeat,
    int? remindBeforeDays,
    int? remindBeforeHours,
  }) {
    return FamilyEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      lunarDay: lunarDay ?? this.lunarDay,
      lunarMonth: lunarMonth ?? this.lunarMonth,
      leap: leap ?? this.leap,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      repeat: repeat ?? this.repeat,
      remindBeforeDays: remindBeforeDays ?? this.remindBeforeDays,
      remindBeforeHours: remindBeforeHours ?? this.remindBeforeHours,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'note': note,
        'lunarDay': lunarDay,
        'lunarMonth': lunarMonth,
        'leap': leap,
        'hour': hour,
        'minute': minute,
        'repeat': repeat.name,
        'remindBeforeDays': remindBeforeDays,
        'remindBeforeHours': remindBeforeHours,
      };

  static FamilyEvent fromJson(Map<String, dynamic> j) {
    RepeatType rp = RepeatType.yearly;
    final raw = j['repeat']?.toString();
    for (final r in RepeatType.values) {
      if (r.name == raw) rp = r;
    }
    return FamilyEvent(
      id: (j['id'] ?? DateTime.now().microsecondsSinceEpoch.toString()).toString(),
      title: (j['title'] ?? '').toString(),
      note: (j['note'] ?? '').toString(),
      lunarDay: (j['lunarDay'] as num?)?.toInt() ?? 1,
      lunarMonth: (j['lunarMonth'] as num?)?.toInt() ?? 1,
      leap: j['leap'] == true,
      hour: (j['hour'] as num?)?.toInt() ?? 7,
      minute: (j['minute'] as num?)?.toInt() ?? 0,
      repeat: rp,
      remindBeforeDays: (j['remindBeforeDays'] as num?)?.toInt() ?? 0,
      remindBeforeHours: (j['remindBeforeHours'] as num?)?.toInt() ?? 0,
    );
  }
}

class Store {
  static const _eventsKey = 'family_events_v2';
  static const _hideTrayKey = 'hide_to_tray';
  static const _startupKey = 'startup_enabled';
  static const _googleClientKey = 'google_client_id';
  static const _googleAccessKey = 'google_access_token';
  static const _googleRefreshKey = 'google_refresh_token';
  static const _googleExpiryKey = 'google_expiry_ms';

  static Future<List<FamilyEvent>> loadEvents() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_eventsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => FamilyEvent.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<void> saveEvents(List<FamilyEvent> events) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_eventsKey, jsonEncode(events.map((e) => e.toJson()).toList()));
  }

  static Future<bool> getHideToTray() async => (await SharedPreferences.getInstance()).getBool(_hideTrayKey) ?? true;
  static Future<void> setHideToTray(bool v) async => (await SharedPreferences.getInstance()).setBool(_hideTrayKey, v);

  static Future<bool> getStartup() async => (await SharedPreferences.getInstance()).getBool(_startupKey) ?? false;
  static Future<void> setStartup(bool v) async => (await SharedPreferences.getInstance()).setBool(_startupKey, v);

  static Future<String> getGoogleClientId() async => (await SharedPreferences.getInstance()).getString(_googleClientKey) ?? '';
  static Future<void> setGoogleClientId(String v) async => (await SharedPreferences.getInstance()).setString(_googleClientKey, v.trim());

  static Future<Map<String, dynamic>> getGoogleTokens() async {
    final sp = await SharedPreferences.getInstance();
    return {
      'access_token': sp.getString(_googleAccessKey) ?? '',
      'refresh_token': sp.getString(_googleRefreshKey) ?? '',
      'expiry_ms': sp.getInt(_googleExpiryKey) ?? 0,
    };
  }

  static Future<void> setGoogleTokens(String access, String refresh, int expiryMs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_googleAccessKey, access);
    if (refresh.isNotEmpty) await sp.setString(_googleRefreshKey, refresh);
    await sp.setInt(_googleExpiryKey, expiryMs);
  }

  static Future<void> clearGoogleTokens() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_googleAccessKey);
    await sp.remove(_googleRefreshKey);
    await sp.remove(_googleExpiryKey);
  }
}

List<DateTime> occurrencesForEvent(FamilyEvent e, int startYear, int endYear) {
  final out = <DateTime>[];
  for (var y = startYear; y <= endYear; y++) {
    Iterable<int> months;
    if (e.repeat == RepeatType.yearly) {
      months = [e.lunarMonth];
    } else if (e.repeat == RepeatType.quarterly) {
      months = List.generate(4, (i) => e.lunarMonth + i * 3).where((m) => m >= 1 && m <= 12);
    } else {
      months = List.generate(12, (i) => i + 1);
    }

    for (final m in months) {
      final solar = LunarCalc.lunarToSolar(e.lunarDay, m, y, e.repeat == RepeatType.yearly ? e.leap : false);
      if (solar != null) {
        out.add(DateTime(solar.year, solar.month, solar.day, e.hour, e.minute));
      }
    }
  }
  out.sort();
  return out;
}

class LocalNotify {
  static final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    const windows = WindowsInitializationSettings(
      appName: 'Lịch âm gia tộc',
      appUserModelId: 'com.example.lunar_calendar_app',
      guid: '4e39072a-7db9-4f67-9eaa-5d4d52f30c9f',
    );
    const settings = InitializationSettings(android: android, iOS: darwin, macOS: darwin, windows: windows);
    await plugin.initialize(settings);

    if (isAndroid) {
      try {
        await plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } catch (_) {}
      try {
        await plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestExactAlarmsPermission();
      } catch (_) {}
    }
  }

  static NotificationDetails details() {
    const android = AndroidNotificationDetails(
      'lunar_family_reminders',
      'Nhắc lịch âm gia tộc',
      channelDescription: 'Thông báo giỗ, chạp, ngày sinh, ngày mất theo lịch âm',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
    );
    const darwin = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
    const windows = WindowsNotificationDetails();
    return const NotificationDetails(android: android, iOS: darwin, macOS: darwin, windows: windows);
  }

  static int notificationId(String s) => s.codeUnits.fold<int>(17, (a, b) => (a * 37 + b) & 0x7fffffff);

  static Future<void> showNow(String title, String body) async {
    await plugin.show(notificationId('$title$body${DateTime.now()}'), title, body, details());
  }

  static Future<void> scheduleOnce(String key, String title, String body, DateTime when) async {
    if (when.isBefore(DateTime.now().add(const Duration(seconds: 5)))) return;
    final tzdt = tz.TZDateTime.from(when, tz.local);
    await plugin.zonedSchedule(
      notificationId(key),
      title,
      body,
      tzdt,
      details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> scheduleAll(List<FamilyEvent> events) async {
    try {
      await plugin.cancelAll();
      final now = DateTime.now();
      for (final e in events) {
        final occs = occurrencesForEvent(e, now.year, now.year + 2).where((d) => d.isAfter(now)).take(18);
        for (final dt in occs) {
          final remind = dt.subtract(Duration(days: e.remindBeforeDays, hours: e.remindBeforeHours));
          await scheduleOnce(
            '${e.id}_${dt.millisecondsSinceEpoch}',
            e.title,
            'Âm ${e.lunarDay}/${e.lunarMonth}${e.leap ? ' nhuận' : ''} • Dương ${fmtDate(dt)}',
            remind,
          );
        }
      }
    } catch (_) {}
  }
}

class QuoteBank {
  static final List<String> base = [
    'Không có gì quý hơn độc lập, tự do.',
    'Dĩ bất biến, ứng vạn biến.',
    'Học để làm việc, làm người, làm cán bộ.',
    'Lý luận mà không liên hệ với thực tiễn là lý luận suông.',
    'Thực tiễn không có lý luận hướng dẫn thì thành thực tiễn mù quáng.',
    'Đạo đức cách mạng không phải trên trời sa xuống.',
    'Việc gì có lợi cho dân thì hết sức làm.',
    'Đoàn kết, đoàn kết, đại đoàn kết. Thành công, thành công, đại thành công.',
    'Tri thức là sức mạnh khi gắn với hành động.',
    'Biết người là trí, biết mình là sáng.',
    'Muốn đi xa phải giữ được gốc.',
    'Một ngày không học là một ngày lùi lại.',
    'Hành trình lớn bắt đầu từ một bước nhỏ.',
    'Tư duy đúng mở đường cho hành động đúng.',
    'Sự thật là tiêu chuẩn kiểm nghiệm chân lý.',
    'Con người tạo nên hoàn cảnh và hoàn cảnh cũng tạo nên con người.',
    'Kỷ luật là sức mạnh của tổ chức.',
    'Gia đình là gốc của ký ức, đạo nghĩa là gốc của con người.',
    'Nhớ nguồn là cách giữ cho tương lai không lạc hướng.',
    'Tự thắng mình là chiến thắng khó nhất.',
  ];

  static List<String> get all => List.generate(1000, (i) {
        final b = base[i % base.length];
        return '$b';
      });

  static String forDate(DateTime d) {
    final index = (d.year * 372 + d.month * 31 + d.day) % all.length;
    return all[index];
  }
}

class GoogleSyncService {
  static const calendarScope = 'https://www.googleapis.com/auth/calendar';

  static Future<Map<String, dynamic>> startDeviceCode(String clientId) async {
    final res = await http.post(
      Uri.parse('https://oauth2.googleapis.com/device/code'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'client_id': clientId, 'scope': calendarScope},
    );
    if (res.statusCode >= 400) {
      throw Exception('Google device code error: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> pollToken(String clientId, String deviceCode) async {
    while (true) {
      await Future.delayed(const Duration(seconds: 5));
      final res = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': clientId,
          'device_code': deviceCode,
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        },
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) return body;
      final err = body['error']?.toString() ?? '';
      if (err == 'authorization_pending' || err == 'slow_down') continue;
      throw Exception('Google token error: ${res.body}');
    }
  }

  static Future<String> accessToken() async {
    final tokens = await Store.getGoogleTokens();
    var access = tokens['access_token']?.toString() ?? '';
    final refresh = tokens['refresh_token']?.toString() ?? '';
    final expiryMs = (tokens['expiry_ms'] as num?)?.toInt() ?? 0;
    if (access.isNotEmpty && DateTime.now().millisecondsSinceEpoch < expiryMs - 60000) return access;
    final clientId = await Store.getGoogleClientId();
    if (refresh.isEmpty || clientId.isEmpty) return access;
    final res = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'refresh_token': refresh,
        'grant_type': 'refresh_token',
      },
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      access = body['access_token'].toString();
      final expires = (body['expires_in'] as num?)?.toInt() ?? 3600;
      await Store.setGoogleTokens(access, refresh, DateTime.now().add(Duration(seconds: expires)).millisecondsSinceEpoch);
    }
    return access;
  }

  static Future<void> pushEvents(List<FamilyEvent> events) async {
    final token = await accessToken();
    if (token.isEmpty) throw Exception('Chưa đăng nhập Google.');
    final now = DateTime.now();
    for (final e in events) {
      final occs = occurrencesForEvent(e, now.year, now.year + 5).where((d) => d.isAfter(now.subtract(const Duration(days: 1))));
      for (final dt in occs.take(80)) {
        final start = dt.toUtc().toIso8601String();
        final end = dt.add(const Duration(hours: 1)).toUtc().toIso8601String();
        final body = {
          'summary': e.title,
          'description': 'Lịch âm gia tộc\nÂm: ${e.lunarDay}/${e.lunarMonth}${e.leap ? ' nhuận' : ''}\n${e.note}',
          'start': {'dateTime': start, 'timeZone': 'Asia/Ho_Chi_Minh'},
          'end': {'dateTime': end, 'timeZone': 'Asia/Ho_Chi_Minh'},
          'extendedProperties': {
            'private': {
              'lunar_family_calendar': 'true',
              'source_event_id': e.id,
              'lunar_day': '${e.lunarDay}',
              'lunar_month': '${e.lunarMonth}',
              'lunar_leap': '${e.leap}',
              'repeat': e.repeat.name,
            }
          },
          'reminders': {
            'useDefault': false,
            'overrides': [
              {'method': 'popup', 'minutes': e.remindBeforeDays * 1440 + e.remindBeforeHours * 60}
            ],
          },
        };
        final res = await http.post(
          Uri.parse('https://www.googleapis.com/calendar/v3/calendars/primary/events'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(body),
        );
        if (res.statusCode >= 400) throw Exception('Google Calendar error: ${res.body}');
      }
    }
  }

  static Future<List<FamilyEvent>> pullEvents() async {
    final token = await accessToken();
    if (token.isEmpty) throw Exception('Chưa đăng nhập Google.');
    final uri = Uri.https('www.googleapis.com', '/calendar/v3/calendars/primary/events', {
      'privateExtendedProperty': 'lunar_family_calendar=true',
      'singleEvents': 'true',
      'maxResults': '2500',
      'timeMin': DateTime(DateTime.now().year - 1).toUtc().toIso8601String(),
    });
    final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode >= 400) throw Exception('Google Calendar error: ${res.body}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (body['items'] as List?) ?? [];
    final seen = <String>{};
    final out = <FamilyEvent>[];
    for (final item in items) {
      final m = Map<String, dynamic>.from(item);
      final priv = Map<String, dynamic>.from(((m['extendedProperties'] as Map?)?['private'] as Map?) ?? {});
      final id = priv['source_event_id']?.toString() ?? '';
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      RepeatType rp = RepeatType.yearly;
      for (final r in RepeatType.values) {
        if (r.name == priv['repeat']) rp = r;
      }
      out.add(FamilyEvent(
        id: id,
        title: m['summary']?.toString() ?? 'Sự kiện Google',
        note: m['description']?.toString() ?? '',
        lunarDay: int.tryParse(priv['lunar_day']?.toString() ?? '') ?? 1,
        lunarMonth: int.tryParse(priv['lunar_month']?.toString() ?? '') ?? 1,
        leap: priv['lunar_leap']?.toString() == 'true',
        hour: 7,
        minute: 0,
        repeat: rp,
        remindBeforeDays: 0,
        remindBeforeHours: 0,
      ));
    }
    return out;
  }
}


extension FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class LunarFamilyApp extends StatelessWidget {
  const LunarFamilyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lịch âm gia tộc',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xffb3261e),
        scaffoldBackgroundColor: const Color(0xfffff7f5),
        fontFamily: 'Roboto',
      ),
      home: const LunarHomePage(),
    );
  }
}

class LunarHomePage extends StatefulWidget {
  const LunarHomePage({super.key});

  @override
  State<LunarHomePage> createState() => _LunarHomePageState();
}

class _LunarHomePageState extends State<LunarHomePage> with TrayListener, WindowListener {
  DateTime selected = DateTime.now();
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  CalendarViewMode mode = CalendarViewMode.month;
  List<FamilyEvent> events = [];
  String quote = QuoteBank.forDate(DateTime.now());
  bool hideToTray = true;
  bool startupEnabled = false;
  FamilyEvent? floatingReminder;

  @override
  void initState() {
    super.initState();
    unawaited(load());
    if (isWindowsDesktop) {
      unawaited(setupDesktop());
    }
  }

  Future<void> restoreWindowSafely() async {
    if (!isWindowsDesktop) return;
    try {
      final display = await screenRetriever.getPrimaryDisplay();
      final visibleSize = display.visibleSize ?? display.size;
      final visiblePosition = display.visiblePosition ?? Offset.zero;
      final currentSize = await windowManager.getSize();

      final w = min(currentSize.width, max(720.0, visibleSize.width - 40.0));
      final h = min(currentSize.height, max(520.0, visibleSize.height - 70.0));
      final dx = visiblePosition.dx + max(8.0, (visibleSize.width - w) / 2);
      final dy = visiblePosition.dy + max(8.0, (visibleSize.height - h) / 2);

      await windowManager.setFullScreen(false);
      await windowManager.unmaximize();
      await windowManager.setSize(Size(w, h));
      await windowManager.setPosition(Offset(dx, dy));
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  @override
  void dispose() {
    if (isWindowsDesktop) {
      trayManager.removeListener(this);
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> load() async {
    final loaded = await Store.loadEvents();
    final h = await Store.getHideToTray();
    final s = await Store.getStartup();
    if (!mounted) return;
    setState(() {
      events = loaded;
      hideToTray = h;
      startupEnabled = s;
      quote = QuoteBank.forDate(DateTime.now());
    });
    unawaited(LocalNotify.scheduleAll(loaded));
  }

  Future<void> setupDesktop() async {
    trayManager.addListener(this);
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
    try {
      final iconPath = await resolveWindowsTrayIconPath();
      await trayManager.setIcon(iconPath);
    } catch (_) {
      try {
        await trayManager.setIcon('assets/icons/app_icon.ico');
      } catch (_) {}
    }
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'show', label: 'Hiện cửa sổ'),
      MenuItem.separator(),
      MenuItem(key: 'exit', label: 'Thoát hoàn toàn'),
    ]));
  }

  @override
  Future<void> onWindowClose() async {
    if (hideToTray) {
      await windowManager.hide();
    } else {
      await windowManager.destroy();
    }
  }

  @override
  void onTrayIconMouseDown() {
    restoreWindowSafely();
  }

  @override
  void onTrayMenuItemClick(MenuItem item) {
    if (item.key == 'show') {
      restoreWindowSafely();
    } else if (item.key == 'exit') {
      windowManager.destroy();
    }
  }

  Future<void> setStartup(bool value) async {
    setState(() => startupEnabled = value);
    await Store.setStartup(value);
    if (!isWindowsDesktop) return;
    try {
      final info = await PackageInfo.fromPlatform();
      launchAtStartup.setup(appName: info.appName, appPath: Platform.resolvedExecutable);
      if (value) {
        await launchAtStartup.enable();
      } else {
        await launchAtStartup.disable();
      }
    } catch (_) {}
  }

  void movePrevious() {
    setState(() {
      if (mode == CalendarViewMode.week) {
        selected = selected.subtract(const Duration(days: 7));
        month = DateTime(selected.year, selected.month);
      } else if (mode == CalendarViewMode.year || mode == CalendarViewMode.stats) {
        month = DateTime(month.year - 1, month.month);
      } else if (mode == CalendarViewMode.fiveYear) {
        month = DateTime(month.year - 5, month.month);
      } else {
        month = DateTime(month.year, month.month - 1);
      }
    });
  }

  void moveNext() {
    setState(() {
      if (mode == CalendarViewMode.week) {
        selected = selected.add(const Duration(days: 7));
        month = DateTime(selected.year, selected.month);
      } else if (mode == CalendarViewMode.year || mode == CalendarViewMode.stats) {
        month = DateTime(month.year + 1, month.month);
      } else if (mode == CalendarViewMode.fiveYear) {
        month = DateTime(month.year + 5, month.month);
      } else {
        month = DateTime(month.year, month.month + 1);
      }
    });
  }

  String headerText() {
    if (mode == CalendarViewMode.week) {
      final start = selected.subtract(Duration(days: selected.weekday - 1));
      final end = start.add(const Duration(days: 6));
      return 'Tuần ${fmtDate(start)} - ${fmtDate(end)}';
    }
    if (mode == CalendarViewMode.year || mode == CalendarViewMode.stats) return 'Năm ${month.year}';
    if (mode == CalendarViewMode.fiveYear) return '${month.year} - ${month.year + 4}';
    if (mode == CalendarViewMode.events) return 'Danh sách sự kiện';
    if (mode == CalendarViewMode.google) return 'Google / Sao lưu';
    return 'Tháng ${month.month}/${month.year}';
  }

  List<FamilyEvent> eventsForDate(DateTime d) {
    final l = LunarCalc.solarToLunar(d);
    return events.where((e) {
      if (e.repeat == RepeatType.monthly) return e.lunarDay == l.day;
      if (e.repeat == RepeatType.quarterly) {
        return e.lunarDay == l.day && ((l.month - e.lunarMonth) % 3 == 0);
      }
      return e.lunarDay == l.day && e.lunarMonth == l.month && e.leap == l.leap;
    }).toList();
  }

  String holiday(DateTime d, LunarDate l) {
    final sk = '${d.day}/${d.month}';
    final lk = '${l.day}/${l.month}';
    const solar = {
      '1/1': 'Tết Dương lịch',
      '30/4': 'Giải phóng',
      '1/5': 'Lao động',
      '2/9': 'Quốc khánh',
    };
    const lunar = {
      '1/1': 'Tết Nguyên Đán',
      '15/1': 'Rằm tháng Giêng',
      '10/3': 'Giỗ Tổ Hùng Vương',
      '15/4': 'Phật Đản',
      '15/7': 'Vu Lan',
      '15/8': 'Trung Thu',
      '23/12': 'Ông Công Ông Táo',
    };
    final isToday = sameDay(d, DateTime.now());

    final lunarHoliday = lunar[lk];
    final solarHoliday = solar[sk];

    if (isToday) {
      final extra = lunarHoliday ?? solarHoliday;
      return extra == null ? 'Hôm nay' : 'Hôm nay • $extra';
    }

    if (lunarHoliday != null) return lunarHoliday;
    if (solarHoliday != null) return solarHoliday;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 760;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Lịch âm gia tộc',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          PopupMenuButton<CalendarViewMode>(
            tooltip: 'Chế độ xem',
            initialValue: mode,
            onSelected: (value) => setState(() => mode = value),
            itemBuilder: (_) => CalendarViewMode.values
                .map((m) => PopupMenuItem(value: m, child: Text(modeLabel(m))))
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: compact ? const Icon(Icons.view_agenda) : Row(children: [const Icon(Icons.view_agenda), const SizedBox(width: 6), Text(modeLabel(mode))]),
            ),
          ),
          IconButton(onPressed: openEventDialog, icon: const Icon(Icons.add_alert), tooltip: 'Thêm sự kiện âm lịch'),
          IconButton(onPressed: () => setState(() => mode = CalendarViewMode.google), icon: const Icon(Icons.cloud_sync), tooltip: 'Google / Sao lưu'),
          IconButton(
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                selected = now;
                month = DateTime(now.year, now.month);
                mode = CalendarViewMode.month;
                quote = QuoteBank.forDate(now);
              });
            },
            icon: const Icon(Icons.today),
            tooltip: 'Hôm nay',
          ),
        ],
      ),
      body: Stack(
        children: [
          compact ? buildMobileBody() : buildDesktopBody(),
          if (floatingReminder != null) buildFloatingReminder(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openEventDialog,
        icon: const Icon(Icons.add),
        label: const Text('Sự kiện âm'),
      ),
    );
  }

  Widget buildDesktopBody() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: buildDesktopMainWorkspace(),
    );
  }

  Widget buildDesktopMainWorkspace() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: buildDesktopCalendarArea()),
        const SizedBox(width: 8),
        SizedBox(width: 360, child: buildDesktopSidePanel()),
      ],
    );
  }

  Widget buildDesktopCalendarArea() {
    return LayoutBuilder(
      builder: (context, box) {
        return Column(
          children: [
            buildTopBar(),
            const SizedBox(height: 8),
            Expanded(
              child: switch (mode) {
                CalendarViewMode.week => buildWeekView(fill: true),
                CalendarViewMode.month => buildMonthView(month, fill: true),
                CalendarViewMode.year => buildDesktopScrollable(buildYearView()),
                CalendarViewMode.fiveYear => buildDesktopScrollable(buildFiveYearView()),
                CalendarViewMode.events => buildDesktopScrollable(buildEventsView()),
                CalendarViewMode.stats => buildDesktopScrollable(buildStatsView()),
                CalendarViewMode.google => buildDesktopScrollable(buildGoogleView()),
              },
            ),
          ],
        );
      },
    );
  }

  Widget buildDesktopScrollable(Widget child) {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: child,
      ),
    );
  }

  Widget buildDesktopSidePanel() {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        child: buildSidePanel(),
      ),
    );
  }

  Widget buildMobileBody() {
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        buildMainContent(),
        const SizedBox(height: 10),
        buildSidePanel(),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget buildMainContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildTopBar(),
        const SizedBox(height: 10),
        if (mode == CalendarViewMode.week) buildWeekView(),
        if (mode == CalendarViewMode.month) buildMonthView(month),
        if (mode == CalendarViewMode.year) buildYearView(),
        if (mode == CalendarViewMode.fiveYear) buildFiveYearView(),
        if (mode == CalendarViewMode.events) buildEventsView(),
        if (mode == CalendarViewMode.stats) buildStatsView(),
        if (mode == CalendarViewMode.google) buildGoogleView(),
      ],
    );
  }

  Widget buildTopBar() {
    return Card(
      elevation: 0,
      color: const Color(0xffffeeeb),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            IconButton(onPressed: movePrevious, icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: Text(
                headerText(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
            IconButton(onPressed: moveNext, icon: const Icon(Icons.chevron_right)),
          ],
        ),
      ),
    );
  }

  Widget buildWeekHeader() {
    const names = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return Row(
      children: List.generate(7, (i) {
        final weekend = i >= 5;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: weekend ? const Color(0xffffe0dc) : const Color(0xfffff4f2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(names[i], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
      }),
    );
  }

  Widget buildMonthView(DateTime m, {bool mini = false, bool fill = false}) {
    final first = DateTime(m.year, m.month, 1);
    final start = first.subtract(Duration(days: first.weekday - 1));
    final days = List.generate(42, (i) => start.add(Duration(days: i)));

    if (fill) {
      return LayoutBuilder(
        builder: (context, c) {
          final headerHeight = c.maxHeight < 430 ? 24.0 : 34.0;
          return Column(
            children: [
              SizedBox(height: headerHeight, child: buildWeekHeader()),
              const SizedBox(height: 4),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, grid) {
                    final cellW = grid.maxWidth / 7;
                    final cellH = max(1.0, grid.maxHeight / 6);
                    final ratio = cellW / cellH;
                    return GridView.builder(
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: days.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: ratio,
                      ),
                      itemBuilder: (_, i) {
                        final d = days[i];
                        return buildDayCell(d, inMonth: d.month == m.month, mini: mini);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    }

    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final phone = w < 560;
      final narrowPhone = w < 390;
      final ratio = phone ? (narrowPhone ? 0.46 : 0.52) : (mini ? 0.92 : 0.82);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildWeekHeader(),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: ratio,
            ),
            itemBuilder: (_, i) {
              final d = days[i];
              return buildDayCell(d, inMonth: d.month == m.month, mini: mini);
            },
          ),
        ],
      );
    });
  }

  Widget buildWeekView({bool fill = false}) {
    final start = selected.subtract(Duration(days: selected.weekday - 1));
    final days = List.generate(7, (i) => start.add(Duration(days: i)));

    if (fill) {
      return LayoutBuilder(
        builder: (context, c) {
          final headerHeight = c.maxHeight < 360 ? 24.0 : 34.0;
          return Column(
            children: [
              SizedBox(height: headerHeight, child: buildWeekHeader()),
              const SizedBox(height: 4),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, grid) {
                    final cellW = grid.maxWidth / 7;
                    final cellH = max(1.0, grid.maxHeight);
                    final ratio = cellW / cellH;
                    return GridView.builder(
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 7,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: ratio,
                      ),
                      itemBuilder: (_, i) => buildDayCell(days[i], inMonth: true),
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    }

    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxWidth < 620;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildWeekHeader(),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 7,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: compact ? 2 : 7,
              childAspectRatio: compact ? 1.05 : 0.72,
            ),
            itemBuilder: (_, i) => buildDayCell(days[i], inMonth: true),
          ),
        ],
      );
    });
  }

  Widget buildDayCell(DateTime d, {required bool inMonth, bool mini = false}) {
    final l = LunarCalc.solarToLunar(d);
    final es = eventsForDate(d);
    final h = holiday(d, l);
    final weekend = d.weekday >= 6;
    final today = sameDay(d, DateTime.now());
    final selectedDay = sameDay(d, selected);

    return LayoutBuilder(
      builder: (context, box) {
        final cw = box.maxWidth;
        final ch = box.maxHeight;
        final phoneCell = cw < 64 || ch < 96;
        final tiny = cw < 48;
        final lunarFont = mini ? 12.0 : (cw * 0.38).clamp(13.0, phoneCell ? 17.0 : 22.0);
        final solarFont = mini ? 11.0 : (cw * 0.28).clamp(9.0, phoneCell ? 13.0 : 18.0);
        final amFont = mini ? 8.0 : (cw * 0.18).clamp(8.0, 11.0);
        final innerPad = tiny ? 3.0 : (phoneCell ? 4.0 : 7.0);

        return InkWell(
          onTap: () => setState(() {
            selected = d;
            month = DateTime(d.year, d.month);
          }),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: EdgeInsets.all(tiny ? 1.5 : 3),
            padding: EdgeInsets.all(innerPad),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: selectedDay
                  ? const Color(0xffffd6d0)
                  : weekend
                      ? const Color(0xfffff0ed)
                      : Colors.white,
              border: Border.all(
                color: selectedDay
                    ? const Color(0xffb3261e)
                    : today
                        ? Colors.orange
                        : const Color(0x22b3261e),
                width: selectedDay || today ? 1.6 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 3)],
            ),
            child: Opacity(
              opacity: inMonth ? 1 : 0.36,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    width: cw * 0.58,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${l.day}',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: lunarFont,
                              height: 0.95,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xffb3261e),
                            ),
                          ),
                        ),
                        Text(
                          'âm',
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            fontSize: amFont,
                            height: 1.0,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xffb3261e),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 1,
                    width: cw * 0.42,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${d.day}',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: solarFont,
                          height: 1.0,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  if (!mini && !phoneCell && h.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: max(33.0, ch * 0.36),
                      child: Text(
                        h,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (!mini && !phoneCell && es.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Text(
                        es.map((e) => e.title).take(2).join(', '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1.05,
                          color: Color(0xff7a1b17),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if ((phoneCell || mini) && es.isNotEmpty)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xffb3261e),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${es.length}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  if (phoneCell && h.isNotEmpty && es.isEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Text(
                        h,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: tiny ? 7 : 8,
                          height: 1,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  Widget buildYearView() {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth < 760 ? 1 : 3;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 12,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, childAspectRatio: cols == 1 ? 0.72 : 0.86),
        itemBuilder: (_, i) {
          final m = DateTime(month.year, i + 1);
          return Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(children: [
                Text('Tháng ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w900)),
                Expanded(child: SingleChildScrollView(child: buildMonthView(m, mini: true))),
              ]),
            ),
          );
        },
      );
    });
  }

  Widget buildFiveYearView() {
    return Column(
      children: List.generate(5, (i) {
        final y = month.year + i;
        final count = statsForYear(y).values.fold<int>(0, (a, b) => a + b);
        return Card(
          child: ListTile(
            title: Text('Năm $y', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('$count lượt sự kiện phát sinh'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() {
              month = DateTime(y, 1);
              mode = CalendarViewMode.year;
            }),
          ),
        );
      }),
    );
  }

  Widget buildSidePanel() {
    final l = LunarCalc.solarToLunar(selected);
    final es = eventsForDate(selected);
    return Container(
      color: const Color(0xffffeeeb),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ngày âm', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          Text(l.text, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 34, color: Color(0xffb3261e))),
          Text('Dương lịch: ${fmtDate(selected)}', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text('Lời hay hôm nay', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.grey.shade800)),
          const SizedBox(height: 6),
          Text(quote, style: const TextStyle(fontStyle: FontStyle.italic)),
          const Divider(height: 28),
          Row(
            children: [
              const Expanded(child: Text('Sự kiện ngày này', style: TextStyle(fontWeight: FontWeight.w900))),
              IconButton(onPressed: openEventDialog, icon: const Icon(Icons.add_circle)),
            ],
          ),
          if (es.isEmpty)
            const Text('Không có sự kiện.')
          else
            ...es.map((e) => Card(
                  child: ListTile(
                    title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('Âm ${e.lunarDay}/${e.lunarMonth} • ${repeatLabel(e.repeat)}'),
                    trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => openEventDialog(editing: e)),
                  ),
                )),
          if (isWindowsDesktop) ...[
            const Divider(height: 28),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ẩn xuống system tray khi thoát'),
              value: hideToTray,
              onChanged: (v) async {
                setState(() => hideToTray = v);
                await Store.setHideToTray(v);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Khởi động cùng Windows'),
              value: startupEnabled,
              onChanged: setStartup,
            ),
            FilledButton.icon(
              onPressed: () {
                LocalNotify.showNow('Thử thông báo', 'Đây là thông báo nổi của Lịch âm gia tộc.');
                setState(() => floatingReminder = FamilyEvent(
                      id: 'test',
                      title: 'Thử thông báo',
                      note: '',
                      lunarDay: l.day,
                      lunarMonth: l.month,
                      leap: l.leap,
                      hour: 7,
                      minute: 0,
                      repeat: RepeatType.yearly,
                      remindBeforeDays: 0,
                      remindBeforeHours: 0,
                    ));
              },
              icon: const Icon(Icons.notifications_active),
              label: const Text('Thử thông báo nổi'),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildEventsView() {
    final sorted = [...events]..sort((a, b) => a.lunarMonth == b.lunarMonth ? a.lunarDay.compareTo(b.lunarDay) : a.lunarMonth.compareTo(b.lunarMonth));
    if (sorted.isEmpty) return const Padding(padding: EdgeInsets.all(24), child: Text('Chưa có sự kiện.'));
    return Column(
      children: sorted.map((e) {
        final next = occurrencesForEvent(e, DateTime.now().year, DateTime.now().year + 2).where((d) => d.isAfter(DateTime.now())).firstOrNull;
        return Card(
          child: ListTile(
            leading: const Icon(Icons.event_available, color: Color(0xffb3261e)),
            title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text('Âm ${e.lunarDay}/${e.lunarMonth}${e.leap ? ' nhuận' : ''} • ${repeatLabel(e.repeat)}\nNhắc trước ${e.remindBeforeDays} ngày ${e.remindBeforeHours} giờ${next == null ? '' : '\nLần tới: ${fmtDateTime(next)}'}'),
            isThreeLine: true,
            trailing: Wrap(
              spacing: 2,
              children: [
                IconButton(icon: const Icon(Icons.edit), onPressed: () => openEventDialog(editing: e)),
                IconButton(icon: const Icon(Icons.delete_forever), onPressed: () => deleteEvent(e)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Map<String, int> statsForYear(int year) {
    final map = <String, int>{};
    for (final e in events) {
      final occs = occurrencesForEvent(e, year, year);
      for (final d in occs) {
        final k = 'Tháng ${d.month}';
        map[k] = (map[k] ?? 0) + 1;
      }
    }
    return map;
  }

  Widget buildStatsView() {
    final map = statsForYear(month.year);
    if (map.isEmpty) return const Padding(padding: EdgeInsets.all(24), child: Text('Năm này chưa có sự kiện.'));
    return Column(
      children: map.entries.map((e) => Card(child: ListTile(title: Text(e.key), trailing: Text('${e.value} lượt', style: const TextStyle(fontWeight: FontWeight.w900))))).toList(),
    );
  }

  Widget buildGoogleView() {
    final exportJson = const JsonEncoder.withIndent('  ').convert(events.map((e) => e.toJson()).toList());
    final jsonController = TextEditingController(text: exportJson);
    final clientController = TextEditingController();

    return FutureBuilder<String>(
      future: Store.getGoogleClientId(),
      builder: (context, snapshot) {
        clientController.text = snapshot.data ?? '';
        return Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Google Calendar Sync', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                TextField(
                  controller: clientController,
                  decoration: const InputDecoration(
                    labelText: 'Google OAuth Client ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => googleLogin(clientController.text),
                      icon: const Icon(Icons.login),
                      label: const Text('Đăng nhập Google'),
                    ),
                    FilledButton.icon(
                      onPressed: () => googlePush(),
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Đẩy lên Google Calendar'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => googlePull(),
                      icon: const Icon(Icons.cloud_download),
                      label: const Text('Tải từ Google Calendar'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await Store.clearGoogleTokens();
                        if (mounted) showMsg('Đã xóa token Google.');
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Đăng xuất'),
                    ),
                  ],
                ),
                const Divider(height: 28),
                const Text('Sao lưu JSON', style: TextStyle(fontWeight: FontWeight.w900)),
                TextField(
                  controller: jsonController,
                  maxLines: 8,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: jsonController.text));
                        if (mounted) showMsg('Đã copy JSON sao lưu.');
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy sao lưu'),
                    ),
                    FilledButton.icon(
                      onPressed: () async {
                        try {
                          final list = (jsonDecode(jsonController.text) as List).map((e) => FamilyEvent.fromJson(Map<String, dynamic>.from(e))).toList();
                          setState(() => events = list);
                          await Store.saveEvents(events);
                          unawaited(LocalNotify.scheduleAll(events));
                          if (mounted) showMsg('Đã khôi phục ${list.length} sự kiện.');
                        } catch (e) {
                          showMsg('JSON không hợp lệ: $e');
                        }
                      },
                      icon: const Icon(Icons.restore),
                      label: const Text('Khôi phục JSON'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> googleLogin(String clientId) async {
    try {
      if (clientId.trim().isEmpty) {
        showMsg('Hãy nhập Google OAuth Client ID.');
        return;
      }
      await Store.setGoogleClientId(clientId);
      final device = await GoogleSyncService.startDeviceCode(clientId.trim());
      final url = Uri.parse(device['verification_url']?.toString() ?? device['verification_url_complete']?.toString() ?? '');
      final code = device['user_code']?.toString() ?? '';
      if (url.toString().isNotEmpty) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      showMsg('Mã đăng nhập: $code. Hãy xác nhận trên trình duyệt, app sẽ tự chờ.');
      final token = await GoogleSyncService.pollToken(clientId.trim(), device['device_code'].toString());
      final access = token['access_token'].toString();
      final refresh = token['refresh_token']?.toString() ?? '';
      final expires = (token['expires_in'] as num?)?.toInt() ?? 3600;
      await Store.setGoogleTokens(access, refresh, DateTime.now().add(Duration(seconds: expires)).millisecondsSinceEpoch);
      showMsg('Đăng nhập Google thành công.');
    } catch (e) {
      showMsg('Lỗi Google Login: $e');
    }
  }

  Future<void> googlePush() async {
    try {
      showMsg('Đang đẩy sự kiện lên Google Calendar...');
      await GoogleSyncService.pushEvents(events);
      showMsg('Đã đẩy sự kiện lên Google Calendar.');
    } catch (e) {
      showMsg('Lỗi đồng bộ Google: $e');
    }
  }

  Future<void> googlePull() async {
    try {
      final pulled = await GoogleSyncService.pullEvents();
      final map = {for (final e in events) e.id: e};
      for (final e in pulled) {
        map[e.id] = e;
      }
      setState(() => events = map.values.toList());
      await Store.saveEvents(events);
      unawaited(LocalNotify.scheduleAll(events));
      showMsg('Đã tải ${pulled.length} sự kiện từ Google Calendar.');
    } catch (e) {
      showMsg('Lỗi tải Google: $e');
    }
  }

  Future<void> openEventDialog({FamilyEvent? editing}) async {
    final l = LunarCalc.solarToLunar(selected);
    final title = TextEditingController(text: editing?.title ?? '');
    final note = TextEditingController(text: editing?.note ?? '');
    var lunarDay = editing?.lunarDay ?? l.day;
    var lunarMonth = editing?.lunarMonth ?? l.month;
    var leap = editing?.leap ?? l.leap;
    var hour = editing?.hour ?? 7;
    var minute = editing?.minute ?? 0;
    var repeat = editing?.repeat ?? RepeatType.yearly;
    var beforeDays = editing?.remindBeforeDays ?? 0;
    var beforeHours = editing?.remindBeforeHours ?? 0;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(editing == null ? 'Thêm sự kiện theo lịch âm' : 'Sửa sự kiện'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'Tên sự kiện')),
                  TextField(controller: note, decoration: const InputDecoration(labelText: 'Ghi chú')),
                  Row(
                    children: [
                      Expanded(child: numberField('Ngày âm', lunarDay, (v) => lunarDay = v, min: 1, max: 30)),
                      const SizedBox(width: 8),
                      Expanded(child: numberField('Tháng âm', lunarMonth, (v) => lunarMonth = v, min: 1, max: 12)),
                    ],
                  ),
                  CheckboxListTile(
                    value: leap,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setLocal(() => leap = v ?? false),
                    title: const Text('Tháng nhuận'),
                  ),
                  DropdownButtonFormField<RepeatType>(
                    value: repeat,
                    decoration: const InputDecoration(labelText: 'Chu kỳ nhắc'),
                    items: RepeatType.values.map((r) => DropdownMenuItem(value: r, child: Text(repeatLabel(r)))).toList(),
                    onChanged: (v) => setLocal(() => repeat = v ?? repeat),
                  ),
                  Row(
                    children: [
                      Expanded(child: numberField('Giờ', hour, (v) => hour = v, min: 0, max: 23)),
                      const SizedBox(width: 8),
                      Expanded(child: numberField('Phút', minute, (v) => minute = v, min: 0, max: 59)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: numberField('Nhắc trước ngày', beforeDays, (v) => beforeDays = v, min: 0, max: 365)),
                      const SizedBox(width: 8),
                      Expanded(child: numberField('Nhắc trước giờ', beforeHours, (v) => beforeHours = v, min: 0, max: 23)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (editing != null)
              TextButton.icon(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await deleteEvent(editing);
                },
                icon: const Icon(Icons.delete_forever),
                label: const Text('Xóa'),
              ),
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Hủy')),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().isEmpty) {
                  showMsg('Hãy nhập tên sự kiện.');
                  return;
                }
                final event = FamilyEvent(
                  id: editing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                  title: title.text.trim(),
                  note: note.text.trim(),
                  lunarDay: lunarDay,
                  lunarMonth: lunarMonth,
                  leap: leap,
                  hour: hour,
                  minute: minute,
                  repeat: repeat,
                  remindBeforeDays: beforeDays,
                  remindBeforeHours: beforeHours,
                );
                final next = [...events];
                final idx = next.indexWhere((e) => e.id == event.id);
                if (idx >= 0) {
                  next[idx] = event;
                } else {
                  next.add(event);
                }
                setState(() => events = next);
                await Store.saveEvents(events);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                unawaited(LocalNotify.scheduleAll(events));
                showMsg(editing == null ? 'Đã lưu và lập lịch nhắc.' : 'Đã cập nhật sự kiện.');
              },
              child: Text(editing == null ? 'Lưu + lập lịch nhắc' : 'Cập nhật'),
            ),
          ],
        ),
      ),
    );
  }

  Widget numberField(String label, int value, void Function(int) onChanged, {required int min, required int max}) {
    return TextFormField(
      initialValue: '$value',
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      onChanged: (v) {
        var n = int.tryParse(v) ?? value;
        n = n.clamp(min, max);
        onChanged(n);
      },
    );
  }

  Future<void> deleteEvent(FamilyEvent event) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa sự kiện?'),
        content: Text('Xóa "${event.title}" khỏi danh sách sự kiện đã lưu?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.delete), label: const Text('Xóa')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() { events.removeWhere((e) => e.id == event.id); });
    await Store.saveEvents(events);
    unawaited(LocalNotify.scheduleAll(events));
    showMsg('Đã xóa sự kiện.');
  }

  Widget buildFloatingReminder() {
    final e = floatingReminder!;
    return Positioned(
      right: 18,
      bottom: 18,
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xfffff5f2),
        child: SizedBox(
          width: 340,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  const Icon(Icons.notifications_active, color: Color(0xffb3261e)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w900))),
                  IconButton(onPressed: () => setState(() => floatingReminder = null), icon: const Icon(Icons.close)),
                ]),
                Text('Âm ${e.lunarDay}/${e.lunarMonth}${e.leap ? ' nhuận' : ''}'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(onPressed: () => setState(() => floatingReminder = null), child: const Text('Tắt')),
                    FilledButton(
                      onPressed: () {
                        LocalNotify.scheduleOnce('snooze10_${DateTime.now().millisecondsSinceEpoch}', e.title, 'Nhắc lại sau 10 phút', DateTime.now().add(const Duration(minutes: 10)));
                        setState(() => floatingReminder = null);
                      },
                      child: const Text('Nhắc lại 10 phút'),
                    ),
                    FilledButton(
                      onPressed: () {
                        LocalNotify.scheduleOnce('snooze60_${DateTime.now().millisecondsSinceEpoch}', e.title, 'Nhắc lại sau 1 giờ', DateTime.now().add(const Duration(hours: 1)));
                        setState(() => floatingReminder = null);
                      },
                      child: const Text('1 giờ'),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
