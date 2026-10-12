import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../courses/models/course_model.dart';
import '../../courses/providers/courses_provider.dart';
import '../models/schedule_model.dart';
import '../providers/schedules_provider.dart';
import 'schedule_form_screen.dart';

enum TaskFilterPeriod { today, tomorrow, upcoming, all, classSchedule }

class SchedulesScreen extends ConsumerStatefulWidget {
  const SchedulesScreen({super.key});

  @override
  ConsumerState<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends ConsumerState<SchedulesScreen> {
  TaskFilterPeriod _selectedPeriod = TaskFilterPeriod.today;
  String? _selectedCourseId;

  String _getSectionTitle() {
    switch (_selectedPeriod) {
      case TaskFilterPeriod.today:
        return 'Tugas Hari ini';
      case TaskFilterPeriod.tomorrow:
        return 'Tugas Besok';
      case TaskFilterPeriod.upcoming:
        return 'Tugas Mendatang';
      case TaskFilterPeriod.all:
        return 'Semua Tugas';
      case TaskFilterPeriod.classSchedule:
        return 'Jadwal Kuliah';
    }
  }

  String _formatDueDate(DateTime dueDate) {
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

  @override
  Widget build(BuildContext context) {
    final schedulesAsync = ref.watch(schedulesListProvider);
    final courses = ref.watch(coursesListProvider).value ?? [];
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // 1. Top Header Row: "Tugas" Title & User Profile Avatar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Tugas',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF212121),
                      letterSpacing: -0.5,
                    ),
                  ),
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
              const SizedBox(height: 12),

              // 2. Filter Pills Bar (Capsule Container matching Tugas.svg)
              Container(
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF757575), width: 1.0),
                  color: const Color(0xFFF5F5F5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterPill(
                        label: 'Hari ini',
                        period: TaskFilterPeriod.today,
                      ),
                      const SizedBox(width: 6),
                      _buildFilterPill(
                        label: 'Besok',
                        period: TaskFilterPeriod.tomorrow,
                      ),
                      const SizedBox(width: 6),
                      _buildFilterPill(
                        label: 'Mendatang',
                        period: TaskFilterPeriod.upcoming,
                      ),
                      const SizedBox(width: 6),
                      _buildFilterPill(
                        label: 'Semua',
                        period: TaskFilterPeriod.all,
                      ),
                      const SizedBox(width: 6),
                      _buildFilterPill(
                        label: 'Kuliah',
                        period: TaskFilterPeriod.classSchedule,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 3. Optional Course Horizontal Filter Chips
              if (courses.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Semua Matkul'),
                        selected: _selectedCourseId == null,
                        selectedColor: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: _selectedCourseId == null
                              ? const Color(0xFF1E88E5)
                              : const Color(0xFF757575),
                          fontWeight: _selectedCourseId == null ? FontWeight.bold : FontWeight.normal,
                          fontSize: 11.5,
                        ),
                        side: BorderSide(
                          color: _selectedCourseId == null
                              ? const Color(0xFF42A5F5)
                              : const Color(0xFFE0E0E0),
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedCourseId = null);
                        },
                      ),
                      const SizedBox(width: 8),
                      ...courses.map((c) {
                        final isSelected = _selectedCourseId == c.id;
                        final cColor = AppColors.fromHex(c.colorCode);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            avatar: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: cColor, shape: BoxShape.circle),
                            ),
                            label: Text(c.name),
                            selected: isSelected,
                            selectedColor: cColor.withValues(alpha: 0.18),
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: isSelected ? cColor : const Color(0xFF757575),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 11.5,
                            ),
                            side: BorderSide(color: isSelected ? cColor : const Color(0xFFE0E0E0)),
                            onSelected: (val) {
                              setState(() => _selectedCourseId = val ? c.id : null);
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              // 4. Main Tasks Container Box (matching Tugas.svg blue outlined card)
              Expanded(
                child: schedulesAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
                  ),
                  error: (err, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Gagal memuat tugas: $err', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => ref.read(schedulesListProvider.notifier).loadSchedules(),
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                  data: (schedules) {
                    return _buildTasksContainer(schedules, courses);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 6, right: 2),
        child: SizedBox(
          width: 58,
          height: 58,
          child: FloatingActionButton(
            heroTag: 'fab_tasks',
            backgroundColor: const Color(0xFF42A5F5),
            elevation: 4,
            shape: const CircleBorder(),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ScheduleFormScreen()),
              );
            },
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 34),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPill({required String label, required TaskFilterPeriod period}) {
    final isSelected = _selectedPeriod == period;

    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = period),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF42A5F5) : const Color(0xFFBDBDBD),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTasksContainer(List<ScheduleModel> schedules, List<CourseModel> courses) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    var filtered = List<ScheduleModel>.from(schedules);

    // Filter by Course if selected
    if (_selectedCourseId != null) {
      filtered = filtered.where((s) => s.courseId == _selectedCourseId).toList();
    }

    // Filter by Period
    switch (_selectedPeriod) {
      case TaskFilterPeriod.today:
        filtered = filtered.where((s) {
          final d = DateTime(s.dueDate.year, s.dueDate.month, s.dueDate.day);
          return s.type != ScheduleType.classType && d == today;
        }).toList();
        break;
      case TaskFilterPeriod.tomorrow:
        filtered = filtered.where((s) {
          final d = DateTime(s.dueDate.year, s.dueDate.month, s.dueDate.day);
          return s.type != ScheduleType.classType && d == tomorrow;
        }).toList();
        break;
      case TaskFilterPeriod.upcoming:
        filtered = filtered.where((s) {
          final d = DateTime(s.dueDate.year, s.dueDate.month, s.dueDate.day);
          return s.type != ScheduleType.classType && d.isAfter(today);
        }).toList();
        break;
      case TaskFilterPeriod.all:
        filtered = filtered.where((s) => s.type != ScheduleType.classType).toList();
        break;
      case TaskFilterPeriod.classSchedule:
        filtered = filtered.where((s) => s.type == ScheduleType.classType).toList();
        break;
    }

    // Sort: incomplete first, then by dueDate
    filtered.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      return a.dueDate.compareTo(b.dueDate);
    });

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          ref.read(schedulesListProvider.notifier).loadSchedules(),
          ref.read(coursesListProvider.notifier).loadCourses(),
        ]);
      },
      color: const Color(0xFF42A5F5),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 85),
        child: Container(
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
              // Section Title inside blue outline box (matching Tugas.svg)
              Text(
                _getSectionTitle(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF212121),
                ),
              ),
              const SizedBox(height: 14),

              if (filtered.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Column(
                    children: [
                      Icon(
                        _selectedPeriod == TaskFilterPeriod.classSchedule
                            ? Icons.school_outlined
                            : Icons.check_circle_outline_rounded,
                        size: 48,
                        color: const Color(0xFF90CAF9),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedPeriod == TaskFilterPeriod.classSchedule
                            ? 'Tidak ada jadwal kuliah'
                            : 'Tidak ada tugas untuk periode ini',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF757575),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final course = courses.firstWhere(
                      (c) => c.id == item.courseId,
                      orElse: () => CourseModel(
                        id: '',
                        name: 'Mata Kuliah',
                        colorHex: '#42A5F5',
                      ),
                    );
                    return _buildTaskCard(item, course);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Individual Task Card matching Tugas.svg
  Widget _buildTaskCard(ScheduleModel item, CourseModel course) {
    final courseColor = AppColors.fromHex(course.colorCode);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showTaskOptions(item),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFCFE8FF), // Pastel blue card background matching Tugas.svg
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox Circle on the left (matching Tugas.svg)
            GestureDetector(
              onTap: () async {
                final success = await ref
                    .read(schedulesListProvider.notifier)
                    .toggleComplete(item.id);
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        item.isCompleted
                            ? 'Tugas ditandai belum selesai'
                            : 'Selamat! Tugas berhasil diselesaikan 🎉',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.isCompleted ? const Color(0xFF1E88E5) : Colors.transparent,
                  border: Border.all(
                    color: const Color(0xFF1E88E5),
                    width: 2.2,
                  ),
                ),
                child: item.isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 12),

            // Task Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Task Title
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: item.isCompleted
                          ? const Color(0xFF757575)
                          : const Color(0xFF212121),
                      decoration: item.isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Subtitle / Task Description matching Tugas.svg ("Deskripsi Tugas")
                  Text(
                    item.type == ScheduleType.classType
                        ? 'Kuliah Pertemuan ${item.meetingNumber ?? '-'}'
                        : (item.meetingNumber != null
                            ? 'Praktikum / Pertemuan ${item.meetingNumber}'
                            : 'Deskripsi Tugas'),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF424242),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Metadata Row: Due date label, calendar icon, time, clock icon
                  Row(
                    children: [
                      Text(
                        _formatDueDate(item.dueDate),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E88E5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 14,
                        color: Color(0xFF1E88E5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('HH:mm').format(item.dueDate),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E88E5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: Color(0xFF1E88E5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Course Badge Pill (matching Tugas.svg "Kecerdasan Artifisial")
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: courseColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      course.name,
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
            ),
          ],
        ),
      ),
    );
  }

  void _showTaskOptions(ScheduleModel item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Tenggat: ${DateFormat('EEEE, d MMMM yyyy HH:mm', 'id_ID').format(item.dueDate)}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF757575)),
              ),
              const Divider(height: 24),
              ListTile(
                leading: Icon(
                  item.isCompleted ? Icons.radio_button_unchecked : Icons.check_circle_outline,
                  color: const Color(0xFF1E88E5),
                ),
                title: Text(
                  item.isCompleted ? 'Tandai Belum Selesai' : 'Tandai Selesai',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  ref.read(schedulesListProvider.notifier).toggleComplete(item.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Hapus Tugas', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Hapus Tugas'),
                      content: Text('Yakin ingin menghapus "${item.title}"?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Batal')),
                        ElevatedButton(
                          onPressed: () => Navigator.of(c).pop(true),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                          child: const Text('Hapus', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref.read(schedulesListProvider.notifier).deleteSchedule(item.id);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
