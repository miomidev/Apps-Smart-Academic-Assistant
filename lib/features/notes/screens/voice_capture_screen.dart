import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../core/constants/app_colors.dart';
import '../../courses/providers/courses_provider.dart';
import '../models/note_model.dart';
import '../providers/notes_provider.dart';

class VoiceCaptureScreen extends ConsumerStatefulWidget {
  final String? preselectedCourseId;

  const VoiceCaptureScreen({
    super.key,
    this.preselectedCourseId,
  });

  @override
  ConsumerState<VoiceCaptureScreen> createState() => _VoiceCaptureScreenState();
}

class _VoiceCaptureScreenState extends ConsumerState<VoiceCaptureScreen> {
  late final AudioRecorder _audioRecorder;
  late final stt.SpeechToText _speech;
  StreamSubscription<Amplitude>? _amplitudeSub;

  bool _isRecording = false;
  bool _isPaused = false;
  String? _recordedFilePath;

  // Waveform data
  final List<double> _waveAmplitudes = [];
  final int _maxVisibleBars = 45;

  // Timer: centiseconds (1/100 second)
  Timer? _ticker;
  int _centisecondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _speech = stt.SpeechToText();
    // Initialize resting baseline waveform bars
    for (int i = 0; i < _maxVisibleBars; i++) {
      _waveAmplitudes.add(0.06);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _amplitudeSub?.cancel();
    _audioRecorder.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _startRecording() async {
    // 1. Check microphone permission
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin mikrofon diperlukan untuk merekam.')),
        );
      }
      return;
    }

    // 2. Start audio file recording with mono AAC for maximum compatibility
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final filePath = '${dir.path}/$fileName';
    _recordedFilePath = filePath;

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: filePath,
    );

    // 3. Reset and start timer
    _centisecondsElapsed = 0;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 10), (_) {
      if (!_isPaused && mounted) {
        setState(() => _centisecondsElapsed++);
      }
    });

    // 4. Listen to real-time amplitude for visualizer
    _amplitudeSub?.cancel();
    _amplitudeSub = _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 70)).listen((amp) {
      if (_isPaused || !mounted) return;
      final db = amp.current;
      double normalized;
      if (db <= -60) {
        normalized = 0.08 + Random().nextDouble() * 0.07;
      } else {
        normalized = (1.0 + (db / 60.0)).clamp(0.12, 1.0);
      }

      setState(() {
        _waveAmplitudes.add(normalized);
        if (_waveAmplitudes.length > _maxVisibleBars) {
          _waveAmplitudes.removeAt(0);
        }
      });
    });

    if (mounted) {
      setState(() {
        _isRecording = true;
        _isPaused = false;
      });
    }
  }

  Future<void> _togglePauseResume() async {
    if (!_isRecording) return;
    if (_isPaused) {
      await _audioRecorder.resume();
      setState(() => _isPaused = false);
    } else {
      await _audioRecorder.pause();
      setState(() => _isPaused = true);
    }
  }

  Future<void> _stopRecording() async {
    _ticker?.cancel();
    _amplitudeSub?.cancel();

    String? finalPath;
    try {
      finalPath = await _audioRecorder.stop();
    } catch (_) {
      finalPath = _recordedFilePath;
    }

    finalPath ??= _recordedFilePath;

    setState(() {
      _isRecording = false;
      _isPaused = false;
    });

    if (finalPath != null && mounted) {
      _showSaveSheet(finalPath);
    }
  }

  void _showSaveSheet(String filePath) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _SaveAudioNoteSheet(
        filePath: filePath,
        durationSeconds: (_centisecondsElapsed / 100).ceil(),
        initialTranscript: '',
        preselectedCourseId: widget.preselectedCourseId,
        onSaved: () {
          Navigator.of(ctx).pop(); // close sheet
          Navigator.of(context).pop(); // back to Catatan
        },
      ),
    );
  }

  String _formatTimer() {
    final totalCentis = _centisecondsElapsed;
    final minutes = (totalCentis ~/ 6000).toString().padLeft(2, '0');
    final seconds = ((totalCentis % 6000) ~/ 100).toString().padLeft(2, '0');
    final centis = (totalCentis % 100).toString().padLeft(2, '0');
    return '$minutes.$seconds.$centis';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Header Row: Merekam & Tombol Close
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Merekam',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      _stopRecording();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF58ACF6),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 2),

            // Waveform & Audio Ruler Visualizer
            SizedBox(
              height: 220,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Top Ruler
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _AudioRuler(isTop: true),
                  ),

                  // Waveform Bars
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: _buildWaveformBars(),
                  ),

                  // Bottom Ruler
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _AudioRuler(isTop: false),
                  ),

                  // Central Red Indicator Needle with 2 Dots (Exact Match)
                  Positioned(
                    top: 2,
                    bottom: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top Dot
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFF87171),
                          ),
                        ),
                        // Needle Line
                        Expanded(
                          child: Container(
                            width: 2.2,
                            color: const Color(0xFFF87171),
                          ),
                        ),
                        // Bottom Dot
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFF87171),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Timer (MM.SS.cc)
            Text(
              _formatTimer(),
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w400,
                color: Color(0xFF0F172A),
                letterSpacing: 1.0,
              ),
            ),

            const Spacer(flex: 2),

            // Recording Controls
            if (!_isRecording && !_isPaused) ...[
              // Button to start recording on user action
              InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: _startRecording,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF58ACF6),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF58ACF6).withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mic_rounded, color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Mulai Merekam',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Recording Controls: Stop & Pause / Resume (Exact match Screenshot 2)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Stop Button
                  InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: _stopRecording,
                    child: Container(
                      width: 86,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF58ACF6),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Center(
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Pause / Resume Button
                  InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: _togglePauseResume,
                    child: Container(
                      width: 86,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF58ACF6),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Center(
                        child: Icon(
                          _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveformBars() {
    // Generate bars to display
    final bars = List<double>.from(_waveAmplitudes);
    while (bars.length < _maxVisibleBars) {
      bars.insert(0, 0.06);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = 3.6;
        final spacing = 4.2;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: bars.map((amp) {
            final barHeight = (amp * 130).clamp(6.0, 130.0);

            return Container(
              width: barWidth,
              height: barHeight,
              margin: EdgeInsets.symmetric(horizontal: spacing / 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// Audio Ruler with fine vertical tick marks matching Screenshot 2
class _AudioRuler extends StatelessWidget {
  final bool isTop;

  const _AudioRuler({required this.isTop});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      width: double.infinity,
      child: CustomPaint(
        painter: _RulerPainter(isTop: isTop),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  final bool isTop;

  _RulerPainter({required this.isTop});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF93C5FD)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    final tickSpacing = 7.5;
    final totalTicks = (size.width / tickSpacing).ceil();

    for (int i = 0; i <= totalTicks; i++) {
      final x = i * tickSpacing;
      final isMajor = i % 5 == 0;
      final tickHeight = isMajor ? 14.0 : 8.0;

      if (isTop) {
        canvas.drawLine(Offset(x, 0), Offset(x, tickHeight), paint);
      } else {
        canvas.drawLine(Offset(x, size.height), Offset(x, size.height - tickHeight), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Bottom sheet to preview audio playback, edit transcript, and save note
class _SaveAudioNoteSheet extends ConsumerStatefulWidget {
  final String filePath;
  final int durationSeconds;
  final String initialTranscript;
  final String? preselectedCourseId;
  final VoidCallback onSaved;

  const _SaveAudioNoteSheet({
    required this.filePath,
    required this.durationSeconds,
    required this.initialTranscript,
    this.preselectedCourseId,
    required this.onSaved,
  });

  @override
  ConsumerState<_SaveAudioNoteSheet> createState() => _SaveAudioNoteSheetState();
}

class _SaveAudioNoteSheetState extends ConsumerState<_SaveAudioNoteSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _transcriptController;
  late final AudioPlayer _player;

  String? _selectedCourseId;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: 'Catatan Rekaman ${DateFormat('d MMM, HH:mm').format(DateTime.now())}',
    );
    _transcriptController = TextEditingController(text: widget.initialTranscript);
    _selectedCourseId = widget.preselectedCourseId;

    _player = AudioPlayer();
    _initAudioPlayer();
  }

  Future<void> _initAudioPlayer() async {
    try {
      await _player.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.defaultToSpeaker},
          ),
        ),
      );
      await _player.setVolume(1.0);
    } catch (_) {}

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });

    _player.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() => _currentPosition = pos);
      }
    });

    _player.onDurationChanged.listen((dur) {
      if (mounted) {
        setState(() => _totalDuration = dur);
      }
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentPosition = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _titleController.dispose();
    _transcriptController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _togglePlayPreview() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.setVolume(1.0);
      await _player.play(DeviceFileSource(widget.filePath));
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      final file = File(widget.filePath);
      final fileName = file.uri.pathSegments.last;

      // 1. Upload audio file to backend
      final fileUrl = await ref.read(notesListProvider.notifier).uploadAudioFile(
            filePath: widget.filePath,
            fileName: fileName,
          );

      // 2. Create note in backend
      await ref.read(notesListProvider.notifier).createNote(
            title: _titleController.text.trim(),
            content: _transcriptController.text.trim().isNotEmpty
                ? _transcriptController.text.trim()
                : 'Hasil rekaman audio (${widget.durationSeconds} detik)',
            type: NoteType.voice,
            courseId: _selectedCourseId,
            durationSeconds: widget.durationSeconds,
            fileUrl: fileUrl,
            fileName: fileName,
            mimeType: 'audio/m4a',
            fileSize: await file.length(),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Catatan rekaman suara berhasil disimpan!'),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan catatan: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(coursesListProvider).value ?? [];

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Simpan Rekaman Suara',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),

            // Audio Player Preview Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: _togglePlayPreview,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFF58ACF6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Putar Ulang Hasil Rekaman',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${_formatDuration(_currentPosition)} / ${_formatDuration(_totalDuration.inSeconds > 0 ? _totalDuration : Duration(seconds: widget.durationSeconds))}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3.0,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                      activeTrackColor: const Color(0xFF58ACF6),
                      inactiveTrackColor: const Color(0xFFCBD5E1),
                      thumbColor: const Color(0xFF58ACF6),
                    ),
                    child: Slider(
                      min: 0.0,
                      max: (_totalDuration.inMilliseconds > 0
                              ? _totalDuration.inMilliseconds
                              : widget.durationSeconds * 1000)
                          .toDouble(),
                      value: _currentPosition.inMilliseconds
                          .toDouble()
                          .clamp(
                            0.0,
                            (_totalDuration.inMilliseconds > 0
                                    ? _totalDuration.inMilliseconds
                                    : widget.durationSeconds * 1000)
                                .toDouble(),
                          ),
                      onChanged: (val) async {
                        final target = Duration(milliseconds: val.toInt());
                        await _player.seek(target);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Title input
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Judul Catatan',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 14),

            // Course selection
            DropdownButtonFormField<String?>(
              initialValue: _selectedCourseId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Mata Kuliah (Opsional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Tanpa Mata Kuliah')),
                ...courses.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
              ],
              onChanged: (val) => setState(() => _selectedCourseId = val),
            ),
            const SizedBox(height: 14),

            // Transcript text area
            TextField(
              controller: _transcriptController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Transkrip / Isi Catatan',
                hintText: 'Tuliskan poin-poin materi atau hasil transkrip...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF58ACF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Simpan Catatan',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
