import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class QuickActionsRow extends StatelessWidget {
  final VoidCallback onRecordVoice;
  final VoidCallback onStartFocus;
  final VoidCallback onUploadRps;
  final VoidCallback onAddCourse;

  const QuickActionsRow({
    super.key,
    required this.onRecordVoice,
    required this.onStartFocus,
    required this.onUploadRps,
    required this.onAddCourse,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ActionButton(
          icon: Icons.mic_rounded,
          label: 'Rekam',
          color: AppColors.primary,
          onTap: onRecordVoice,
        ),
        _ActionButton(
          icon: Icons.lock_clock_rounded,
          label: 'Fokus',
          color: const Color(0xFF8B5CF6),
          onTap: onStartFocus,
        ),
        _ActionButton(
          icon: Icons.picture_as_pdf_rounded,
          label: 'Unggah RPS',
          color: AppColors.secondary,
          onTap: onUploadRps,
        ),
        _ActionButton(
          icon: Icons.add_circle_outline_rounded,
          label: 'Tambah MK',
          color: AppColors.success,
          onTap: onAddCourse,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 78,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
