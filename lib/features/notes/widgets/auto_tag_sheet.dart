import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../courses/models/course_model.dart';
import '../../courses/providers/courses_provider.dart';
import '../models/auto_tag_result.dart';

class AutoTagSheet extends ConsumerStatefulWidget {
  final AutoTagResult? autoTagResult;
  final String? initialCourseId;
  final ValueChanged<String?> onCourseSelected;

  const AutoTagSheet({
    super.key,
    required this.autoTagResult,
    this.initialCourseId,
    required this.onCourseSelected,
  });

  static Future<String?> show(
    BuildContext context, {
    required AutoTagResult? autoTagResult,
    String? initialCourseId,
  }) {
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AutoTagSheet(
        autoTagResult: autoTagResult,
        initialCourseId: initialCourseId,
        onCourseSelected: (courseId) => Navigator.of(ctx).pop(courseId),
      ),
    );
  }

  @override
  ConsumerState<AutoTagSheet> createState() => _AutoTagSheetState();
}

class _AutoTagSheetState extends ConsumerState<AutoTagSheet> {
  String? _selectedCourseId;
  bool _showAllCourses = false;

  @override
  void initState() {
    super.initState();
    _selectedCourseId =
        widget.initialCourseId ?? widget.autoTagResult?.suggestedCourseId;
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesListProvider);
    final courses = coursesAsync.value ?? [];
    final result = widget.autoTagResult;

    final double score = result?.confidenceScore ?? 0.0;
    final bool isHighConfidence = score >= 0.60 && result?.suggestedCourseId != null;
    final bool isMediumConfidence = score >= 0.30 && score < 0.60;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.neutral300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Auto-Tagging Mata Kuliah',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'AI menganalisis transkrip dan jadwal Anda',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // High Confidence (> 60%)
          if (isHighConfidence && !_showAllCourses) ...[
            _buildHighConfidenceCard(courses, result!),
          ]
          // Medium Confidence (30% - 59%)
          else if (isMediumConfidence && !_showAllCourses) ...[
            _buildMediumConfidenceCandidates(courses, result!),
          ]
          // Low Confidence or manual pick
          else ...[
            _buildManualCourseList(courses),
          ],

          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => widget.onCourseSelected(null),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Tanpa Tag'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => widget.onCourseSelected(_selectedCourseId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Konfirmasi & Simpan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHighConfidenceCard(List<CourseModel> courses, AutoTagResult result) {
    final course = courses.firstWhere(
      (c) => c.id == result.suggestedCourseId,
      orElse: () => CourseModel(
        id: result.suggestedCourseId ?? '',
        name: result.suggestedCourseName ?? 'Mata Kuliah Ditemukan',
        colorHex: '#4F46E5',
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.fromHex(course.colorHex),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  course.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(result.confidenceScore * 100).toInt()}% Cocok',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          if (result.isTimeMatched) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time_filled, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'Sesuai dengan jadwal kelas hari ini',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
          if (result.matchedKeywords.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: result.matchedKeywords.map((kw) {
                return Chip(
                  label: Text(kw, style: const TextStyle(fontSize: 10)),
                  backgroundColor: AppColors.neutral200,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => setState(() => _showAllCourses = true),
            icon: const Icon(Icons.edit, size: 14),
            label: const Text('Bukan mata kuliah ini? Pilih lain'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediumConfidenceCandidates(
    List<CourseModel> courses,
    AutoTagResult result,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Beberapa kemungkinan mata kuliah:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        ...result.candidates.take(3).map((candidate) {
          final isSelected = _selectedCourseId == candidate.courseId;
          final course = courses.firstWhere(
            (c) => c.id == candidate.courseId,
            orElse: () => CourseModel(
              id: candidate.courseId,
              name: candidate.courseName,
              colorHex: '#4F46E5',
            ),
          );

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedCourseId = candidate.courseId),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.neutral200,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.fromHex(course.colorHex),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        candidate.courseName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${(candidate.confidence * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        TextButton(
          onPressed: () => setState(() => _showAllCourses = true),
          child: const Text('Tampilkan semua mata kuliah'),
        ),
      ],
    );
  }

  Widget _buildManualCourseList(List<CourseModel> courses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pilih Mata Kuliah:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: courses.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 6),
            itemBuilder: (ctx, i) {
              final c = courses[i];
              final isSelected = _selectedCourseId == c.id;
              return InkWell(
                onTap: () => setState(() => _selectedCourseId = c.id),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          isSelected ? AppColors.primary : AppColors.neutral200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.fromHex(c.colorHex),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          c.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check, size: 18, color: AppColors.primary),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
