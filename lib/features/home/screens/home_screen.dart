import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/auth_provider.dart';
import '../../courses/screens/courses_screen.dart';
import '../../focus/providers/focus_provider.dart';
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

    final studentName = user?.name ?? 'Mahasiswa';
    final universityName = user?.university ?? 'Universitas Siliwangi';
    final weeklyMinutes = focusStats?.totalMinutes ?? 0;

    final todayFormatted = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF42A5F5),
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
                  // User Avatar / Initial
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFBBDEFB),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        studentName.isNotEmpty ? studentName[0].toUpperCase() : 'M',
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
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
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF212121),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          universityName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF757575),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Weekly Focus Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: Color(0xFF1E88E5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$weeklyMinutes mnt',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E88E5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Settings Button in Soft Blue Circle (#BBDEFB)
                  GestureDetector(
                    onTap: () => context.push('/settings'),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFBBDEFB),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.settings_outlined,
                          color: Color(0xFF212121),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Hero Academic Summary Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF42A5F5).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            todayFormatted,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.school_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Asisten Akademik Pintar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Kelola jadwal, rekaman kuliah, dan sesi belajar harianmu dengan mudah.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Quick Stats Mini Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildHeroStatItem(
                            count: '${todaysSchedules.length}',
                            label: 'Kelas Hari Ini',
                            icon: Icons.calendar_today_rounded,
                          ),
                          Container(width: 1, height: 26, color: Colors.white24),
                          _buildHeroStatItem(
                            count: '${upcomingTasks.length}',
                            label: 'Tugas Menunggu',
                            icon: Icons.assignment_outlined,
                          ),
                          Container(width: 1, height: 26, color: Colors.white24),
                          _buildHeroStatItem(
                            count: '$weeklyMinutes',
                            label: 'Mnt Fokus',
                            icon: Icons.timer_outlined,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Section Title: Aksi Cepat
              const Text(
                'Aksi Cepat',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF212121),
                ),
              ),
              const SizedBox(height: 12),

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
                  onNavigateTab?.call(3);
                },
                onUploadRps: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RpsUploadScreen(),
                    ),
                  );
                },
                onViewCourses: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CoursesScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 22),

              // Today's Class Schedule Card
              TodayScheduleCard(
                todaysSchedules: todaysSchedules,
                onViewAll: () => onNavigateTab?.call(2), // Navigate to Tugas/Jadwal
              ),
              const SizedBox(height: 18),

              // Upcoming Tasks Card
              UpcomingTasksCard(
                upcomingTasks: upcomingTasks,
                onToggleComplete: (id) {
                  ref.read(schedulesListProvider.notifier).toggleComplete(id);
                },
                onViewAll: () => onNavigateTab?.call(2),
              ),
              const SizedBox(height: 18),

              // Academic Assistant Tip Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE0F2FE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF0284C7),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tips Cerdas Asisten Akademik',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Unggah RPS untuk otomatisasi jadwal 16 pertemuan, lalu rekam saat kuliah agar catatan otomatis ter-tag!',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                              height: 1.4,
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

  Widget _buildHeroStatItem({
    required String count,
    required String label,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              count,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
