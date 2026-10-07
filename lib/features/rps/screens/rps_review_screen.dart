import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../models/rps_extraction_model.dart';
import '../providers/rps_provider.dart';

class RpsReviewScreen extends ConsumerStatefulWidget {
  final String courseId;
  final RpsExtractionResult extractionResult;

  const RpsReviewScreen({
    super.key,
    required this.courseId,
    required this.extractionResult,
  });

  @override
  ConsumerState<RpsReviewScreen> createState() => _RpsReviewScreenState();
}

class _RpsReviewScreenState extends ConsumerState<RpsReviewScreen> {
  late List<ExtractedMeeting> _meetings;
  late ConfettiController _confettiController;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 40);
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _meetings = widget.extractionResult.meetings;
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _toggleSelectAll(bool select) {
    setState(() {
      for (final m in _meetings) {
        m.isSelected = select;
      }
    });
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _scheduleAll() async {
    final selectedCount = _meetings.where((m) => m.isSelected).length;
    if (selectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal satu pertemuan.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final totalScheduled =
          await ref.read(rpsExtractionProvider.notifier).confirmAndScheduleBulk(
                courseId: widget.courseId,
                meetings: _meetings,
                defaultStartTime: _formatTimeOfDay(_startTime),
                defaultEndTime: _formatTimeOfDay(_endTime),
              );

      if (mounted) {
        setState(() => _isSaving = false);
        _confettiController.play();

        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success),
                SizedBox(width: 8),
                Text('Berhasil Terjadwal!'),
              ],
            ),
            content: Text(
              '$totalScheduled item jadwal dan tugas berhasil ditambahkan ke kalender Anda beserta pengingat otomatis.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop(); // pop review
                  Navigator.of(context).pop(); // pop upload
                },
                child: const Text('Bagus, Selesai!'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menjadwalkan: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedMeetings = _meetings.where((m) => m.isSelected).toList();
    final int totalTasks = selectedMeetings.fold(
      0,
      (acc, m) => acc + m.tasks.length,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tinjau Hasil Ekstraksi'),
        actions: [
          TextButton(
            onPressed: () => _toggleSelectAll(
              selectedMeetings.length != _meetings.length,
            ),
            child: Text(
              selectedMeetings.length == _meetings.length
                  ? 'Batal Semua'
                  : 'Pilih Semua',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Course metadata card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.extractionResult.courseName ?? 'Mata Kuliah',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (widget.extractionResult.lecturer != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Dosen: ${widget.extractionResult.lecturer}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const Divider(height: 16),
                    Row(
                      children: [
                        const Text(
                          'Jam Kuliah:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          label: Text(_formatTimeOfDay(_startTime)),
                          onPressed: _pickStartTime,
                        ),
                        const SizedBox(width: 4),
                        const Text('-'),
                        const SizedBox(width: 4),
                        ActionChip(
                          label: Text(_formatTimeOfDay(_endTime)),
                          onPressed: _pickEndTime,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Meetings list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _meetings.length,
                  itemBuilder: (ctx, i) {
                    final meeting = _meetings[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: meeting.isSelected
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : Colors.transparent,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: meeting.isSelected,
                                  onChanged: (val) {
                                    setState(() {
                                      meeting.isSelected = val ?? false;
                                    });
                                  },
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Pertemuan ${meeting.meetingNumber}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (meeting.date != null)
                                  Text(
                                    DateFormat('d MMM yyyy')
                                        .format(meeting.date!),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 48, right: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    meeting.topic,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (meeting.subTopics.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      meeting.subTopics.join(', '),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                  if (meeting.tasks.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      children: meeting.tasks.map((t) {
                                        return Chip(
                                          avatar: const Icon(
                                            Icons.assignment_outlined,
                                            size: 12,
                                            color: AppColors.warning,
                                          ),
                                          label: Text(
                                            t.title,
                                            style: const TextStyle(fontSize: 10),
                                          ),
                                          backgroundColor: AppColors.warning
                                              .withValues(alpha: 0.1),
                                          padding: EdgeInsets.zero,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom confirm button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _scheduleAll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Jadwalkan (${selectedMeetings.length} Pertemuan + $totalTasks Tugas)',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 25,
            ),
          ),
        ],
      ),
    );
  }
}
