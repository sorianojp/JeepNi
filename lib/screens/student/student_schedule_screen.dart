import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_routes.dart';
import '../../models/ejeep_schedule.dart';
import '../../services/ejeep_schedule_service.dart';

const Color _studentThemeColor = Color(0xFF212121);
const Color _driverThemeColor = Color(0xFF05056A);

class StudentScheduleScreen extends StatelessWidget {
  const StudentScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheduleService = context.watch<EJeepScheduleService>();
    final activeSchedules = scheduleService.schedules
        .where((schedule) => schedule.isActive)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('EJeep Schedule'),
        backgroundColor: _studentThemeColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.student),
        ),
      ),
      body: Builder(
        builder: (context) {
          if (scheduleService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (scheduleService.errorMessage != null) {
            return _ScheduleMessage(message: scheduleService.errorMessage!);
          }

          if (activeSchedules.isEmpty) {
            return const _ScheduleMessage(
              message: 'No eJeep schedules posted yet.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: activeSchedules.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _StudentScheduleCard(schedule: activeSchedules[index]);
            },
          );
        },
      ),
    );
  }
}

class _StudentScheduleCard extends StatelessWidget {
  const _StudentScheduleCard({required this.schedule});

  final EJeepSchedule schedule;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _driverThemeColor.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: _driverThemeColor.withValues(alpha: 0.1),
              foregroundColor: _driverThemeColor,
              child: const Icon(Icons.directions_bus),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    schedule.ejeepName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    schedule.route,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade800),
                  ),
                  if (schedule.notes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      schedule.notes,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _driverThemeColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _driverThemeColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      schedule.timeRangeLabel,
                      style: const TextStyle(
                        color: _driverThemeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  schedule.dayRange,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700),
        ),
      ),
    );
  }
}
