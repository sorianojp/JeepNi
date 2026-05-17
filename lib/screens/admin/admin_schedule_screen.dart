import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_routes.dart';
import '../../core/app_ui.dart';
import '../../models/ejeep_schedule.dart';
import '../../services/ejeep_schedule_service.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/app_text_field.dart';

const Color _adminThemeColor = Color(0xFF1A237E);
const Color _driverThemeColor = Color(0xFF05056A);
const List<String> _dayRangeOptions = [
  'Monday to Friday',
  'Monday to Saturday',
  'Saturday to Sunday',
  'Sunday only',
  'Monday only',
  'Tuesday only',
  'Wednesday only',
  'Thursday only',
  'Friday only',
  'Saturday only',
];

class AdminScheduleScreen extends StatefulWidget {
  const AdminScheduleScreen({super.key});

  @override
  State<AdminScheduleScreen> createState() => _AdminScheduleScreenState();
}

class _AdminScheduleScreenState extends State<AdminScheduleScreen> {
  final TextEditingController _ejeepNameController = TextEditingController();
  final TextEditingController _routeController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String? _selectedDayRange;
  bool _isSaving = false;
  String? _message;

  @override
  void dispose() {
    _ejeepNameController.dispose();
    _routeController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (selectedTime == null || !mounted) return;

    setState(() {
      controller.text = selectedTime.format(context);
    });
  }

  Future<void> _addSchedule(EJeepScheduleService scheduleService) async {
    final ejeepName = _ejeepNameController.text.trim();
    final route = _routeController.text.trim();
    final dayRange = _selectedDayRange?.trim() ?? '';
    final startTime = _startTimeController.text.trim();
    final endTime = _endTimeController.text.trim();
    final notes = _notesController.text.trim();

    if (ejeepName.isEmpty ||
        route.isEmpty ||
        dayRange.isEmpty ||
        startTime.isEmpty ||
        endTime.isEmpty) {
      setState(() {
        _message =
            'EJeep name, route, day range, start time, and end time are required.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _message = null;
    });

    try {
      await scheduleService.addSchedule(
        ejeepName: ejeepName,
        route: route,
        dayRange: dayRange,
        startTime: startTime,
        endTime: endTime,
        notes: notes,
      );

      if (!mounted) return;
      _ejeepNameController.clear();
      _routeController.clear();
      _startTimeController.clear();
      _endTimeController.clear();
      _notesController.clear();
      setState(() {
        _selectedDayRange = null;
        _message = 'Schedule added.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Could not add schedule. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduleService = context.watch<EJeepScheduleService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('EJeep Schedule'),
        backgroundColor: _adminThemeColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.admin),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: _adminThemeColor.withValues(alpha: 0.16)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.event_note, color: _adminThemeColor),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Add Schedule',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _ejeepNameController,
                    label: 'EJeep name',
                    hint: 'EJeep 01',
                    icon: Icons.directions_bus,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _routeController,
                    label: 'Route',
                    hint: 'Campus to Downtown',
                    icon: Icons.route,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedDayRange,
                    decoration: _scheduleInputDecoration(
                      label: 'Day range',
                      icon: Icons.calendar_today,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    items: _dayRangeOptions
                        .map(
                          (range) => DropdownMenuItem<String>(
                            value: range,
                            child: Text(range),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedDayRange = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeSelectField(
                          label: 'Start time',
                          value: _startTimeController.text,
                          onTap: () => _pickTime(_startTimeController),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TimeSelectField(
                          label: 'End time',
                          value: _endTimeController.text,
                          onTap: () => _pickTime(_endTimeController),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _notesController,
                    label: 'Notes',
                    hint: 'Optional',
                    icon: Icons.notes,
                  ),
                  const SizedBox(height: 12),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _message!,
                        style: TextStyle(
                          color: _message == 'Schedule added.'
                              ? _driverThemeColor
                              : Colors.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  AppPrimaryButton(
                    label: _isSaving ? 'Saving...' : 'Add schedule',
                    onPressed: () => _addSchedule(scheduleService),
                    isLoading: _isSaving,
                    icon: Icons.add,
                    backgroundColor: _adminThemeColor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Schedules',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (scheduleService.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (scheduleService.errorMessage != null)
            _ScheduleMessage(message: scheduleService.errorMessage!)
          else if (scheduleService.schedules.isEmpty)
            const _ScheduleMessage(message: 'No schedules yet.')
          else
            ...scheduleService.schedules.map(
              (schedule) => _AdminScheduleTile(
                schedule: schedule,
                onActiveChanged: (isActive) =>
                    scheduleService.setScheduleActive(schedule.id, isActive),
                onDelete: () => scheduleService.deleteSchedule(schedule.id),
              ),
            ),
        ],
      ),
    );
  }
}

InputDecoration _scheduleInputDecoration({
  required String label,
  required IconData icon,
}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: AppUi.formSurface,
    contentPadding: AppUi.fieldContentPadding,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppUi.fieldRadius),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppUi.fieldRadius),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppUi.fieldRadius),
      borderSide: const BorderSide(color: _adminThemeColor, width: 1.4),
    ),
  );
}

class _TimeSelectField extends StatelessWidget {
  const _TimeSelectField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppUi.fieldRadius),
        onTap: onTap,
        child: InputDecorator(
          decoration: _scheduleInputDecoration(
            label: label,
            icon: Icons.schedule,
          ),
          child: Text(
            value.isEmpty ? 'Select' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: value.isEmpty ? Colors.grey.shade700 : AppUi.textPrimary,
              fontWeight: value.isEmpty ? FontWeight.w500 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminScheduleTile extends StatelessWidget {
  const _AdminScheduleTile({
    required this.schedule,
    required this.onActiveChanged,
    required this.onDelete,
  });

  final EJeepSchedule schedule;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        leading: CircleAvatar(
          backgroundColor: schedule.isActive
              ? _driverThemeColor.withValues(alpha: 0.1)
              : Colors.grey.shade200,
          foregroundColor: schedule.isActive ? _driverThemeColor : Colors.grey,
          child: const Icon(Icons.directions_bus),
        ),
        title: Text(
          '${schedule.ejeepName} • ${schedule.timeRangeLabel}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          [
            schedule.route,
            schedule.dayRange,
            if (schedule.notes.isNotEmpty) schedule.notes,
          ].join(' • '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: schedule.isActive,
              activeThumbColor: _driverThemeColor,
              onChanged: onActiveChanged,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Colors.red,
              tooltip: 'Delete schedule',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleMessage extends StatelessWidget {
  const _ScheduleMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700),
        ),
      ),
    );
  }
}
