import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../models/course_model.dart';
import '../providers/courses_provider.dart';
import 'course_detail_screen.dart';
import 'course_form_screen.dart';

class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(coursesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mata Kuliah'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.read(coursesListProvider.notifier).loadCourses(),
          ),
        ],
      ),
      body: coursesAsync.when(
        data: (courses) {
          if (courses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.school_outlined,
                        size: 56,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Belum Ada Mata Kuliah',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tambahkan mata kuliah untuk menghubungkan transkripsi suara, jadwal, dan RPS otomatis.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CourseFormScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Mata Kuliah'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(coursesListProvider.notifier).loadCourses(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: courses.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final course = courses[index];
                return _CourseCard(course: course);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Gagal memuat mata kuliah',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      ref.read(coursesListProvider.notifier).loadCourses(),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_courses',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CourseFormScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah MK'),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final CourseModel course;

  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.fromHex(course.colorCode);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CourseDetailScreen(courseId: course.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colored Banner Top
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          course.code ?? 'MK',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    course.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (course.lecturer != null && course.lecturer!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Dosen: ${course.lecturer}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Slots Badges
                  if (course.slots.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: course.slots.map((s) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.access_time_rounded,
                                  size: 13, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                '${s.dayName} ${s.startTime}-${s.endTime}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (s.room != null && s.room!.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '• ${s.room}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
