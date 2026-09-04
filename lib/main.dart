import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  runApp(const MedicineApp());
}

const _storageChannel = MethodChannel('ilac/storage');
const _unsetValue = Object();
const _medicineBarcodeAssetPath = 'assets/medicine_barcodes.json';
const _capsuleMarkerAssetPath = 'assets/capsule_marker.png';
const _daysPerWeek = 7;

class MedicineApp extends StatelessWidget {
  const MedicineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'İlaç Takibi',
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [
        Locale('tr', 'TR'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF217A70),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7FAF8),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: Color(0xFFE1EAE5)),
          ),
        ),
      ),
      home: const MedicineHomePage(),
    );
  }
}

enum RoutineType {
  daily,
  everyOtherDay,
  weekly,
}

extension RoutineTypeText on RoutineType {
  String get label {
    switch (this) {
      case RoutineType.daily:
        return 'Günde bir';
      case RoutineType.everyOtherDay:
        return 'İki günde bir';
      case RoutineType.weekly:
        return 'Haftanın belli günleri';
    }
  }
}

class MedicineRoutine {
  const MedicineRoutine({
    required this.id,
    required this.name,
    required this.dose,
    required this.boxQuantity,
    required this.time,
    required this.routineType,
    required this.startDate,
    required this.weekdays,
    required this.isActive,
    this.note = '',
  });

  final String id;
  final String name;
  final String dose;
  final String boxQuantity;
  final TimeOfDay? time;
  final RoutineType routineType;
  final DateTime startDate;
  final Set<int> weekdays;
  final bool isActive;
  final String note;

  bool isDueOn(DateTime date) {
    if (!isActive) {
      return false;
    }

    final currentDate = _dateOnly(date);
    final firstDate = _dateOnly(startDate);
    if (currentDate.isBefore(firstDate)) {
      return false;
    }

    final bool isPatternDue;
    switch (routineType) {
      case RoutineType.daily:
        isPatternDue = true;
        break;
      case RoutineType.everyOtherDay:
        isPatternDue = currentDate.difference(firstDate).inDays.isEven;
        break;
      case RoutineType.weekly:
        isPatternDue = weekdays.contains(currentDate.weekday);
        break;
    }

    if (!isPatternDue) {
      return false;
    }

    final maxDoseCount = _maxDoseCount();
    if (maxDoseCount == null) {
      return true;
    }

    final doseNumber = _doseNumberOn(currentDate, firstDate);
    return doseNumber != null && doseNumber <= maxDoseCount;
  }

  int? _maxDoseCount() {
    final boxQuantityValue = _parseDose(boxQuantity);
    final doseValue = _parseDose(dose);
    if (boxQuantityValue == null ||
        boxQuantityValue <= 0 ||
        doseValue == null ||
        doseValue <= 0) {
      return null;
    }

    return boxQuantityValue ~/ doseValue;
  }

  int? _doseNumberOn(DateTime currentDate, DateTime firstDate) {
    switch (routineType) {
      case RoutineType.daily:
        return currentDate.difference(firstDate).inDays + 1;
      case RoutineType.everyOtherDay:
        final daysBetween = currentDate.difference(firstDate).inDays;
        if (!daysBetween.isEven) {
          return null;
        }

        return daysBetween ~/ 2 + 1;
      case RoutineType.weekly:
        return _weeklyDoseNumberOn(currentDate, firstDate);
    }
  }

  int _weeklyDoseNumberOn(DateTime currentDate, DateTime firstDate) {
    var doseCount = 0;
    var cursor = firstDate;
    while (!cursor.isAfter(currentDate)) {
      if (weekdays.contains(cursor.weekday)) {
        doseCount += 1;
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    return doseCount;
  }

  MedicineRoutine copyWith({
    String? name,
    String? dose,
    String? boxQuantity,
    Object? time = _unsetValue,
    RoutineType? routineType,
    DateTime? startDate,
    Set<int>? weekdays,
    bool? isActive,
    String? note,
  }) {
    return MedicineRoutine(
      id: id,
      name: name ?? this.name,
      dose: dose ?? this.dose,
      boxQuantity: boxQuantity ?? this.boxQuantity,
      time: time == _unsetValue ? this.time : time as TimeOfDay?,
      routineType: routineType ?? this.routineType,
      startDate: startDate ?? this.startDate,
      weekdays: weekdays ?? this.weekdays,
      isActive: isActive ?? this.isActive,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'dose': dose,
      'boxQuantity': boxQuantity,
      'timeHour': time?.hour,
      'timeMinute': time?.minute,
      'routineType': routineType.name,
      'startDate': _dateKey(startDate),
      'weekdays': weekdays.toList()..sort(),
      'isActive': isActive,
      'note': note,
    };
  }

  factory MedicineRoutine.fromJson(Map<String, dynamic> json) {
    return MedicineRoutine(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      dose: json['dose'] as String? ?? '',
      boxQuantity: json['boxQuantity'] as String? ?? '',
      time: json['timeHour'] == null || json['timeMinute'] == null
          ? null
          : TimeOfDay(
              hour: json['timeHour'] as int,
              minute: json['timeMinute'] as int,
            ),
      routineType: RoutineType.values.firstWhere(
        (type) => type.name == json['routineType'],
        orElse: () => RoutineType.daily,
      ),
      startDate: DateTime.tryParse(json['startDate'] as String? ?? '') ??
          _dateOnly(DateTime.now()),
      weekdays: (json['weekdays'] as List<dynamic>? ?? <dynamic>[])
          .whereType<int>()
          .toSet(),
      isActive: json['isActive'] as bool? ?? true,
      note: json['note'] as String? ?? '',
    );
  }
}

class MedicineState {
  const MedicineState({
    required this.routines,
    required this.takenDates,
    required this.notifyAfter,
    required this.unlockNotificationsEnabled,
  });

  final List<MedicineRoutine> routines;
  final Map<String, Set<String>> takenDates;
  final TimeOfDay notifyAfter;
  final bool unlockNotificationsEnabled;

  List<MedicineRoutine> dueFor(DateTime date) {
    return routines.where((routine) => routine.isDueOn(date)).toList()
      ..sort(_sortByDoseTime);
  }

  bool isTaken(MedicineRoutine routine, DateTime date) {
    return takenDates[routine.id]?.contains(_dateKey(date)) ?? false;
  }

  MedicineState copyWith({
    List<MedicineRoutine>? routines,
    Map<String, Set<String>>? takenDates,
    TimeOfDay? notifyAfter,
    bool? unlockNotificationsEnabled,
  }) {
    return MedicineState(
      routines: routines ?? this.routines,
      takenDates: takenDates ?? this.takenDates,
      notifyAfter: notifyAfter ?? this.notifyAfter,
      unlockNotificationsEnabled:
          unlockNotificationsEnabled ?? this.unlockNotificationsEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'routines': routines.map((routine) => routine.toJson()).toList(),
      'takenDates': takenDates.map(
        (key, value) => MapEntry(key, value.toList()..sort()),
      ),
      'notifyAfterHour': notifyAfter.hour,
      'notifyAfterMinute': notifyAfter.minute,
      'unlockNotificationsEnabled': unlockNotificationsEnabled,
    };
  }

  factory MedicineState.fromJson(Map<String, dynamic> json) {
    final takenJson = json['takenDates'] as Map<String, dynamic>? ?? {};

    return MedicineState(
      routines: (json['routines'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(MedicineRoutine.fromJson)
          .toList(),
      takenDates: takenJson.map(
        (key, value) => MapEntry(
          key,
          (value as List<dynamic>? ?? <dynamic>[]).whereType<String>().toSet(),
        ),
      ),
      notifyAfter: TimeOfDay(
        hour: json['notifyAfterHour'] as int? ?? 8,
        minute: json['notifyAfterMinute'] as int? ?? 0,
      ),
      unlockNotificationsEnabled:
          json['unlockNotificationsEnabled'] as bool? ?? true,
    );
  }
}

class MedicineStorage {
  Future<MedicineState> load() async {
    final jsonText = await _storageChannel.invokeMethod<String>('loadState');
    if (jsonText == null || jsonText.trim().isEmpty) {
      return _initialState();
    }

    final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
    return MedicineState.fromJson(decoded);
  }

  Future<void> save(MedicineState state) async {
    await _storageChannel.invokeMethod<void>(
      'saveState',
      jsonEncode(state.toJson()),
    );
  }

  Future<bool> startUnlockMonitor() async {
    return await _storageChannel.invokeMethod<bool>('startUnlockMonitor') ??
        false;
  }

  Future<void> stopUnlockMonitor() async {
    await _storageChannel.invokeMethod<void>('stopUnlockMonitor');
  }

  Future<bool> requestNotificationPermission() async {
    return await _storageChannel.invokeMethod<bool>(
          'requestNotificationPermission',
        ) ??
        false;
  }
}

class MedicineLookupResult {
  const MedicineLookupResult({
    this.medicineName,
    this.boxQuantity,
    this.message,
  });

  final String? medicineName;
  final String? boxQuantity;
  final String? message;
}

class MedicineCatalogItem {
  const MedicineCatalogItem({
    required this.name,
    this.boxQuantity,
  });

  final String name;
  final String? boxQuantity;
}

class MedicineLookupService {
  Map<String, MedicineCatalogItem>? _barcodeMedicines;

  Future<MedicineLookupResult> lookupFromScannedCode(String scannedCode) async {
    final fallbackName = _extractMedicineNameFromQr(scannedCode);
    final barcode = _extractBarcodeFromScannedCode(scannedCode);
    if (barcode == null) {
      return MedicineLookupResult(medicineName: fallbackName);
    }

    final MedicineCatalogItem? medicine;
    try {
      medicine = await _lookupByBarcode(barcode);
    } on FlutterError {
      return const MedicineLookupResult(
        message: 'Yerel ilaç listesi uygulama içinde bulunamadı.',
      );
    } on FormatException {
      return const MedicineLookupResult(
        message: 'Yerel ilaç listesi okunamadı.',
      );
    }

    if (medicine == null || medicine.name.trim().isEmpty) {
      return MedicineLookupResult(
        message: 'Barkod yerel ilaç listesinde bulunamadı: $barcode',
      );
    }

    return MedicineLookupResult(
      medicineName: medicine.name.trim(),
      boxQuantity: medicine.boxQuantity,
    );
  }

  Future<MedicineCatalogItem?> _lookupByBarcode(String barcode) async {
    final medicines = await _loadBarcodeMedicines();
    return medicines[barcode];
  }

  Future<Map<String, MedicineCatalogItem>> _loadBarcodeMedicines() async {
    if (_barcodeMedicines != null) {
      return _barcodeMedicines!;
    }

    final assetContent = await rootBundle.loadString(_medicineBarcodeAssetPath);
    final decoded = jsonDecode(assetContent);
    final barcodeMedicines = <String, MedicineCatalogItem>{};

    if (decoded is Map<String, dynamic>) {
      decoded.forEach((barcode, value) {
        final normalizedBarcode = _normalizeBarcode(barcode);
        if (value is String && value.trim().isNotEmpty) {
          barcodeMedicines[normalizedBarcode] = MedicineCatalogItem(
            name: value.trim(),
            boxQuantity: _extractBoxQuantityFromText(value),
          );
        }

        if (value is Map<String, dynamic>) {
          final medicineName = _readMedicineName(value);
          if (normalizedBarcode.isNotEmpty && medicineName != null) {
            barcodeMedicines[normalizedBarcode] = MedicineCatalogItem(
              name: medicineName,
              boxQuantity: _readBoxQuantity(value) ??
                  _extractBoxQuantityFromText(medicineName),
            );
          }
        }
      });
    }

    if (decoded is List) {
      for (final item in decoded.whereType<Map<String, dynamic>>()) {
        final barcode = _normalizeBarcode(item['Barkod']?.toString());
        final medicineName = _readMedicineName(item);
        if (barcode.isNotEmpty && medicineName != null) {
          barcodeMedicines[barcode] = MedicineCatalogItem(
            name: medicineName,
            boxQuantity: _readBoxQuantity(item) ??
                _extractBoxQuantityFromText(medicineName),
          );
        }
      }
    }

    _barcodeMedicines = barcodeMedicines;
    return barcodeMedicines;
  }
}

class MedicineHomePage extends StatefulWidget {
  const MedicineHomePage({super.key});

  @override
  State<MedicineHomePage> createState() => _MedicineHomePageState();
}

class _MedicineHomePageState extends State<MedicineHomePage> {
  final MedicineStorage _storage = MedicineStorage();
  final MedicineLookupService _medicineLookupService = MedicineLookupService();
  MedicineState _state = _initialState();
  DateTime _visibleCalendarMonth = _firstDayOfMonth(DateTime.now());
  bool _isCalendarExpanded = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final loadedState = await _storage.load();
    if (!mounted) {
      return;
    }

    setState(() {
      _state = loadedState;
      _isLoading = false;
    });

    await _prepareNotificationsOnStartup();
  }

  Future<void> _saveState(MedicineState state) async {
    setState(() {
      _state = state;
    });

    await _storage.save(state);
    await _syncUnlockMonitor(state);
  }

  Future<void> _prepareNotificationsOnStartup() async {
    await _storage.requestNotificationPermission();
    await _syncUnlockMonitor(_state);
  }

  Future<void> _syncUnlockMonitor(MedicineState state) async {
    if (state.unlockNotificationsEnabled) {
      await _storage.startUnlockMonitor();
      return;
    }

    await _storage.stopUnlockMonitor();
  }

  Future<void> _pickNotifyTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _state.notifyAfter,
    );
    if (picked == null) {
      return;
    }

    await _saveState(_state.copyWith(notifyAfter: picked));
  }

  Future<void> _toggleUnlockNotifications(bool isEnabled) async {
    await _saveState(_state.copyWith(unlockNotificationsEnabled: isEnabled));
  }

  void _openPrivacyNotice() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PrivacyNoticePage(),
      ),
    );
  }

  Future<void> _openRoutineForm([MedicineRoutine? routine]) async {
    final savedRoutine = await showModalBottomSheet<MedicineRoutine>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => RoutineFormSheet(
        routine: routine,
        medicineLookupService: _medicineLookupService,
      ),
    );
    if (savedRoutine == null) {
      return;
    }

    final routines = [..._state.routines];
    final existingIndex = routines.indexWhere((item) => item.id == savedRoutine.id);
    if (existingIndex >= 0) {
      routines[existingIndex] = savedRoutine;
    } else {
      routines.add(savedRoutine);
    }

    await _saveState(_state.copyWith(routines: routines));
  }

  Future<void> _deleteRoutine(MedicineRoutine routine) async {
    final routines = _state.routines
        .where((currentRoutine) => currentRoutine.id != routine.id)
        .toList();
    final takenDates = Map<String, Set<String>>.from(_state.takenDates)
      ..remove(routine.id);

    await _saveState(
      _state.copyWith(routines: routines, takenDates: takenDates),
    );
  }

  Future<void> _toggleTaken(MedicineRoutine routine, bool isTaken) async {
    final dateKey = _dateKey(DateTime.now());
    final takenDates = _cloneTakenDates(_state.takenDates);
    final routineDates = takenDates.putIfAbsent(routine.id, () => <String>{});

    if (isTaken) {
      routineDates.add(dateKey);
    } else {
      routineDates.remove(dateKey);
    }

    await _saveState(_state.copyWith(takenDates: takenDates));
  }

  void _toggleCalendarView() {
    setState(() {
      _isCalendarExpanded = !_isCalendarExpanded;
      if (_isCalendarExpanded) {
        _visibleCalendarMonth = _firstDayOfMonth(DateTime.now());
      }
    });
  }

  void _changeVisibleCalendarMonth(int monthOffset) {
    setState(() {
      _visibleCalendarMonth = DateTime(
        _visibleCalendarMonth.year,
        _visibleCalendarMonth.month + monthOffset,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dueRoutines = _state.dueFor(today);
    final completedCount = dueRoutines
        .where((routine) => _state.isTaken(routine, today))
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('İlaç Takibi'),
        actions: [
          IconButton(
            onPressed: _openPrivacyNotice,
            tooltip: 'Gizlilik ve beyan',
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                _SummaryPanel(
                  completedCount: completedCount,
                  totalCount: dueRoutines.length,
                  notifyAfter: _state.notifyAfter,
                  unlockNotificationsEnabled:
                      _state.unlockNotificationsEnabled,
                  onChangeTime: _pickNotifyTime,
                  onToggleUnlockNotifications: _toggleUnlockNotifications,
                ),
                const SizedBox(height: 16),
                _SectionTitle(
                  title: 'Bugün',
                  actionText: dueRoutines.isEmpty ? null : '$completedCount/${dueRoutines.length}',
                ),
                const SizedBox(height: 8),
                if (dueRoutines.isEmpty)
                  const _EmptyPanel(
                    icon: Icons.check_circle_outline,
                    title: 'Bugün alınacak ilaç yok',
                    message: 'Yeni rutin eklediğinizde takvim burada görünür.',
                  )
                else
                  ...dueRoutines.map(
                    (routine) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TodayRoutineTile(
                        routine: routine,
                        isTaken: _state.isTaken(routine, today),
                        onChanged: (value) => _toggleTaken(routine, value),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                MedicineCalendarPanel(
                  state: _state,
                  today: today,
                  visibleMonth: _visibleCalendarMonth,
                  isExpanded: _isCalendarExpanded,
                  onToggle: _toggleCalendarView,
                  onPreviousMonth: () => _changeVisibleCalendarMonth(-1),
                  onNextMonth: () => _changeVisibleCalendarMonth(1),
                ),
                const SizedBox(height: 16),
                const _SectionTitle(title: 'Rutinler'),
                const SizedBox(height: 8),
                if (_state.routines.isEmpty)
                  const _EmptyPanel(
                    icon: Icons.medication_outlined,
                    title: 'Henüz rutin yok',
                    message: 'İlacın adını, dozunu ve tekrar düzenini ekleyin.',
                  )
                else
                  ..._state.routines.map(
                    (routine) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RoutineTile(
                        routine: routine,
                        takenCount: _state.takenDates[routine.id]?.length ?? 0,
                        onEdit: () => _openRoutineForm(routine),
                        onDelete: () => _deleteRoutine(routine),
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRoutineForm(),
        icon: const Icon(Icons.add),
        label: const Text('İlaç ekle'),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.completedCount,
    required this.totalCount,
    required this.notifyAfter,
    required this.unlockNotificationsEnabled,
    required this.onChangeTime,
    required this.onToggleUnlockNotifications,
  });

  final int completedCount;
  final int totalCount;
  final TimeOfDay notifyAfter;
  final bool unlockNotificationsEnabled;
  final VoidCallback onChangeTime;
  final ValueChanged<bool> onToggleUnlockNotifications;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bugünkü takip',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    totalCount == 0
                        ? 'Plan temiz'
                        : '$completedCount ilaç alındı, ${totalCount - completedCount} kaldı',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                const Icon(Icons.health_and_safety_outlined, size: 36),
              ],
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Kilit açma bildirimleri'),
              subtitle: const Text(
                'Kapalıyken arka plan kilit açma takibi çalışmaz.',
              ),
              value: unlockNotificationsEnabled,
              onChanged: onToggleUnlockNotifications,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: unlockNotificationsEnabled ? onChangeTime : null,
              icon: const Icon(Icons.lock_open_outlined),
              label: Text(
                '${_formatTime(notifyAfter)} sonrası kilit açmada bildir',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TodayRoutineTile extends StatelessWidget {
  const TodayRoutineTile({
    super.key,
    required this.routine,
    required this.isTaken,
    required this.onChanged,
  });

  final MedicineRoutine routine;
  final bool isTaken;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: CheckboxListTile(
        value: isTaken,
        onChanged: (value) => onChanged(value ?? false),
        secondary: const Icon(Icons.medication_liquid_outlined),
        title: Text(routine.name),
        subtitle: Text(_todayRoutineDescription(routine)),
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }
}

class MedicineCalendarPanel extends StatelessWidget {
  const MedicineCalendarPanel({
    super.key,
    required this.state,
    required this.today,
    required this.visibleMonth,
    required this.isExpanded,
    required this.onToggle,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final MedicineState state;
  final DateTime today;
  final DateTime visibleMonth;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              if (isExpanded)
                _CalendarMonthHeader(
                  visibleMonth: visibleMonth,
                  onPreviousMonth: onPreviousMonth,
                  onNextMonth: onNextMonth,
                )
              else
                const _CalendarWeekHeader(),
              const SizedBox(height: 8),
              if (isExpanded)
                _MonthCalendarGrid(
                  state: state,
                  today: today,
                  visibleMonth: visibleMonth,
                )
              else
                _WeekCalendarRow(
                  state: state,
                  today: today,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarWeekHeader extends StatelessWidget {
  const _CalendarWeekHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Haftalık takvim',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Spacer(),
        const Icon(Icons.expand_more, size: 20),
      ],
    );
  }
}

class _CalendarMonthHeader extends StatelessWidget {
  const _CalendarMonthHeader({
    required this.visibleMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final DateTime visibleMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPreviousMonth,
          tooltip: 'Önceki ay',
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            _formatMonthYear(visibleMonth),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          onPressed: onNextMonth,
          tooltip: 'Sonraki ay',
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _WeekCalendarRow extends StatelessWidget {
  const _WeekCalendarRow({
    required this.state,
    required this.today,
  });

  final MedicineState state;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final weekStart = _startOfWeek(today);
    final dates = List.generate(
      _daysPerWeek,
      (index) => weekStart.add(Duration(days: index)),
    );

    return Row(
      children: dates
          .map(
            (date) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _CalendarDayCell(
                  date: date,
                  routineCount: state.dueFor(date).length,
                  isToday: _isSameDate(date, today),
                  isOutsideMonth: false,
                  height: 72,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MonthCalendarGrid extends StatelessWidget {
  const _MonthCalendarGrid({
    required this.state,
    required this.today,
    required this.visibleMonth,
  });

  final MedicineState state;
  final DateTime today;
  final DateTime visibleMonth;

  @override
  Widget build(BuildContext context) {
    final gridStart = _startOfWeek(visibleMonth);
    final dates = List.generate(
      _daysPerWeek * 6,
      (index) => gridStart.add(Duration(days: index)),
    );

    return Column(
      children: [
        Row(
          children: _weekdayLabels
              .map(
                (label) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _CalendarWeekdayText(
                      label: label,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        GridView.builder(
          itemCount: dates.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _daysPerWeek,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            mainAxisExtent: 58,
          ),
          itemBuilder: (context, index) {
            final date = dates[index];
            return _CalendarDayCell(
              date: date,
              routineCount: state.dueFor(date).length,
              isToday: _isSameDate(date, today),
              isOutsideMonth: date.month != visibleMonth.month,
              height: 58,
            );
          },
        ),
      ],
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.routineCount,
    required this.isToday,
    required this.isOutsideMonth,
    required this.height,
  });

  final DateTime date;
  final int routineCount;
  final bool isToday;
  final bool isOutsideMonth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = isToday ? colorScheme.primary : const Color(0xFFE1EAE5);
    final backgroundColor = isToday
        ? colorScheme.primaryContainer.withValues(alpha: 0.55)
        : Colors.white;
    final textColor = isOutsideMonth
        ? colorScheme.onSurface.withValues(alpha: 0.35)
        : colorScheme.onSurface;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 7,
            top: 6,
            right: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 13,
                  child: _CalendarWeekdayText(
                    label: _weekdayLabels[date.weekday - 1],
                    color: textColor,
                    textAlign: TextAlign.left,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  date.day.toString(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: textColor,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: _PillIconStack(
              count: routineCount,
              maxHeight: height - 36,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarWeekdayText extends StatelessWidget {
  const _CalendarWeekdayText({
    required this.label,
    required this.color,
    required this.textAlign,
  });

  final String label;
  final Color color;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      alignment: textAlign == TextAlign.center
          ? Alignment.center
          : Alignment.centerLeft,
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        textAlign: textAlign,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _PillIconStack extends StatelessWidget {
  const _PillIconStack({
    required this.count,
    required this.maxHeight,
  });

  final int count;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 30,
        maxHeight: maxHeight,
      ),
      child: SizedBox(
        width: 30,
        height: maxHeight,
        child: FittedBox(
          alignment: Alignment.bottomRight,
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 18,
            child: Wrap(
              alignment: WrapAlignment.end,
              runAlignment: WrapAlignment.end,
              spacing: 0,
              runSpacing: 0,
              children: List.generate(
                count,
                (index) => const _CapsuleMarker(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CapsuleMarker extends StatelessWidget {
  const _CapsuleMarker();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _capsuleMarkerAssetPath,
      width: 9,
      height: 9,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

class PrivacyNoticePage extends StatelessWidget {
  const PrivacyNoticePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gizlilik ve Beyan'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _NoticeSection(
            icon: Icons.health_and_safety_outlined,
            title: 'Tıbbi tavsiye değildir',
            message:
                'İlaç Takip ilaç önermez, doz belirlemez, reçete yerine geçmez ve tedavi kararı vermez. Uygulama yalnızca kullanıcının kendi girdiği ilaç rutinlerini takip etmesine yardımcı olur.',
          ),
          SizedBox(height: 12),
          _NoticeSection(
            icon: Icons.storage_outlined,
            title: 'Veriler cihazda saklanır',
            message:
                'İlaç adı, doz, kutu adedi, rutin bilgisi ve alındı kayıtları cihazdaki yerel depolamada tutulur. Bu bilgiler uygulama tarafından bir sunucuya gönderilmez.',
          ),
          SizedBox(height: 12),
          _NoticeSection(
            icon: Icons.qr_code_scanner_outlined,
            title: 'Kamera kullanımı',
            message:
                'Kamera yalnızca ilaç kutusundaki QR veya DataMatrix kodunu okumak için kullanılır. Barkod eşleştirme APK içindeki yerel ilaç listesiyle yapılır.',
          ),
          SizedBox(height: 12),
          _NoticeSection(
            icon: Icons.notifications_active_outlined,
            title: 'Bildirimler',
            message:
                'Bildirim izni ilaç hatırlatmalarını göstermek için istenir. Kilit açma bildirimleri kapatıldığında arka plan kilit açma takibi durdurulur.',
          ),
        ],
      ),
    );
  }
}

class _NoticeSection extends StatelessWidget {
  const _NoticeSection({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoutineTile extends StatelessWidget {
  const RoutineTile({
    super.key,
    required this.routine,
    required this.takenCount,
    required this.onEdit,
    required this.onDelete,
  });

  final MedicineRoutine routine;
  final int takenCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          routine.isActive ? Icons.medication_outlined : Icons.pause_circle_outline,
        ),
        title: Text(routine.name),
        subtitle: Text(_routineDescription(routine, takenCount: takenCount)),
        trailing: PopupMenuButton<String>(
          tooltip: 'Rutin işlemleri',
          onSelected: (value) {
            if (value == 'edit') {
              onEdit();
            }
            if (value == 'delete') {
              onDelete();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'edit',
              child: Text('Düzenle'),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text('Sil'),
            ),
          ],
        ),
      ),
    );
  }
}

class RoutineFormSheet extends StatefulWidget {
  const RoutineFormSheet({
    super.key,
    required this.medicineLookupService,
    this.routine,
  });

  final MedicineLookupService medicineLookupService;
  final MedicineRoutine? routine;

  @override
  State<RoutineFormSheet> createState() => _RoutineFormSheetState();
}

class _RoutineFormSheetState extends State<RoutineFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _doseController;
  late final TextEditingController _boxQuantityController;
  late final TextEditingController _noteController;
  late RoutineType _routineType;
  late TimeOfDay _time;
  late Set<int> _weekdays;
  late bool _isActive;
  late bool _hasDoseTime;
  late bool _startsTomorrowForEveryOtherDay;
  bool _isLookingUpMedicine = false;

  @override
  void initState() {
    super.initState();
    final routine = widget.routine;
    _nameController = TextEditingController(text: routine?.name ?? '');
    _doseController = TextEditingController(
      text: _editableDoseValue(routine?.dose ?? ''),
    );
    _boxQuantityController = TextEditingController(
      text: _editableDoseValue(routine?.boxQuantity ?? ''),
    );
    _noteController = TextEditingController(text: routine?.note ?? '');
    _routineType = routine?.routineType ?? RoutineType.daily;
    _time = routine?.time ?? const TimeOfDay(hour: 9, minute: 0);
    _weekdays = routine?.weekdays.toSet() ?? {DateTime.now().weekday};
    _isActive = routine?.isActive ?? true;
    _hasDoseTime = routine?.time != null;
    _startsTomorrowForEveryOtherDay =
        routine?.routineType == RoutineType.everyOtherDay &&
        _dateOnly(routine!.startDate).isAfter(_dateOnly(DateTime.now()));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
    _boxQuantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked == null) {
      return;
    }

    setState(() {
      _time = picked;
    });
  }

  Future<void> _scanMedicineQr() async {
    final qrValue = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const MedicineQrScannerPage()),
    );
    if (qrValue == null || qrValue.trim().isEmpty) {
      return;
    }

    setState(() {
      _isLookingUpMedicine = true;
      if (_nameController.text.trim().startsWith('Barkod ')) {
        _nameController.clear();
      }
    });

    final lookupResult =
        await widget.medicineLookupService.lookupFromScannedCode(qrValue);
    if (!mounted) {
      return;
    }

    setState(() {
      _isLookingUpMedicine = false;
      if (lookupResult.medicineName != null) {
        _nameController.text = lookupResult.medicineName!;
      }
      if (lookupResult.boxQuantity != null) {
        _boxQuantityController.text = lookupResult.boxQuantity!;
      }
    });

    if (lookupResult.medicineName != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İlaç adı barkoddan alındı.')),
      );
    } else if (lookupResult.message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lookupResult.message!)),
      );
    }
  }

  void _changeDoseBy(double step) {
    final currentDose = _parseDose(_doseController.text) ?? 0;
    final nextDose = currentDose + step;
    if (nextDose < 0) {
      return;
    }

    setState(() {
      _doseController.text = _formatDose(nextDose);
      _doseController.selection = TextSelection.collapsed(
        offset: _doseController.text.length,
      );
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_routineType == RoutineType.weekly && _weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Haftalık rutin için en az bir gün seçin.')),
      );
      return;
    }

    final existingRoutine = widget.routine;
    final effectiveStartDate = _routineType == RoutineType.everyOtherDay
        ? _dateOnly(DateTime.now()).add(
            Duration(days: _startsTomorrowForEveryOtherDay ? 1 : 0),
          )
        : existingRoutine?.startDate ?? _dateOnly(DateTime.now());
    final routine = MedicineRoutine(
      id: existingRoutine?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      dose: _formatDose(_parseDose(_doseController.text)!),
      boxQuantity: _formatDose(_parseDose(_boxQuantityController.text)!),
      time: _hasDoseTime ? _time : null,
      routineType: _routineType,
      startDate: effectiveStartDate,
      weekdays: _weekdays,
      isActive: _isActive,
      note: _noteController.text.trim(),
    );

    Navigator.of(context).pop(routine);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom + 20;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.routine == null ? 'İlaç ekle' : 'İlacı düzenle',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'İlaç adı',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: _isLookingUpMedicine ? null : _scanMedicineQr,
                    tooltip: 'Kod oku',
                    icon: _isLookingUpMedicine
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.qr_code_scanner_outlined),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'İlaç adı gerekli';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _boxQuantityController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  DecimalDoseInputFormatter(decimalRange: 2),
                ],
                decoration: const InputDecoration(
                  labelText: 'Kutuda kaç adet var',
                  hintText: 'Örn. 30.00',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Kutu adedi gerekli';
                  }
                  final boxQuantity = _parseDose(value);
                  if (boxQuantity == null || boxQuantity <= 0) {
                    return 'Kutu adedi sıfırdan büyük olmalı';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 128,
                    child: DoseStepperField(
                      controller: _doseController,
                      onIncrease: () => _changeDoseBy(1),
                      onDecrease: () => _changeDoseBy(-1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<RoutineType>(
                      value: _routineType,
                      decoration: const InputDecoration(
                        labelText: 'Rutin',
                        border: OutlineInputBorder(),
                      ),
                      items: RoutineType.values
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _routineType = value;
                          if (value == RoutineType.everyOtherDay) {
                            _startsTomorrowForEveryOtherDay = false;
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
              if (_routineType == RoutineType.weekly) ...[
                const SizedBox(height: 12),
                WeekdaySelector(
                  selectedDays: _weekdays,
                  onChanged: (selectedDays) {
                    setState(() {
                      _weekdays = selectedDays;
                    });
                  },
                ),
              ],
              if (_routineType == RoutineType.everyOtherDay) ...[
                const SizedBox(height: 4),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Yarın başlasın'),
                  subtitle: const Text('Kapalıysa rutin bugünden başlar.'),
                  value: _startsTomorrowForEveryOtherDay,
                  onChanged: (value) {
                    setState(() {
                      _startsTomorrowForEveryOtherDay = value ?? false;
                    });
                  },
                ),
              ],
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('İlaç saati belirt'),
                value: _hasDoseTime,
                onChanged: (value) {
                  setState(() {
                    _hasDoseTime = value;
                  });
                },
              ),
              if (_hasDoseTime)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.schedule_outlined),
                        label: Text(_formatTime(_time)),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Not',
                  border: OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aktif'),
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MedicineQrScannerPage extends StatefulWidget {
  const MedicineQrScannerPage({super.key});

  @override
  State<MedicineQrScannerPage> createState() => _MedicineQrScannerPageState();
}

class _MedicineQrScannerPageState extends State<MedicineQrScannerPage> {
  final MobileScannerController _scannerController = MobileScannerController(
    formats: [
      BarcodeFormat.qrCode,
      BarcodeFormat.dataMatrix,
    ],
  );
  bool _hasResult = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_hasResult) {
      return;
    }

    String? value;
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue?.trim();
      if (rawValue != null && rawValue.isNotEmpty) {
        value = rawValue;
        break;
      }
    }

    if (value == null) {
      return;
    }

    _hasResult = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kod oku'),
        actions: [
          IconButton(
            onPressed: () => _scannerController.toggleTorch(),
            tooltip: 'Flaş',
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleBarcode,
          ),
          const _QrScannerFrame(),
        ],
      ),
    );
  }
}

class DoseStepperField extends StatelessWidget {
  const DoseStepperField({
    super.key,
    required this.controller,
    required this.onIncrease,
    required this.onDecrease,
  });

  final TextEditingController controller;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                DecimalDoseInputFormatter(decimalRange: 2),
              ],
              decoration: const InputDecoration(
                labelText: 'Doz',
                hintText: '1.00',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Gerekli';
                }
                if (_parseDose(value) == null) {
                  return 'Sayı';
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Expanded(
                  child: _DoseArrowButton(
                    icon: Icons.keyboard_arrow_up,
                    tooltip: 'Dozu artır',
                    onPressed: onIncrease,
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: _DoseArrowButton(
                    icon: Icons.keyboard_arrow_down,
                    tooltip: 'Dozu azalt',
                    onPressed: onDecrease,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DoseArrowButton extends StatelessWidget {
  const _DoseArrowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      padding: EdgeInsets.zero,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
    );
  }
}

class _QrScannerFrame extends StatelessWidget {
  const _QrScannerFrame();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.16)),
      child: Center(
        child: Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.white,
              width: 3,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: Colors.black.withValues(alpha: 0.62),
              child: const Text(
                'İlaç kutusundaki QR veya DataMatrix kodunu çerçeveye alın',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DecimalDoseInputFormatter extends TextInputFormatter {
  DecimalDoseInputFormatter({required this.decimalRange})
      : assert(decimalRange >= 0);

  final int decimalRange;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(',', '.');
    if (text.isEmpty) {
      return newValue;
    }

    final pattern = RegExp('^\\d{0,6}(\\.\\d{0,$decimalRange})?\$');
    if (!pattern.hasMatch(text)) {
      return oldValue;
    }

    if (text != newValue.text) {
      return newValue.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }

    return newValue;
  }
}

class WeekdaySelector extends StatelessWidget {
  const WeekdaySelector({
    super.key,
    required this.selectedDays,
    required this.onChanged,
  });

  final Set<int> selectedDays;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(_weekdayLabels.length, (index) {
        final weekday = index + 1;
        final isSelected = selectedDays.contains(weekday);

        return FilterChip(
          label: Text(_weekdayLabels[index]),
          selected: isSelected,
          onSelected: (selected) {
            final updatedDays = selectedDays.toSet();
            if (selected) {
              updatedDays.add(weekday);
            } else {
              updatedDays.remove(weekday);
            }
            onChanged(updatedDays);
          },
        );
      }),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.actionText,
  });

  final String title;
  final String? actionText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (actionText != null)
          Text(
            actionText!,
            style: Theme.of(context).textTheme.labelLarge,
          ),
      ],
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(icon, size: 36),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

MedicineState _initialState() {
  return const MedicineState(
    routines: [],
    takenDates: {},
    notifyAfter: TimeOfDay(hour: 8, minute: 0),
    unlockNotificationsEnabled: true,
  );
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

DateTime _firstDayOfMonth(DateTime date) {
  return DateTime(date.year, date.month);
}

DateTime _startOfWeek(DateTime date) {
  final cleanDate = _dateOnly(date);
  return cleanDate.subtract(Duration(days: cleanDate.weekday - 1));
}

bool _isSameDate(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

String _dateKey(DateTime date) {
  final cleanDate = _dateOnly(date);
  return '${cleanDate.year.toString().padLeft(4, '0')}-'
      '${cleanDate.month.toString().padLeft(2, '0')}-'
      '${cleanDate.day.toString().padLeft(2, '0')}';
}

String _formatTime(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}

String _formatMonthYear(DateTime date) {
  return '${_monthLabels[date.month - 1]} ${date.year}';
}

String _routineDescription(
  MedicineRoutine routine, {
  int takenCount = 0,
}) {
  final buffer = StringBuffer();
  if (routine.time != null) {
    buffer
      ..write(_formatTime(routine.time!))
      ..write(' - ');
  }

  buffer
    ..write(routine.dose)
    ..write(' - ')
    ..write(routine.routineType.label);

  final boxSummary = _boxQuantitySummary(routine, takenCount: takenCount);
  if (boxSummary != null) {
    buffer
      ..write(' - ')
      ..write(boxSummary);
  }

  if (routine.routineType == RoutineType.weekly) {
    final days = routine.weekdays.toList()..sort();
    buffer.write(' (');
    buffer.write(days.map((day) => _weekdayLabels[day - 1]).join(', '));
    buffer.write(')');
  }

  if (!routine.isActive) {
    buffer.write(' - Pasif');
  }

  return buffer.toString();
}

String? _boxQuantitySummary(
  MedicineRoutine routine, {
  required int takenCount,
}) {
  final boxQuantity = _parseDose(routine.boxQuantity);
  final dose = _parseDose(routine.dose);
  if (boxQuantity == null || boxQuantity <= 0 || dose == null || dose <= 0) {
    return null;
  }

  final usedQuantity = takenCount * dose;
  final remainingQuantity =
      (boxQuantity - usedQuantity).clamp(0, boxQuantity).toDouble();
  final doseDays = remainingQuantity / dose;
  final calendarDays = _estimateCalendarDays(routine, doseDays);
  return 'Kalan ${_compactNumber(remainingQuantity)} adet, yaklaşık $calendarDays gün';
}

int _estimateCalendarDays(MedicineRoutine routine, double doseDays) {
  switch (routine.routineType) {
    case RoutineType.daily:
      return doseDays.floor();
    case RoutineType.everyOtherDay:
      return (doseDays * 2).floor();
    case RoutineType.weekly:
      final weeklyDoseDays = routine.weekdays.isEmpty ? 1 : routine.weekdays.length;
      return (doseDays / weeklyDoseDays * 7).floor();
  }
}

int _sortByDoseTime(MedicineRoutine first, MedicineRoutine second) {
  final firstMinutes = first.time == null
      ? 24 * 60
      : first.time!.hour * 60 + first.time!.minute;
  final secondMinutes = second.time == null
      ? 24 * 60
      : second.time!.hour * 60 + second.time!.minute;
  return firstMinutes.compareTo(secondMinutes);
}

String _todayRoutineDescription(MedicineRoutine routine) {
  if (routine.time == null) {
    return routine.dose;
  }

  return '${_formatTime(routine.time!)} - ${routine.dose}';
}

String _extractMedicineNameFromQr(String qrValue) {
  final trimmedValue = qrValue.trim();
  final jsonName = _extractMedicineNameFromJson(trimmedValue);
  if (jsonName != null) {
    return jsonName;
  }

  final uriName = _extractMedicineNameFromUri(trimmedValue);
  if (uriName != null) {
    return uriName;
  }

  final labelledName = _extractMedicineNameFromLabelledText(trimmedValue);
  if (labelledName != null) {
    return labelledName;
  }

  return trimmedValue;
}

String? _extractMedicineNameFromJson(String qrValue) {
  try {
    final decoded = jsonDecode(qrValue);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final normalizedValues = decoded.map(
      (key, value) => MapEntry(key.toLowerCase(), value),
    );
    for (final key in _medicineNameKeys) {
      final value = normalizedValues[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
  } on FormatException {
    return null;
  }

  return null;
}

String? _extractMedicineNameFromUri(String qrValue) {
  final uri = Uri.tryParse(qrValue);
  if (uri == null || !uri.hasQuery) {
    return null;
  }

  final normalizedParameters = uri.queryParameters.map(
    (key, value) => MapEntry(key.toLowerCase(), value),
  );
  for (final key in _medicineNameKeys) {
    final value = normalizedParameters[key];
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
    }
  }

  return null;
}

String? _extractMedicineNameFromLabelledText(String qrValue) {
  final lines = qrValue.split(RegExp(r'[\r\n;]+'));
  for (final line in lines) {
    final parts = line.split(RegExp(r'[:=]'));
    if (parts.length < 2) {
      continue;
    }

    final key = parts.first.trim().toLowerCase();
    final value = parts.sublist(1).join(':').trim();
    if (_medicineNameKeys.contains(key) && value.isNotEmpty) {
      return value;
    }
  }

  return null;
}

String? _extractGtinFromGs1(String qrValue) {
  final printedGtinMatch = RegExp(r'\(01\)\s*(\d{14})').firstMatch(qrValue);
  if (printedGtinMatch != null) {
    return printedGtinMatch.group(1);
  }

  final compactGtinMatch = RegExp(r'01(\d{14})').firstMatch(qrValue);
  return compactGtinMatch?.group(1);
}

String? _extractBarcodeFromScannedCode(String scannedCode) {
  final gs1Gtin = _extractGtinFromGs1(scannedCode);
  if (gs1Gtin != null) {
    return _normalizeBarcode(gs1Gtin);
  }

  final digits = scannedCode.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 13 || digits.length == 14) {
    return _normalizeBarcode(digits);
  }

  return null;
}

String _normalizeBarcode(String? value) {
  final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.length == 14 && digits.startsWith('0')) {
    return digits.substring(1);
  }

  return digits;
}

String? _readMedicineName(Map<String, dynamic> medicine) {
  for (final key in _apiMedicineNameKeys) {
    final value = medicine[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }

  return null;
}

String? _readBoxQuantity(Map<String, dynamic> medicine) {
  for (final key in _boxQuantityKeys) {
    final value = medicine[key];
    final quantity = _parseDose(value?.toString() ?? '');
    if (quantity != null && quantity > 0) {
      return _formatDose(quantity);
    }
  }

  return null;
}

String? _extractBoxQuantityFromText(String value) {
  final match = RegExp(
    r'(\d+(?:[,.]\d+)?)\s*(?:adet|tablet|tbl|kaps[üu]l|kap|ampul|flakon|saşe|sase|supp|draje|pastil)',
    caseSensitive: false,
  ).firstMatch(value);
  if (match == null) {
    return null;
  }

  final quantity = _parseDose(match.group(1) ?? '');
  if (quantity == null || quantity <= 0) {
    return null;
  }

  return _formatDose(quantity);
}

double? _parseDose(String value) {
  final normalizedValue = value.trim().replaceAll(',', '.');
  if (normalizedValue.isEmpty || normalizedValue == '.') {
    return null;
  }

  return double.tryParse(normalizedValue);
}

String _formatDose(double value) {
  return value.toStringAsFixed(2);
}

String _compactNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }

  return value.toStringAsFixed(2);
}

String _editableDoseValue(String value) {
  final parsedDose = _parseDose(value);
  if (parsedDose == null) {
    return '';
  }

  return _formatDose(parsedDose);
}

Map<String, Set<String>> _cloneTakenDates(Map<String, Set<String>> source) {
  return source.map((key, value) => MapEntry(key, value.toSet()));
}

const _weekdayLabels = [
  'Pzt',
  'Sal',
  'Çar',
  'Per',
  'Cum',
  'Cmt',
  'Paz',
];

const _monthLabels = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

const _medicineNameKeys = [
  'name',
  'medicine',
  'medicine name',
  'medicine_name',
  'medicinename',
  'drug',
  'drug name',
  'drug_name',
  'drugname',
  'ilac',
  'ilac adi',
  'ilac_adi',
  'ilacadi',
  'ilaç',
  'ilaç adı',
  'ilaç_adı',
  'ilaçadı',
];

const _apiMedicineNameKeys = [
  'İlaç Adı',
  'ilaç adı',
  'Ilac Adi',
  'ilac_adi',
  'la_ad',
  'name',
];

const _boxQuantityKeys = [
  'boxQuantity',
  'box_quantity',
  'Kutu Adedi',
  'Kutu Miktarı',
  'Ambalaj Miktarı',
  'Ambalaj Miktari',
  'Ambalaj Adedi',
  'Adet',
];
