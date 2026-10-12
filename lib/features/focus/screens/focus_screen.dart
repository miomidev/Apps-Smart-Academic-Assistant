import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../courses/models/course_model.dart';
import '../../courses/providers/courses_provider.dart';
import '../../schedules/models/schedule_model.dart';
import '../../schedules/providers/schedules_provider.dart';
import '../providers/focus_provider.dart';
import 'focus_active_screen.dart';
import 'focus_stats_screen.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  int _selectedDuration = 30; // default 30 minutes matching "30.00" in mockup
  ScheduleModel? _selectedTask;
  CourseModel? _selectedCourse;
  bool _blockNotifications = true; // ON by default in mockup
  bool _blockApps = false; // OFF by default in mockup
  String _selectedAmbient = 'None';

  final List<String> _ambientOptions = [
    'None',
    'Hujan Lembut',
    'White Noise',
    'Kafe Kampus',
  ];

  @override
  Widget build(BuildContext context) {
    final schedules = ref.watch(schedulesListProvider).value ?? [];
    final courses = ref.watch(coursesListProvider).value ?? [];
    final statsAsync = ref.watch(focusStatsProvider);
    final user = ref.watch(authStateProvider).value;

    // Pick a default task if not yet selected
    final tasks = schedules.where((s) => s.type == ScheduleType.task && !s.isCompleted).toList();
    final activeTask = _selectedTask ?? (tasks.isNotEmpty ? tasks.first : null);

    // Associated course
    final activeCourse = _selectedCourse ??
        (activeTask != null
            ? courses.firstWhere(
                (c) => c.id == activeTask.courseId,
                orElse: () => CourseModel(id: '', name: 'Kecerdasan Artifisial', colorHex: '#EF5350'),
              )
            : (courses.isNotEmpty ? courses.first : null));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // 1. Header: "Fokus" Title, Stats Button & Profile Avatar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Fokus',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF212121),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Statistik Fokus',
                        icon: const Icon(Icons.bar_chart_rounded, color: Color(0xFF42A5F5), size: 28),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const FocusStatsScreen()),
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => context.push('/settings'),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF42A5F5), width: 2),
                          ),
                          child: ClipOval(
                            child: CircleAvatar(
                              radius: 19,
                              backgroundColor: const Color(0xFFBBDEFB),
                              child: Text(
                                user?.name.isNotEmpty == true
                                    ? user!.name[0].toUpperCase()
                                    : 'M',
                                style: const TextStyle(
                                  color: Color(0xFF1565C0),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Large Circular Focus Timer (matching Catatan(Filled) (1).svg)
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF42A5F5),
                      width: 14,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Time display (e.g. 30.00)
                      Text(
                        '$_selectedDuration.00',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF212121),
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Play Capsule Button
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FocusActiveScreen(
                                durationMinutes: _selectedDuration,
                                course: activeCourse,
                                enablePinning: _blockApps,
                                ambientSound: _selectedAmbient,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 136,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFF42A5F5),
                            borderRadius: BorderRadius.circular(23),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF42A5F5).withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Settings Gear Button
                      GestureDetector(
                        onTap: () => _showSettingsModal(context),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF42A5F5),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.settings,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // 3. Target Fokus Container Box (matching Catatan(Filled) (1).svg)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFBBDEFB), width: 3.5),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Target Fokus + Info Icon
                    Row(
                      children: [
                        const Text(
                          'Target Fokus',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF212121),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Pilih tugas atau materi yang ingin Anda fokuskan pada sesi ini.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Color(0xFF90CAF9),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Target Task Card (Light Red/Pink Tint Card matching mockup)
                    if (activeTask != null)
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFCDD2), // Pastel red/pink tint from mockup
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEF5350), width: 1.0),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activeTask.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF212121),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Deskripsi Tugas',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF424242),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Meta: Besok 📅 23:59 🕒
                            Row(
                              children: [
                                Text(
                                  _formatTaskDueDate(activeTask.dueDate),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFD32F2F),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.calendar_month_rounded,
                                  size: 14,
                                  color: Color(0xFFD32F2F),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat('HH:mm').format(activeTask.dueDate),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFD32F2F),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 14,
                                  color: Color(0xFFD32F2F),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Course Badge Pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF5350),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                activeCourse?.name ?? 'Kecerdasan Artifisial',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                        ),
                        child: const Center(
                          child: Text(
                            'Belum ada target tugas dipilih',
                            style: TextStyle(color: Color(0xFF757575), fontSize: 13),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),

                    // "Tambah Target" Blue Button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => _showTaskPicker(context, tasks, courses),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF42A5F5),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Tambah Target',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.add_circle, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. Distraction Blockers Boxes (matching Catatan(Filled) (1).svg)
              // Box A: Blokir Notifikasi
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBBDEFB), width: 3.5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Text(
                      'Blokir Notifikasi',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Color(0xFF90CAF9),
                    ),
                    const Spacer(),
                    _buildCustomSwitch(
                      value: _blockNotifications,
                      onChanged: (val) => setState(() => _blockNotifications = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Box B: Blokir Aplikasi
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBBDEFB), width: 3.5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Text(
                      'Blokir Aplikasi',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Color(0xFF90CAF9),
                    ),
                    const Spacer(),
                    _buildCustomSwitch(
                      value: _blockApps,
                      onChanged: (val) => setState(() => _blockApps = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 5. Mini stats preview link
              statsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (stats) {
                  return InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const FocusStatsScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.insights, size: 20, color: Color(0xFF1E88E5)),
                          const SizedBox(width: 10),
                          Text(
                            'Total minggu ini: ${stats.totalMinutes} menit fokus',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0D47A1),
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'Lihat Grafik',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1E88E5),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 18, color: Color(0xFF1E88E5)),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 85),
            ],
          ),
        ),
      ),
    );
  }

  // Custom Toggle Switch matching Catatan(Filled) (1).svg with check or cross
  Widget _buildCustomSwitch({required bool value, required ValueChanged<bool> onChanged}) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 54,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: value ? const Color(0xFF42A5F5) : const Color(0xFFE0E0E0),
        ),
        child: Align(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Icon(
              value ? Icons.check_rounded : Icons.close_rounded,
              size: 15,
              color: value ? const Color(0xFF42A5F5) : const Color(0xFF9E9E9E),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTaskDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (dueDay == today) {
      return 'Hari ini';
    } else if (dueDay == tomorrow) {
      return 'Besok';
    } else {
      return DateFormat('d MMM', 'id_ID').format(dueDate);
    }
  }

  // Duration & Ambient Sound Settings Modal
  void _showSettingsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pengaturan Sesi Fokus',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pilih Durasi:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [15, 25, 30, 45, 60].map((mins) {
                    final isSel = _selectedDuration == mins;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setModalState(() => _selectedDuration = mins);
                          setState(() => _selectedDuration = mins);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFF42A5F5) : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSel ? const Color(0xFF42A5F5) : const Color(0xFFE0E0E0),
                            ),
                          ),
                          child: Text(
                            '$mins mnt',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSel ? Colors.white : const Color(0xFF212121),
                              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Suara Latar (Ambient Sound):',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedAmbient,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  items: _ambientOptions.map((opt) {
                    return DropdownMenuItem(value: opt, child: Text(opt));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() => _selectedAmbient = val);
                      setState(() => _selectedAmbient = val);
                    }
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF42A5F5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Simpan Pengaturan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Task & Course Picker BottomSheet
  void _showTaskPicker(BuildContext context, List<ScheduleModel> tasks, List<CourseModel> courses) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pilih Target Tugas untuk Fokus',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (tasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('Tidak ada tugas aktif tersedia.'),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: tasks.length,
                    separatorBuilder: (_, _) => const Divider(height: 8),
                    itemBuilder: (ctx, i) {
                      final t = tasks[i];
                      final c = courses.firstWhere(
                        (item) => item.id == t.courseId,
                        orElse: () => CourseModel(id: '', name: 'Mata Kuliah', colorHex: '#EF5350'),
                      );
                      return ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.fromHex(c.colorCode).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.assignment, color: AppColors.fromHex(c.colorCode), size: 20),
                        ),
                        title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(
                          '${c.name} • ${_formatTaskDueDate(t.dueDate)}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
                        ),
                        trailing: const Icon(Icons.check_circle_outline, color: Color(0xFF42A5F5)),
                        onTap: () {
                          setState(() {
                            _selectedTask = t;
                            _selectedCourse = c;
                          });
                          Navigator.of(ctx).pop();
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
