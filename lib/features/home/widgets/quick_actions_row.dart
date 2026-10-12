import 'package:flutter/material.dart';

class QuickActionsRow extends StatelessWidget {
  final VoidCallback onRecordVoice;
  final VoidCallback onStartFocus;
  final VoidCallback onUploadRps;
  final VoidCallback onViewCourses;

  const QuickActionsRow({
    super.key,
    required this.onRecordVoice,
    required this.onStartFocus,
    required this.onUploadRps,
    required this.onViewCourses,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ActionButton(
          icon: Icons.mic_rounded,
          label: 'Rekam',
          color: const Color(0xFF42A5F5),
          bgColor: const Color(0xFFE3F2FD),
          onTap: onRecordVoice,
        ),
        _ActionButton(
          icon: Icons.hourglass_empty_rounded,
          label: 'Fokus',
          color: const Color(0xFF8B5CF6),
          bgColor: const Color(0xFFF3E8FF),
          onTap: onStartFocus,
        ),
        _ActionButton(
          icon: Icons.upload_file_rounded,
          label: 'RPS PDF',
          color: const Color(0xFF0284C7),
          bgColor: const Color(0xFFE0F2FE),
          onTap: onUploadRps,
        ),
        _ActionButton(
          icon: Icons.menu_book_rounded,
          label: 'Matkul',
          color: const Color(0xFF10B981),
          bgColor: const Color(0xFFD1FAE5),
          onTap: onViewCourses,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 78,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEEEEEE)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, color: color, size: 22),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF212121),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
