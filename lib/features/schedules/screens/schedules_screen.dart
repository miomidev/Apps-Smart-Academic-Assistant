import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../models/schedule_model.dart';
import '../providers/schedules_provider.dart';
import 'schedule_form_screen.dart';

class SchedulesScreen extends ConsumerStatefulWidget {
  const SchedulesScreen({super.key});

  @override
  ConsumerState<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends ConsumerState<SchedulesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schedulesAsync = ref.watch(schedulesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal & Tugas'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Semua'),
            Tab(text: 'Kuliah'),
            Tab(text: 'Tugas & Ujian'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.read(schedulesListProvider.notifier).loadSchedules(),
          ),
        ],
      ),
      body: schedulesAsync.when(
        data: (schedules) {
          final sorted = List<ScheduleModel>.from(schedules)
            ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

          final classOnly = sorted
              .where((s) => s.type == ScheduleType.classType)
              .toList();
          final taskAndExam = sorted
              .where((s) =>
                  s.type == ScheduleType.task || s.type == ScheduleType.exam)
              .toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _ScheduleListView(schedules: sorted),
              _ScheduleListView(schedules: classOnly),
              _ScheduleListView(schedules: taskAndExam),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Gagal memuat jadwal: $err'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.read(schedulesListProvider.notifier).loadSchedules(),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_schedules',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ScheduleFormScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ScheduleListView extends ConsumerWidget {
  final List<ScheduleModel> schedules;

  const _ScheduleListView({required this.schedules});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (schedules.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.event_available_rounded,
                size: 56,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 16),
              const Text(
                'Tidak Ada Jadwal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Gunakan tombol + untuk menambah jadwal manual atau ekstrak dari PDF RPS.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final dateFormat = DateFormat('EEEE, d MMM yyyy • HH:mm', 'id_ID');

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(schedulesListProvider.notifier).loadSchedules(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: schedules.length,
        separatorBuilder: (ctx, i) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = schedules[index];
          final courseColor = item.course != null
              ? AppColors.fromHex(item.course!.colorCode)
              : AppColors.primary;

          IconData typeIcon;
          Color typeBadgeColor;
          String typeLabel;

          switch (item.type) {
            case ScheduleType.classType:
              typeIcon = Icons.menu_book_rounded;
              typeBadgeColor = AppColors.primary;
              typeLabel = item.meetingNumber != null
                  ? 'Pertemuan ${item.meetingNumber}'
                  : 'Kuliah';
              break;
            case ScheduleType.task:
              typeIcon = Icons.assignment_rounded;
              typeBadgeColor = AppColors.warning;
              typeLabel = 'Tugas';
              break;
            case ScheduleType.exam:
              typeIcon = Icons.quiz_rounded;
              typeBadgeColor = AppColors.error;
              typeLabel = 'Ujian';
              break;
          }

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: item.isCompleted
                    ? AppColors.border
                    : courseColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Completed Checkbox
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    item.isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: item.isCompleted
                        ? AppColors.success
                        : AppColors.textMuted,
                    size: 24,
                  ),
                  onPressed: () {
                    ref
                        .read(schedulesListProvider.notifier)
                        .toggleComplete(item.id);
                  },
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeBadgeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(typeIcon,
                                    size: 11, color: typeBadgeColor),
                                const SizedBox(width: 4),
                                Text(
                                  typeLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: typeBadgeColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (item.course != null) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                item.course!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: courseColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          decoration: item.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: item.isCompleted
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 13, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            dateFormat.format(item.dueDate.toLocal()),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Delete Button
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: AppColors.textMuted),
                  onPressed: () {
                    ref
                        .read(schedulesListProvider.notifier)
                        .deleteSchedule(item.id);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
