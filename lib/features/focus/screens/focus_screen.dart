import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../courses/models/course_model.dart';
import '../../courses/providers/courses_provider.dart';
import '../providers/focus_provider.dart';
import 'focus_active_screen.dart';
import 'focus_stats_screen.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  int _selectedDuration = 25; // 25, 45, 60, 90 or custom
  String? _selectedCourseId;
  bool _enablePinning = true;
  String _selectedAmbient = 'None';

  final List<String> _ambientOptions = [
    'None',
    'Hujan Lembut',
    'White Noise',
    'Kafe Kampus',
  ];

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(coursesListProvider).value ?? [];
    final statsAsync = ref.watch(focusStatsProvider);

    final selectedCourse = courses.firstWhere(
      (c) => c.id == _selectedCourseId,
      orElse: () => CourseModel(
        id: '',
        name: 'Fokus Bebas (Tanpa Matkul)',
        colorHex: '#4F46E5',
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mode Deep Focus'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Statistik & Analitik',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const FocusStatsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tingkatkan Produktivitas',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Blokir Distraksi & Fokus Belajar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Kunci layar ke aplikasi SAA untuk mencegah membuka medsos atau game.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.timer_outlined,
                        color: Colors.white, size: 32),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Duration Presets
            const Text(
              'Durasi Fokus',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildPresetButton(25, '25 Menit\nPomodoro'),
                const SizedBox(width: 8),
                _buildPresetButton(45, '45 Menit\nDeep Work'),
                const SizedBox(width: 8),
                _buildPresetButton(60, '60 Menit\nIntensif'),
                const SizedBox(width: 8),
                _buildPresetButton(90, '90 Menit\nMaraton'),
              ],
            ),

            const SizedBox(height: 12),
            // Slider for custom duration
            Row(
              children: [
                const Text('Kustom:',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                Expanded(
                  child: Slider(
                    value: _selectedDuration.toDouble(),
                    min: 10,
                    max: 120,
                    divisions: 22,
                    label: '$_selectedDuration Menit',
                    onChanged: (val) {
                      setState(() => _selectedDuration = val.toInt());
                    },
                  ),
                ),
                Text(
                  '$_selectedDuration mnt',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Target Course
            const Text(
              'Mata Kuliah Target',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _selectedCourseId,
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Fokus Bebas (Tanpa Matkul)'),
                ),
                ...courses.map(
                  (c) => DropdownMenuItem(
                    value: c.id,
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
                        Expanded(child: Text(c.name)),
                      ],
                    ),
                  ),
                ),
              ],
              onChanged: (val) => setState(() => _selectedCourseId = val),
            ),

            const SizedBox(height: 20),

            // Distraction Blocking Toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.neutral200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.screen_lock_portrait,
                        color: AppColors.warning),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kunci Layar (Screen Pinning)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Mencegah membuka WhatsApp, Instagram, YouTube saat sesi berjalan.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _enablePinning,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _enablePinning = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Ambient Sound Selector
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.neutral200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.headphones, color: AppColors.secondary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Suara Latar (Ambient)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Suara relaksasi membantu konsentrasi belajar.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DropdownButton<String>(
                    value: _selectedAmbient,
                    underline: const SizedBox.shrink(),
                    items: _ambientOptions.map((opt) {
                      return DropdownMenuItem(value: opt, child: Text(opt));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedAmbient = val);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Start Focus Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => FocusActiveScreen(
                        durationMinutes: _selectedDuration,
                        course: _selectedCourseId != null ? selectedCourse : null,
                        enablePinning: _enablePinning,
                        ambientSound: _selectedAmbient,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 28),
                label: Text(
                  'Mulai Fokus ($_selectedDuration Menit)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Mini stats preview
            statsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, st) => const SizedBox.shrink(),
              data: (stats) {
                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (ctx) => const FocusStatsScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.neutral100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.insights,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Total minggu ini: ${stats.totalMinutes} menit fokus',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Lihat Grafik',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            size: 16, color: AppColors.primary),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton(int minutes, String label) {
    final isSelected = _selectedDuration == minutes;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedDuration = minutes),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.1)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.neutral200,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
