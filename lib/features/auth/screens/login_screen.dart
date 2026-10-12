import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    final success =
        await ref.read(authStateProvider.notifier).loginWithDevBypass();
    if (mounted) {
      setState(() => _isLoading = false);
    }

    if (success && mounted) {
      context.go('/');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal login ke server. Periksa koneksi backend.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showServerConfigDialog() {
    final storage = ref.read(storageServiceProvider);
    final controller = TextEditingController(text: storage.getBaseUrl());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pengaturan Server Backend'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gunakan IP laptop jika menjalankan di HP fisik (contoh: http://192.168.1.5:3000/api/v1):',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                hintText: 'http://10.0.2.2:3000/api/v1',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await storage.setBaseUrl(controller.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Server URL disimpan!')),
                  );
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Konfigurasi Server',
            icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
            onPressed: _showServerConfigDialog,
          ),
          TextButton(
            onPressed: () {
              ref.read(authStateProvider.notifier).loginWithDevBypass();
              context.go('/');
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Lewati',
                  style: TextStyle(
                    color: Color(0xFF58ACF6),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF58ACF6)),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // App Logo
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF42A5F5).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  size: 44,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Smart Academic\nAssistant',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Fokus belajar lebih tajam, transkripsi suara pintar, dan kelola jadwal RPS otomatis.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 32),

              // Feature Badges
              const _FeatureBadge(
                icon: Icons.mic_rounded,
                title: 'Voice Auto-Tag',
                subtitle: 'Transkripsi bicara langsung tersimpan ke mata kuliah',
              ),
              const SizedBox(height: 12),
              const _FeatureBadge(
                icon: Icons.picture_as_pdf_rounded,
                title: 'RPS Extractor',
                subtitle: 'Upload PDF RPS, langsung jadi jadwal kuliah 1 semester',
              ),
              const SizedBox(height: 12),
              const _FeatureBadge(
                icon: Icons.lock_clock_rounded,
                title: 'Deep Focus Blocker',
                subtitle: 'Kunci distraksi hp saat sesi Pomodoro belajar',
              ),

              const SizedBox(height: 36),

              // Login Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42A5F5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.school_rounded),
                  label: Text(
                    _isLoading ? 'Menghubungkan...' : 'Masuk sebagai Mahasiswa',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(authStateProvider.notifier).loginWithDevBypass();
                    context.go('/');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF42A5F5),
                    side: const BorderSide(color: Color(0xFF42A5F5), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text(
                    'Lewati (Masuk ke Beranda)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Dikembangkan untuk IconFest • Universitas Siliwangi',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureBadge({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
