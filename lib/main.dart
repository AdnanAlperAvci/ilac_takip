import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  runApp(const MedicineApp());
}

const _storageChannel = MethodChannel('ilac/storage');

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
  final TimeOfDay time;
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

    switch (routineType) {
      case RoutineType.daily:
        return true;
      case RoutineType.everyOtherDay:
        return currentDate.difference(firstDate).inDays.isEven;
      case RoutineType.weekly:
        return weekdays.contains(currentDate.weekday);
    }
  }

  MedicineRoutine copyWith({
    String? name,
    String? dose,
    TimeOfDay? time,
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
      time: time ?? this.time,
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
      'timeHour': time.hour,
      'timeMinute': time.minute,
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
      time: TimeOfDay(
        hour: json['timeHour'] as int? ?? 9,
        minute: json['timeMinute'] as int? ?? 0,
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
  });

  final List<MedicineRoutine> routines;
  final Map<String, Set<String>> takenDates;
  final TimeOfDay notifyAfter;

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
  }) {
    return MedicineState(
      routines: routines ?? this.routines,
      takenDates: takenDates ?? this.takenDates,
      notifyAfter: notifyAfter ?? this.notifyAfter,
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

  Future<bool> requestNotificationPermission() async {
    return await _storageChannel.invokeMethod<bool>(
          'requestNotificationPermission',
        ) ??
        false;
  }
}

class MedicineHomePage extends StatefulWidget {
  const MedicineHomePage({super.key});

  @override
  State<MedicineHomePage> createState() => _MedicineHomePageState();
}

class _MedicineHomePageState extends State<MedicineHomePage> {
  final MedicineStorage _storage = MedicineStorage();
  MedicineState _state = _initialState();
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
  }

  Future<void> _saveState(MedicineState state) async {
    setState(() {
      _state = state;
    });

    await _storage.save(state);
  }

  Future<void> _requestPermission() async {
    final isGranted = await _storage.requestNotificationPermission();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isGranted
              ? 'Bildirim izni açık.'
              : 'Bildirim izni verilmedi. Android ayarlarından açabilirsiniz.',
        ),
      ),
    );
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

  Future<void> _openRoutineForm([MedicineRoutine? routine]) async {
    final savedRoutine = await showModalBottomSheet<MedicineRoutine>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => RoutineFormSheet(routine: routine),
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
            onPressed: _requestPermission,
            tooltip: 'Bildirim izni',
            icon: const Icon(Icons.notifications_active_outlined),
          ),
          IconButton(
            onPressed: _pickNotifyTime,
            tooltip: 'Kilit açma bildirim saati',
            icon: const Icon(Icons.lock_clock_outlined),
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
                  onChangeTime: _pickNotifyTime,
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
    required this.onChangeTime,
  });

  final int completedCount;
  final int totalCount;
  final TimeOfDay notifyAfter;
  final VoidCallback onChangeTime;

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
            OutlinedButton.icon(
              onPressed: onChangeTime,
              icon: const Icon(Icons.lock_open_outlined),
              label: Text(
                '${_formatTime(notifyAfter)} sonrası ilk kilit açmada bildir',
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
        subtitle: Text('${_formatTime(routine.time)} - ${routine.dose}'),
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }
}

class RoutineTile extends StatelessWidget {
  const RoutineTile({
    super.key,
    required this.routine,
    required this.onEdit,
    required this.onDelete,
  });

  final MedicineRoutine routine;
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
        subtitle: Text(_routineDescription(routine)),
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
    this.routine,
  });

  final MedicineRoutine? routine;

  @override
  State<RoutineFormSheet> createState() => _RoutineFormSheetState();
}

class _RoutineFormSheetState extends State<RoutineFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _doseController;
  late final TextEditingController _noteController;
  late RoutineType _routineType;
  late TimeOfDay _time;
  late DateTime _startDate;
  late Set<int> _weekdays;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final routine = widget.routine;
    _nameController = TextEditingController(text: routine?.name ?? '');
    _doseController = TextEditingController(
      text: _editableDoseValue(routine?.dose ?? ''),
    );
    _noteController = TextEditingController(text: routine?.note ?? '');
    _routineType = routine?.routineType ?? RoutineType.daily;
    _time = routine?.time ?? const TimeOfDay(hour: 9, minute: 0);
    _startDate = routine?.startDate ?? _dateOnly(DateTime.now());
    _weekdays = routine?.weekdays.toSet() ?? {DateTime.now().weekday};
    _isActive = routine?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
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

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) {
      return;
    }

    setState(() {
      _startDate = _dateOnly(picked);
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
      _nameController.text = _extractMedicineNameFromQr(qrValue);
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
    final routine = MedicineRoutine(
      id: existingRoutine?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      dose: _formatDose(_parseDose(_doseController.text)!),
      time: _time,
      routineType: _routineType,
      startDate: _startDate,
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
                    onPressed: _scanMedicineQr,
                    tooltip: 'QR oku',
                    icon: const Icon(Icons.qr_code_scanner_outlined),
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
                controller: _doseController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  DecimalDoseInputFormatter(decimalRange: 2),
                ],
                decoration: const InputDecoration(
                  labelText: 'Doz',
                  hintText: 'Örn. 1.00',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Doz gerekli';
                  }
                  if (_parseDose(value) == null) {
                    return 'Doz sayı olmalı';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RoutineType>(
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
                  });
                },
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(_formatTime(_time)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickStartDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(_formatDate(_startDate)),
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
    formats: [BarcodeFormat.qrCode],
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
        title: const Text('QR oku'),
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
                'İlaç kutusundaki QR kodu çerçeveye alın',
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
  );
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

String _dateKey(DateTime date) {
  final cleanDate = _dateOnly(date);
  return '${cleanDate.year.toString().padLeft(4, '0')}-'
      '${cleanDate.month.toString().padLeft(2, '0')}-'
      '${cleanDate.day.toString().padLeft(2, '0')}';
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';
}

String _formatTime(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}

String _routineDescription(MedicineRoutine routine) {
  final buffer = StringBuffer()
    ..write(_formatTime(routine.time))
    ..write(' - ')
    ..write(routine.dose)
    ..write(' - ')
    ..write(routine.routineType.label);

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

int _sortByDoseTime(MedicineRoutine first, MedicineRoutine second) {
  final firstMinutes = first.time.hour * 60 + first.time.minute;
  final secondMinutes = second.time.hour * 60 + second.time.minute;
  return firstMinutes.compareTo(secondMinutes);
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
