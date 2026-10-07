import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../courses/screens/course_form_screen.dart';
import '../../focus/providers/focus_provider.dart';
import '../../focus/screens/focus_active_screen.dart';
import '../../notes/screens/voice_capture_screen.dart';
import '../../rps/screens/rps_upload_screen.dart';
import '../../schedules/providers/schedules_provider.dart';
import '../widgets/quick_actions_row.dart';
import '../widgets/today_schedule_card.dart';
import '../widgets/upcoming_tasks_card.dart';

class HomeScreen extends ConsumerWidget {
  final void Function(int tabIndex)? onNavigateTab;

  const HomeScreen({super.key, this.onNavigateTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final todaysSchedules = ref.watch(todaysSchedulesProvider);
    final upcomingTasks = ref.watch(upcomingTasksProvider);
    final focusStats = ref.watch(focusStatsProvider).value;

    final studentName = user?.name ?? 'Mahasiswa SAA';
    final universityName = user?.university ?? 'Universitas Siliwangi';
    final weeklyMinutes = focusStats?.totalMinutes ?? 0;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.read(schedulesListProvider.notifier).loadSchedules(),
              ref.refresh(focusStatsProvider.future),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Top Profile & Academic Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      studentName.isNotEmpty ? studentName[0].toUpperCase() : 'M',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Halo, $studentName 👋',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          universityName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Weekly Focus Minutes Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 15,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$weeklyMinutes mnt',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Quick Actions
              QuickActionsRow(
                onRecordVoice: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VoiceCaptureScreen(),
                    ),
                  );
                },
                onStartFocus: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FocusActiveScreen(durationMinutes: 25),
                    ),
                  );
                },
                onUploadRps: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RpsUploadScreen(),
                    ),
                  );
                },
                onAddCourse: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CourseFormScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Today's Class Schedule Card
              TodayScheduleCard(
                todaysSchedules: todaysSchedules,
                onViewAll: () => onNavigateTab?.call(3), // Navigate to Schedules Tab
              ),
              const SizedBox(height: 16),

              // Upcoming Tasks Card
              UpcomingTasksCard(
                upcomingTasks: upcomingTasks,
                onToggleComplete: (id) {
                  ref.read(schedulesListProvider.notifier).toggleComplete(id);
                },
                onViewAll: () => onNavigateTab?.call(3),
              ),
              const SizedBox(height: 16),

              // Academic Assistant Tip Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.85),
                      AppColors.primaryDark,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.tips_and_updates_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tips Smart Auto-Tag',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Rekam saat jam kuliah berlangsung untuk akurasi auto-tag mata kuliah tertinggi!',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
