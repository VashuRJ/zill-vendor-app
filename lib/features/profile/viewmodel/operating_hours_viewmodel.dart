import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────
//  Model — one row in the schedule table
// ─────────────────────────────────────────────────────────────────────
class DaySchedule {
  final String day;
  final String shortDay;

  /// Lowercase key sent to / received from the backend ("monday" etc.)
  final String dayKey;

  /// Backend record id — populated after first fetch; null until saved once.
  int? serverId;

  bool isOpen;
  TimeOfDay openTime;
  TimeOfDay closeTime;

  DaySchedule({
    required this.day,
    required this.shortDay,
    required this.dayKey,
    this.serverId,
    this.isOpen = true,
    this.openTime = const TimeOfDay(hour: 9, minute: 0),
    this.closeTime = const TimeOfDay(hour: 22, minute: 0),
  });

  /// Returns "09:00 AM" style display string.
  String formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  String get formattedOpen => formatTime(openTime);
  String get formattedClose => formatTime(closeTime);
}

// ─────────────────────────────────────────────────────────────────────
//  Status enum
// ─────────────────────────────────────────────────────────────────────
enum HoursStatus {
  fetching, // initial data load in progress
  idle, // ready for editing
  saving, // POST in flight
  saved, // POST succeeded (resets to idle after 2 s)
  error, // any failure (see isFetchError for blocking vs. snackbar)
}

// ─────────────────────────────────────────────────────────────────────
//  ViewModel
// ─────────────────────────────────────────────────────────────────────
class OperatingHoursViewModel extends ChangeNotifier {
  final ApiService _apiService;

  HoursStatus _status = HoursStatus.fetching;
  String? _errorMessage;

  /// True → fetch failed; show full-screen error + retry.
  /// False → save failed; show snackbar, keep editing UI in place.
  bool _isFetchError = false;

  // Static schedule slots — order is always Mon → Sun.
  final List<DaySchedule> _schedule = [
    DaySchedule(
      day: 'Monday',
      shortDay: 'MON',
      dayKey: 'monday',
      openTime: const TimeOfDay(hour: 9, minute: 0),
      closeTime: const TimeOfDay(hour: 22, minute: 0),
    ),
    DaySchedule(
      day: 'Tuesday',
      shortDay: 'TUE',
      dayKey: 'tuesday',
      openTime: const TimeOfDay(hour: 9, minute: 0),
      closeTime: const TimeOfDay(hour: 22, minute: 0),
    ),
    DaySchedule(
      day: 'Wednesday',
      shortDay: 'WED',
      dayKey: 'wednesday',
      openTime: const TimeOfDay(hour: 9, minute: 0),
      closeTime: const TimeOfDay(hour: 22, minute: 0),
    ),
    DaySchedule(
      day: 'Thursday',
      shortDay: 'THU',
      dayKey: 'thursday',
      openTime: const TimeOfDay(hour: 9, minute: 0),
      closeTime: const TimeOfDay(hour: 22, minute: 0),
    ),
    DaySchedule(
      day: 'Friday',
      shortDay: 'FRI',
      dayKey: 'friday',
      openTime: const TimeOfDay(hour: 9, minute: 0),
      closeTime: const TimeOfDay(hour: 22, minute: 0),
    ),
    DaySchedule(
      day: 'Saturday',
      shortDay: 'SAT',
      dayKey: 'saturday',
      openTime: const TimeOfDay(hour: 10, minute: 0),
      closeTime: const TimeOfDay(hour: 23, minute: 0),
    ),
    DaySchedule(
      day: 'Sunday',
      shortDay: 'SUN',
      dayKey: 'sunday',
      openTime: const TimeOfDay(hour: 10, minute: 0),
      closeTime: const TimeOfDay(hour: 23, minute: 0),
    ),
  ];

  OperatingHoursViewModel({required ApiService apiService})
    : _apiService = apiService;

  // ── Getters ────────────────────────────────────────────────────────
  HoursStatus get status => _status;
  String? get errorMessage => _errorMessage;
  List<DaySchedule> get schedule => _schedule;
  bool get isSaving => _status == HoursStatus.saving;
  bool get isFetchError => _isFetchError;

  // ── Local mutations (no network) ───────────────────────────────────
  void toggleDay(int index, bool value) {
    _schedule[index].isOpen = value;
    _clearTransientState();
    notifyListeners();
  }

  void updateOpenTime(int index, TimeOfDay time) {
    _schedule[index].openTime = time;
    _clearTransientState();
    notifyListeners();
  }

  void updateCloseTime(int index, TimeOfDay time) {
    _schedule[index].closeTime = time;
    _clearTransientState();
    notifyListeners();
  }

  /// Copies the open/close times of [fromIndex] to every other slot.
  void copyTimesToAll(int fromIndex) {
    final src = _schedule[fromIndex];
    for (var i = 0; i < _schedule.length; i++) {
      if (i == fromIndex) continue;
      _schedule[i].openTime = src.openTime;
      _schedule[i].closeTime = src.closeTime;
    }
    _clearTransientState();
    notifyListeners();
  }

  // ── Fetch — GET /api/vendors/operating-hours/ ──────────────────────
  Future<void> fetchOperatingHours() async {
    _status = HoursStatus.fetching;
    _isFetchError = false;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.get(ApiEndpoints.operatingHours);
      final body = response.data as Map<String, dynamic>;

      // Build lookup: lowercase day_of_week → record map
      final hoursData = body['operating_hours'] as List<dynamic>? ?? [];
      final Map<String, Map<String, dynamic>> lookup = {
        for (final h in hoursData)
          (h as Map<String, dynamic>)['day_of_week'].toString().toLowerCase():
              h,
      };

      // Populate static slots; days absent from the server keep defaults
      for (final day in _schedule) {
        final data = lookup[day.dayKey];
        if (data != null) {
          day.serverId = data['id'] as int?;
          day.isOpen = !(data['is_closed'] as bool? ?? false);
          day.openTime = _parseHhmm(data['opening_time'] as String? ?? '09:00');
          day.closeTime = _parseHhmm(
            data['closing_time'] as String? ?? '22:00',
          );
        }
      }

      _status = HoursStatus.idle;
      _isFetchError = false;
    } on DioException catch (e) {
      _errorMessage = _parseDioError(e);
      _status = HoursStatus.error;
      _isFetchError = true;
    } catch (_) {
      _errorMessage = 'Unexpected error loading schedule.';
      _status = HoursStatus.error;
      _isFetchError = true;
    }
    notifyListeners();
  }

  // ── Save — POST /api/vendors/operating-hours/bulk/ ─────────────────
  Future<void> saveSchedule() async {
    _status = HoursStatus.saving;
    _isFetchError = false;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.post(
        ApiEndpoints.operatingHoursBulk,
        data: {'hours': _buildPayload()},
      );

      _status = HoursStatus.saved;
      notifyListeners();

      // Auto-reset so the button returns to its normal state
      await Future.delayed(const Duration(seconds: 2));
      if (_status == HoursStatus.saved) {
        _status = HoursStatus.idle;
        notifyListeners();
      }
    } on DioException catch (e) {
      _errorMessage = _parseDioError(e);
      _status = HoursStatus.error;
      _isFetchError = false; // snackbar, not full-screen
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Unexpected error saving schedule.';
      _status = HoursStatus.error;
      _isFetchError = false;
      notifyListeners();
    }
  }

  // ── Private helpers ────────────────────────────────────────────────

  List<Map<String, dynamic>> _buildPayload() => _schedule
      .map(
        (d) => {
          'day_of_week': d.dayKey,
          'opening_time': _toHhmm(d.openTime),
          'closing_time': _toHhmm(d.closeTime),
          'is_closed': !d.isOpen,
        },
      )
      .toList();

  /// Parse "HH:MM" 24-hour → TimeOfDay.
  TimeOfDay _parseHhmm(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return const TimeOfDay(hour: 9, minute: 0);
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  /// Format TimeOfDay → "HH:MM" 24-hour (what the backend expects).
  String _toHhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _parseDioError(DioException e) {
    if (e.response == null) {
      return 'Network error. Please check your connection.';
    }
    final data = e.response!.data;
    if (data is Map<String, dynamic>) {
      if (data.containsKey('error')) return data['error'].toString();
      if (data.containsKey('message')) return data['message'].toString();
      if (data.containsKey('detail')) return data['detail'].toString();
    }
    return 'Server error (${e.response!.statusCode}). Please try again.';
  }

  void _clearTransientState() {
    if (_status == HoursStatus.saved || _status == HoursStatus.error) {
      _status = HoursStatus.idle;
      _isFetchError = false;
    }
  }
}
