import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../providers/auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _universityController =
      TextEditingController(text: 'Universitas Siliwangi');
  int _currentPage = 0;
  bool _notificationGranted = false;
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _onboardingPages = [
    {
      'title': 'Voice Auto-Tag Pintar',
      'subtitle':
          'Rekam penjelasan dosen saat kuliah. Teks langsung terdeteksi dan otomatis dikategorikan ke mata kuliah yang sesuai.',
      'icon': Icons.mic_rounded,
      'color': AppColors.primary,
    },
    {
      'title': 'RPS ke Jadwal Otomatis',
      'subtitle':
          'Cukup upload file PDF RPS dari dosen, Smart Academic Assistant akan mengekstrak 16 pertemuan lengkap dengan tanggal & pengingat.',
      'icon': Icons.picture_as_pdf_rounded,
      'color': AppColors.secondary,
    },
    {
      'title': 'Deep Focus Distraction Blocker',
      'subtitle':
          'Kunci HP kamu saat sesi belajar mandiri dengan Screen Pinning native. Selamat tinggal distraksi media sosial!',
      'icon': Icons.lock_clock_rounded,
      'color': AppColors.accent,
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _universityController.dispose();
    super.dispose();
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    if (mounted) {
      setState(() {
        _notificationGranted = status.isGranted;
      });
      if (status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin notifikasi pengingat kuliah diaktifkan!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() => _isSubmitting = true);
    final storage = ref.read(storageServiceProvider);
    final authNotifier = ref.read(authStateProvider.notifier);
    final currentUser = ref.read(authStateProvider).value;

    final university = _universityController.text.trim();
    if (currentUser != null && university.isNotEmpty) {
      await authNotifier.updateProfile(
        name: currentUser.name,
        university: university,
      );
    }

    await storage.setOnboardingCompleted(true);
    if (mounted) {
      setState(() => _isSubmitting = false);
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _completeOnboarding,
            child: const Text(
              'Lewati',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _onboardingPages.length + 1,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemBuilder: (context, index) {
                  if (index < _onboardingPages.length) {
                    final item = _onboardingPages[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: (item['color'] as Color).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Icon(
                              item['icon'] as IconData,
                              size: 52,
                              color: item['color'] as Color,
                            ),
                          ),
                          const SizedBox(height: 36),
                          Text(
                            item['title'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            item['subtitle'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    // Final Page: Profil Kampus & Izin Notifikasi
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Icon(
                              Icons.school_rounded,
                              size: 44,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Satu Langkah Lagi!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Sesuaikan kampus kamu dan aktifkan notifikasi agar tidak melewatkan jadwal kuliah.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Input Universitas
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Asal Universitas / Kampus',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _universityController,
                            decoration: InputDecoration(
                              hintText: 'Contoh: Universitas Siliwangi',
                              prefixIcon: const Icon(Icons.apartment_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Card Izin Notifikasi
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _notificationGranted
                                      ? Icons.notifications_active_rounded
                                      : Icons.notifications_outlined,
                                  color: _notificationGranted
                                      ? AppColors.success
                                      : AppColors.primary,
                                  size: 28,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Pengingat Jadwal Kuliah',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        _notificationGranted
                                            ? 'Izin notifikasi sudah aktif'
                                            : 'Kirim notifikasi sebelum kelas dimulai',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!_notificationGranted)
                                  ElevatedButton(
                                    onPressed: _requestNotificationPermission,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      textStyle: const TextStyle(fontSize: 12),
                                    ),
                                    child: const Text('Aktifkan'),
                                  )
                                else
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.success,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),
            // Bottom Indicator & Next Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dots
                  Row(
                    children: List.generate(
                      _onboardingPages.length + 1,
                      (idx) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 6),
                        width: _currentPage == idx ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == idx
                              ? AppColors.primary
                              : AppColors.neutral300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  // Button
                  ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            if (_currentPage < _onboardingPages.length) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              _completeOnboarding();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _currentPage < _onboardingPages.length
                                ? 'Lanjut'
                                : 'Mulai Belajar',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
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
}
