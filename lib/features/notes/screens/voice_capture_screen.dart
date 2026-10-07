import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../core/constants/app_colors.dart';
import '../providers/notes_provider.dart';
import '../widgets/auto_tag_sheet.dart';

class VoiceCaptureScreen extends ConsumerStatefulWidget {
  final String? preselectedCourseId;

  const VoiceCaptureScreen({
    super.key,
    this.preselectedCourseId,
  });

  @override
  ConsumerState<VoiceCaptureScreen> createState() => _VoiceCaptureScreenState();
}

class _VoiceCaptureScreenState extends ConsumerState<VoiceCaptureScreen>
    with SingleTickerProviderStateMixin {
  late final stt.SpeechToText _speech;
  final TextEditingController _titleController =
      TextEditingController(text: 'Catatan Suara');
  final TextEditingController _transcriptController = TextEditingController();

  bool _isSpeechInitialized = false;
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isProcessing = false;
  String _selectedLocaleId = 'id_ID';

  Timer? _durationTimer;
  int _secondsRecorded = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initPulseAnimation();
    _initSpeech();
  }

  void _initPulseAnimation() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initSpeech() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      final available = await _speech.initialize(
        onStatus: (status) {
          // Restart loop: Android speech engine stops after silence timeout (~30s)
          if ((status == 'done' || status == 'notListening') &&
              _isRecording &&
              !_isPaused) {
            _restartListening();
          }
        },
        onError: (error) {
          if (_isRecording && !_isPaused) {
            _restartListening();
          }
        },
      );
      if (mounted) {
        setState(() => _isSpeechInitialized = available);
      }
    }
  }

  void _restartListening() {
    if (!_isRecording || _isPaused || !mounted) return;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_isRecording && !_isPaused && mounted) {
        _startListening();
      }
    });
  }

  Future<void> _startListening() async {
    if (!_isSpeechInitialized) return;

    try {
      await _speech.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty && mounted) {
            setState(() {
              // Append to existing text or update latest words
              if (_transcriptController.text.isEmpty) {
                _transcriptController.text = result.recognizedWords;
              } else if (!result.finalResult) {
                // Live preview
              } else {
                _transcriptController.text =
                    '${_transcriptController.text.trim()} ${result.recognizedWords}';
              }
            });
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
          localeId: _selectedLocaleId,
        ),
      );
    } catch (_) {}
  }

  void _toggleRecording() async {
    if (!_isSpeechInitialized) {
      await _initSpeech();
      if (!_isSpeechInitialized) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin mikrofon diperlukan.')),
          );
        }
        return;
      }
    }

    if (!_isRecording) {
      // Start recording
      setState(() {
        _isRecording = true;
        _isPaused = false;
        _secondsRecorded = 0;
      });
      _startListening();
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_isPaused && mounted) {
          setState(() => _secondsRecorded++);
        }
      });
    } else {
      // Stop recording
      _stopRecording();
    }
  }

  void _pauseOrResume() {
    if (!_isRecording) return;
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      _speech.stop();
    } else {
      _startListening();
    }
  }

  Future<void> _stopRecording() async {
    _durationTimer?.cancel();
    await _speech.stop();
    setState(() {
      _isRecording = false;
      _isPaused = false;
    });
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _onFinishAndSave() async {
    await _stopRecording();

    final text = _transcriptController.text.trim();
    if (text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transkrip kosong. Ucapkan sesuatu terlebih dahulu.')),
        );
      }
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Step 1: AI Course Suggestion
      final autoTagResult = await ref.read(notesListProvider.notifier).suggestCourse(
            content: text,
            createdAt: DateTime.now(),
          );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      // Step 2: Show Auto-Tagging Bottom Sheet
      final chosenCourseId = await AutoTagSheet.show(
        context,
        autoTagResult: autoTagResult,
        initialCourseId: widget.preselectedCourseId,
      );

      // Step 3: Save to backend
      if (!mounted) return;
      setState(() => _isProcessing = true);

      final title = _titleController.text.trim().isEmpty
          ? 'Catatan Suara ${_formatDuration(_secondsRecorded)}'
          : _titleController.text.trim();

      await ref.read(notesListProvider.notifier).createNote(
            title: title,
            content: text,
            courseId: chosenCourseId,
            durationSeconds: _secondsRecorded,
            suggestedCourseId: autoTagResult?.suggestedCourseId,
            confidenceScore: autoTagResult?.confidenceScore,
            language: _selectedLocaleId,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Catatan suara berhasil disimpan!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _pulseController.dispose();
    _speech.stop();
    _titleController.dispose();
    _transcriptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Transcription'),
        actions: [
          // Language selector
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            tooltip: 'Pilih Bahasa',
            initialValue: _selectedLocaleId,
            onSelected: (loc) => setState(() => _selectedLocaleId = loc),
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'id_ID', child: Text('Bahasa Indonesia')),
              PopupMenuItem(value: 'en_US', child: Text('English (US)')),
            ],
          ),
        ],
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Menganalisis transkrip dengan AI...'),
                ],
              ),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    // Title field
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Judul Catatan...',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const Divider(height: 24),

                    // Live Transcript Editor
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.neutral200),
                        ),
                        child: TextField(
                          controller: _transcriptController,
                          maxLines: null,
                          expands: true,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: _isRecording
                                ? 'Mendengarkan perkataan Anda...'
                                : 'Tekan tombol mikrofon di bawah untuk mulai merekam, atau ketik langsung di sini...',
                            hintStyle: TextStyle(
                              color: AppColors.textSecondary.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Timer badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isRecording
                            ? AppColors.error.withValues(alpha: 0.1)
                            : AppColors.neutral200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isRecording && !_isPaused)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Text(
                            _formatDuration(_secondsRecorded),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _isRecording
                                  ? AppColors.error
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Controls Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Clear
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          iconSize: 28,
                          color: AppColors.textSecondary,
                          tooltip: 'Hapus Teks',
                          onPressed: () {
                            _transcriptController.clear();
                            setState(() => _secondsRecorded = 0);
                          },
                        ),

                        // Pause / Resume (when recording)
                        if (_isRecording)
                          IconButton(
                            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                            iconSize: 32,
                            color: AppColors.primary,
                            tooltip: _isPaused ? 'Lanjutkan' : 'Jeda',
                            onPressed: _pauseOrResume,
                          )
                        else
                          const SizedBox(width: 48),

                        // Center Record / Stop Button with Pulse
                        ScaleTransition(
                          scale: _isRecording && !_isPaused
                              ? _pulseAnimation
                              : const AlwaysStoppedAnimation(1.0),
                          child: InkWell(
                            onTap: _toggleRecording,
                            customBorder: const CircleBorder(),
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isRecording
                                    ? AppColors.error
                                    : AppColors.primary,
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isRecording
                                            ? AppColors.error
                                            : AppColors.primary)
                                        .withValues(alpha: 0.35),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isRecording ? Icons.stop : Icons.mic,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
                        ),

                        // Done / Save Button
                        IconButton(
                          icon: const Icon(Icons.check_circle_outline),
                          iconSize: 32,
                          color: AppColors.success,
                          tooltip: 'Simpan Catatan',
                          onPressed: _onFinishAndSave,
                        ),

                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}
