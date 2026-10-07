import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../courses/models/course_model.dart';
import '../models/focus_session_model.dart';
import '../providers/focus_provider.dart';

class FocusActiveScreen extends ConsumerStatefulWidget {
  final int durationMinutes;
  final CourseModel? course;
  final bool enablePinning;
  final String ambientSound;

  const FocusActiveScreen({
    super.key,
    required this.durationMinutes,
    this.course,
    this.enablePinning = true,
    this.ambientSound = 'None',
  });

  @override
  ConsumerState<FocusActiveScreen> createState() => _FocusActiveScreenState();
}

class _FocusActiveScreenState extends ConsumerState<FocusActiveScreen> {
  late int _totalSeconds;
  late int _remainingSeconds;
  Timer? _timer;
  bool _isPaused = false;
  late DateTime _startedAt;
  late ConfettiController _confettiController;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _totalSeconds = widget.durationMinutes * 60;
    _remainingSeconds = _totalSeconds;
    _startedAt = DateTime.now();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 4));

    _startTimer();
    _enableBlocking();
  }

  void _enableBlocking() {
    if (widget.enablePinning) {
      ref.read(focusSessionsProvider.notifier).enableDistractionBlocking();
    }
  }

  void _disableBlocking() {
    ref.read(focusSessionsProvider.notifier).disableDistractionBlocking();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        if (_remainingSeconds > 0) {
          setState(() => _remainingSeconds--);
        } else {
          _timer?.cancel();
          _onTimerComplete();
        }
      }
    });
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
  }

  Future<void> _onTimerComplete() async {
    setState(() => _isFinished = true);
    _confettiController.play();
    _disableBlocking();

    try {
      await ref.read(focusSessionsProvider.notifier).recordSession(
            courseId: widget.course?.id,
            durationMinutes: widget.durationMinutes,
            actualMinutes: widget.durationMinutes,
            status: FocusStatus.completed,
            startedAt: _startedAt,
            endedAt: DateTime.now(),
          );
    } catch (_) {}

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Center(
            child: Text(
              '🎉 Selamat!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Kamu berhasil fokus penuh selama ${widget.durationMinutes} menit!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),
              if (widget.course != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Mata Kuliah: ${widget.course!.name}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.fromHex(widget.course!.colorHex),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Statistik dan streak belajarmu telah diperbarui.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Kembali ke Menu'),
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _onSurrender() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Menyerah Sekarang?'),
        content: const Text(
          'Sesi ini belum selesai dan tidak akan dihitung dalam statistik fokus mingguan Anda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Lanjut Fokus'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Menyerah'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _timer?.cancel();
      _disableBlocking();

      final elapsedMinutes = (_totalSeconds - _remainingSeconds) ~/ 60;

      try {
        await ref.read(focusSessionsProvider.notifier).recordSession(
              courseId: widget.course?.id,
              durationMinutes: widget.durationMinutes,
              actualMinutes: elapsedMinutes,
              status: FocusStatus.failed,
              startedAt: _startedAt,
              endedAt: DateTime.now(),
            );
      } catch (_) {}

      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _confettiController.dispose();
    _disableBlocking();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _totalSeconds > 0
        ? (_totalSeconds - _remainingSeconds) / _totalSeconds
        : 0.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onSurrender();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // Dark focused background
        body: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    // Top header: Course tag & Pinning badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (widget.course != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.fromHex(widget.course!.colorHex)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.fromHex(widget.course!.colorHex),
                              ),
                            ),
                            child: Text(
                              widget.course!.name,
                              style: TextStyle(
                                color: AppColors.fromHex(widget.course!.colorHex),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        if (widget.enablePinning)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.lock, size: 12, color: Colors.amber),
                                SizedBox(width: 4),
                                Text(
                                  'Screen Pinned',
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const Spacer(),

                    // Circular Countdown Timer
                    Center(
                      child: SizedBox(
                        width: 260,
                        height: 260,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 12,
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.secondary,
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _formatTime(_remainingSeconds),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 54,
                                    fontWeight: FontWeight.w300,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _isPaused
                                      ? 'DIJEDA'
                                      : (_isFinished
                                          ? 'SELESAI!'
                                          : 'DEEP FOCUS'),
                                  style: TextStyle(
                                    color: _isPaused
                                        ? Colors.amber
                                        : Colors.white.withValues(alpha: 0.6),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Ambient sound badge if selected
                    if (widget.ambientSound != 'None')
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.music_note,
                                size: 14, color: AppColors.secondary),
                            const SizedBox(width: 6),
                            Text(
                              'Audio: ${widget.ambientSound}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const Spacer(),

                    // Motivational quote
                    Text(
                      '"Konsentrasi adalah jembatan antara tekad dan pencapaian."',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Controls: Pause / Resume & Surrender
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Surrender button
                        TextButton.icon(
                          onPressed: _onSurrender,
                          icon: const Icon(Icons.close, color: Colors.redAccent),
                          label: const Text(
                            'Menyerah',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),

                        // Pause / Resume FAB
                        FloatingActionButton.large(
                          heroTag: 'fab_focus_active',
                          onPressed: _togglePause,
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          child: Icon(
                            _isPaused ? Icons.play_arrow : Icons.pause,
                            size: 36,
                          ),
                        ),

                        const SizedBox(width: 80),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Confetti overlay
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 30,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
