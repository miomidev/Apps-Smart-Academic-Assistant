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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
                SizedBox(width: 8),
                Text('Berhasil Terjadwal!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Text(
              '$totalScheduled item jadwal dan tugas berhasil ditambahkan ke kalender Anda beserta pengingat otomatis.',
              style: const TextStyle(color: Color(0xFF475569)),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF42A5F5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop(); // pop review
                  Navigator.of(context).pop(); // pop upload
                },
                child: const Text('Bagus, Selesai!', style: TextStyle(fontWeight: FontWeight.bold)),
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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF212121)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tinjau Hasil Ekstraksi',
          style: TextStyle(
            color: Color(0xFF212121),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _toggleSelectAll(
              selectedMeetings.length != _meetings.length,
            ),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF42A5F5),
            ),
            child: Text(
              selectedMeetings.length == _meetings.length
                  ? 'Batal Semua'
                  : 'Pilih Semua',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.extractionResult.courseName ?? 'Mata Kuliah',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF212121),
                      ),
                    ),
                    if (widget.extractionResult.lecturer != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Dosen: ${widget.extractionResult.lecturer}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    Row(
                      children: [
                        const Text(
                          'Jam Kuliah:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          label: Text(_formatTimeOfDay(_startTime), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0284C7))),
                          backgroundColor: const Color(0xFFE0F2FE),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          onPressed: _pickStartTime,
                        ),
                        const SizedBox(width: 4),
                        const Text('-', style: TextStyle(color: Color(0xFF64748B))),
                        const SizedBox(width: 4),
                        ActionChip(
                          label: Text(_formatTimeOfDay(_endTime), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0284C7))),
                          backgroundColor: const Color(0xFFE0F2FE),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: meeting.isSelected
                              ? const Color(0xFF42A5F5).withValues(alpha: 0.5)
                              : const Color(0xFFEEEEEE),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x04000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
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
                                  activeColor: const Color(0xFF42A5F5),
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
                                    color: const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Pertemuan ${meeting.meetingNumber}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (meeting.date != null)
                                  Text(
                                    DateFormat('d MMM yyyy').format(meeting.date!),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
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
                                      color: Color(0xFF212121),
                                    ),
                                  ),
                                  if (meeting.subTopics.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      meeting.subTopics.join(', '),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                  if (meeting.tasks.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      children: meeting.tasks.map((t) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF7ED),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFFFEDD5)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.assignment_outlined,
                                                size: 13,
                                                color: Color(0xFFEA580C),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                t.title,
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFEA580C)),
                                              ),
                                            ],
                                          ),
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
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _scheduleAll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF42A5F5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
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
