import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:stt_record/stt_record.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../../courses/providers/courses_provider.dart';
import '../models/auto_tag_result.dart';
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

class _VoiceCaptureScreenState extends ConsumerState<VoiceCaptureScreen>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  int _currentPageIndex = 0;

  late final SttRecord _sttRecord;
  StreamSubscription<SttRecordTranscript>? _transcriptSub;
  Timer? _sttAmplitudeTimer;
  Timer? _draftAutoSaveTimer;

  bool _isRecording = false;
  bool _isPaused = false;

  // Real-time transcript state
  String _liveTranscript = '';
  late final TextEditingController _transcriptTextController;
  late final ScrollController _transcriptScrollController;

  // Waveform data
  final List<double> _waveAmplitudes = [];
  final int _maxVisibleBars = 45;

  // Timer: centiseconds (1/100 second)
  Timer? _ticker;
  int _centisecondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: 0);
    _sttRecord = SttRecord();
    _transcriptTextController = TextEditingController();
    _transcriptScrollController = ScrollController();

    // Initialize resting baseline waveform bars
    for (int i = 0; i < _maxVisibleBars; i++) {
      _waveAmplitudes.add(0.06);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingDraft();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _sttAmplitudeTimer?.cancel();
    _transcriptSub?.cancel();
    _draftAutoSaveTimer?.cancel();
    _pageController.dispose();
    _transcriptTextController.dispose();
    _transcriptScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_isRecording && !_isPaused) {
        _togglePauseResume();
      }
      _saveCurrentDraft();
    }
  }

  void _saveCurrentDraft() {
    final text = _transcriptTextController.text.trim().isNotEmpty
        ? _transcriptTextController.text.trim()
        : _liveTranscript.trim();
    if (text.isNotEmpty) {
      ref.read(storageServiceProvider).saveVoiceDraft(
            text: text,
            durationSeconds: (_centisecondsElapsed / 100).ceil(),
            courseId: widget.preselectedCourseId,
          );
    }
  }

  void _checkPendingDraft() {
    final storage = ref.read(storageServiceProvider);
    final draft = storage.getVoiceDraft();
    if (draft != null && mounted) {
      final text = draft['text'] as String;
      final duration = draft['duration'] as int? ?? 0;
      final timestamp = draft['timestamp'] as int? ?? 0;
      final dateStr = DateFormat('dd MMM, HH:mm').format(
        DateTime.fromMillisecondsSinceEpoch(timestamp),
      );

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.restore_page_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Pulihkan Catatan?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ditemukan draft rekaman suara yang belum sempat disimpan ($dateStr):',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: Text(
                    text,
                    style: const TextStyle(
                        fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                storage.clearVoiceDraft();
                Navigator.pop(ctx);
              },
              child: const Text('Buang Draft',
                  style: TextStyle(color: AppColors.error)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _liveTranscript = text;
                  _transcriptTextController.text = text;
                  _centisecondsElapsed = duration * 100;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Draft berhasil dipulihkan! Kamu bisa melanjutkan atau menyimpannya.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              child: const Text('Lanjutkan Draft'),
            ),
          ],
        ),
      );
    } else if (mounted) {
      // Auto-start recording when entering screen if no draft is pending (matching Recorder(Running))
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && !_isRecording) {
          _startRecording();
        }
      });
    }
  }

  Future<void> _startRecording() async {
    // 1. Check microphone permission
    final hasMic = await _sttRecord.hasPermission();
    if (!hasMic) {
      final granted = await _sttRecord.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin mikrofon diperlukan untuk merekam.')),
          );
        }
        return;
      }
    }

    // Reset transcript and timer
    setState(() {
      _liveTranscript = '';
      _transcriptTextController.text = '';
      _centisecondsElapsed = 0;
    });

    final storage = ref.read(storageServiceProvider);
    final selectedLang = storage.getSpeechLanguage();

    // 2. Start recording with SttRecord (captures audio to WAV and streams live Speech-to-Text in parallel)
    try {
      _transcriptSub?.cancel();
      _transcriptSub = _sttRecord.transcripts.listen((data) {
        if (mounted && data.text.isNotEmpty) {
          setState(() {
            _liveTranscript = data.text;
            _transcriptTextController.text = data.text;
          });
          // Auto scroll to bottom as speech text arrives
          if (_transcriptScrollController.hasClients) {
            _transcriptScrollController.animateTo(
              _transcriptScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        }
      });

      await _sttRecord.start(
        localeId: selectedLang,
        partialResults: true,
        enableSystemNotification: false,
      );

      // Start 15s periodic auto-save (PRD 5.1.A)
      _draftAutoSaveTimer?.cancel();
      _draftAutoSaveTimer =
          Timer.periodic(const Duration(seconds: 15), (_) {
        if (_isRecording && mounted) {
          _saveCurrentDraft();
        }
      });

      // Listen to amplitude for waveform via polling getAmplitude
      _sttAmplitudeTimer?.cancel();
      _sttAmplitudeTimer = Timer.periodic(const Duration(milliseconds: 70), (_) async {
        if (_isPaused || !mounted || !_isRecording) return;
        final amp = await _sttRecord.getAmplitude();
        double normalized;
        if (amp <= 0.03) {
          normalized = 0.08 + Random().nextDouble() * 0.06;
        } else {
          normalized = (amp * 1.5).clamp(0.12, 1.0);
        }

        if (mounted) {
          setState(() {
            _waveAmplitudes.add(normalized);
            if (_waveAmplitudes.length > _maxVisibleBars) {
              _waveAmplitudes.removeAt(0);
            }
          });
        }
      });
    } catch (e) {
      debugPrint('SttRecord start error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memulai perekaman: $e')),
        );
      }
      return;
    }

    // 3. Start timer
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 10), (_) {
      if (!_isPaused && mounted) {
        setState(() => _centisecondsElapsed++);
      }
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
      await _sttRecord.resume();
      setState(() => _isPaused = false);
    } else {
      await _sttRecord.pause();
      setState(() => _isPaused = true);
      _saveCurrentDraft();
    }
  }

  Future<void> _stopRecording() async {
    _ticker?.cancel();
    _sttAmplitudeTimer?.cancel();
    _transcriptSub?.cancel();
    _draftAutoSaveTimer?.cancel();
    _saveCurrentDraft();

    String? finalPath;
    try {
      final stopRes = await _sttRecord.stop();
      finalPath = stopRes.audioPath;
    } catch (e) {
      debugPrint('Error stopping SttRecord: $e');
    }

    setState(() {
      _isRecording = false;
      _isPaused = false;
    });

    if (finalPath != null && mounted) {
      _showSaveSheet(finalPath);
    }
  }

  void _showSaveSheet(String filePath) {
    // Sync any user edits in transcript text controller
    final currentTranscript = _transcriptTextController.text.trim().isNotEmpty
        ? _transcriptTextController.text.trim()
        : _liveTranscript.trim();

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
        initialTranscript: currentTranscript,
        preselectedCourseId: widget.preselectedCourseId,
        onSaved: () {
          ref.read(storageServiceProvider).clearVoiceDraft();
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

  void _copyTranscript() {
    final text = _transcriptTextController.text.trim().isNotEmpty
        ? _transcriptTextController.text.trim()
        : _liveTranscript.trim();

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada teks transkrip untuk disalin')),
      );
      return;
    }

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Teks transkrip berhasil disalin ke papan klip!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Header Row: Merekam & Tombol Close (matching Recorder(Running).svg)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Merekam',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF212121),
                      letterSpacing: -0.5,
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      if (_isRecording) {
                        try {
                          await _sttRecord.cancel();
                        } catch (_) {}
                      }
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFBBDEFB),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.close_rounded,
                          color: Color(0xFF212121),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Top Tab / Pill Switcher (Swipe or Tap)
            _buildTabSwitcher(),

            // PageView containing Kontrol Rekaman (Page 0) & Auto Transkrip (Page 1)
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPageIndex = index);
                },
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildControlsPage(),
                  _buildTranscriptPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Top Tab Switcher
  Widget _buildTabSwitcher() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Tab 0: Kontrol Rekaman
          Expanded(
            child: GestureDetector(
              onTap: () {
                _pageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _currentPageIndex == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _currentPageIndex == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.graphic_eq_rounded,
                      size: 18,
                      color: _currentPageIndex == 0 ? const Color(0xFF58ACF6) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Kontrol Rekaman',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _currentPageIndex == 0 ? FontWeight.w700 : FontWeight.w600,
                        color: _currentPageIndex == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tab 1: Auto Transkrip
          Expanded(
            child: GestureDetector(
              onTap: () {
                _pageController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _currentPageIndex == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _currentPageIndex == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.subtitles_rounded,
                      size: 18,
                      color: _currentPageIndex == 1 ? const Color(0xFF58ACF6) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Auto Transkrip',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _currentPageIndex == 1 ? FontWeight.w700 : FontWeight.w600,
                        color: _currentPageIndex == 1 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                      ),
                    ),
                    if (_isRecording && !_isPaused) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Page 0: Kontrol Rekaman (Waveform, Audio Ruler, Red Indicator Needle, Timer & Controls)
  Widget _buildControlsPage() {
    return Column(
      children: [
        const Spacer(flex: 2),

        // Waveform & Audio Ruler Visualizer (matching Recorder(Running).svg)
        SizedBox(
          height: 270,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Top Ruler
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: const _AudioRuler(isTop: true),
              ),

              // Waveform Bars (Rendered strictly on LEFT half of center line)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: _buildWaveformBars(),
              ),

              // Bottom Ruler
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: const _AudioRuler(isTop: false),
              ),

              // Central Red Indicator Needle with 2 Dots (Exact Match Recorder(Running).svg)
              Positioned(
                top: 0,
                bottom: 0,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Dot (Diameter 10px, #EF5350)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFEF5350),
                      ),
                    ),
                    // Needle Line
                    Expanded(
                      child: Container(
                        width: 2.0,
                        color: const Color(0xFFEF5350),
                      ),
                    ),
                    // Bottom Dot (Diameter 10px, #EF5350)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFEF5350),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Timer Display (MM.SS.cc) matching Recorder(Running).svg (e.g. 00.23.32)
        Text(
          _formatTimer(),
          style: const TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.w400,
            color: Color(0xFF212121),
            letterSpacing: 0.5,
          ),
        ),

        const Spacer(flex: 2),

        // Recording Controls (matching Recorder(Running).svg)
        if (!_isRecording && !_isPaused) ...[
          // Button to start recording on user action
          GestureDetector(
            onTap: _startRecording,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF42A5F5),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF42A5F5).withValues(alpha: 0.35),
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
          // Recording Controls: Stop & Pause / Resume in rounded squircles #42A5F5
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Stop Button (Rounded squircle with white square)
              GestureDetector(
                onTap: _stopRecording,
                child: Container(
                  width: 86,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Pause / Resume Button (Rounded squircle with pause icon)
              GestureDetector(
                onTap: _togglePauseResume,
                child: Container(
                  width: 86,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5),
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

        const SizedBox(height: 24),

        // Live Transcript Peek Banner / Swipe Prompt
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              _pageController.animateToPage(
                1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _liveTranscript.isNotEmpty ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _liveTranscript.isNotEmpty ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _liveTranscript.isNotEmpty ? Icons.record_voice_over_rounded : Icons.swipe_left_rounded,
                    size: 20,
                    color: const Color(0xFF58ACF6),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _liveTranscript.isNotEmpty
                          ? 'Transkrip: "${_liveTranscript.length > 36 ? "${_liveTranscript.substring(_liveTranscript.length - 36)}..." : _liveTranscript}"'
                          : 'Geser ke kanan untuk melihat Auto Transkrip →',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _liveTranscript.isNotEmpty ? const Color(0xFF1E40AF) : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: Color(0xFF58ACF6),
                  ),
                ],
              ),
            ),
          ),
        ),

        const Spacer(flex: 1),
      ],
    );
  }

  // Page 1: Auto Transkrip (Live Real-time Transcript Viewer & Editor)
  Widget _buildTranscriptPage() {
    final transcriptText = _transcriptTextController.text.trim().isNotEmpty
        ? _transcriptTextController.text.trim()
        : _liveTranscript.trim();

    final wordCount = transcriptText.isEmpty ? 0 : transcriptText.split(RegExp(r'\s+')).length;
    final charCount = transcriptText.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Status & Action Toolbar Row
          Row(
            children: [
              // Real-time status pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isRecording
                      ? (_isPaused ? const Color(0xFFFEF3C7) : const Color(0xFFECFDF5))
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isRecording
                        ? (_isPaused ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0))
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isRecording
                            ? (_isPaused ? const Color(0xFFD97706) : const Color(0xFF10B981))
                            : const Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isRecording
                          ? (_isPaused ? 'Perekaman Dijeda' : 'Mentranskrip Suara...')
                          : 'Belum Mulai Merekam',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _isRecording
                            ? (_isPaused ? const Color(0xFFB45309) : const Color(0xFF047857))
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Copy button
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _copyTranscript,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.copy_rounded, size: 14, color: Color(0xFF0F172A)),
                      SizedBox(width: 4),
                      Text(
                        'Salin',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Main Transcript Area
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: transcriptText.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFF58ACF6).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.record_voice_over_rounded,
                              color: Color(0xFF58ACF6),
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Belum Ada Suara Terdeteksi',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'Bicaralah dengan jelas ke mikrofon. Suara akan otomatis dicatat menjadi teks secara langsung di sini.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                height: 1.5,
                              ),
                            ),
                          ),
                          if (!_isRecording) ...[
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                              onPressed: _startRecording,
                              icon: const Icon(Icons.mic_rounded, size: 18),
                              label: const Text('Mulai Merekam'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF58ACF6),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Word & Char counter chip
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$wordCount kata • $charCount karakter',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                              ),
                            ),
                            const Spacer(),
                            const Text(
                              'Dapat diedit langsung',
                              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                        const Divider(height: 20, thickness: 1, color: Color(0xFFE2E8F0)),

                        // Scrollable text field for reading and editing
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _transcriptScrollController,
                            child: TextField(
                              controller: _transcriptTextController,
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.6,
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w400,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 12),

          // Bottom Mini Control Bar on Transcript Page
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                // Back to Controls button
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    _pageController.animateToPage(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_ios_rounded, size: 14, color: Color(0xFF58ACF6)),
                      SizedBox(width: 4),
                      Text(
                        'Kembali ke Kontrol',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF58ACF6)),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Mini Timer
                Text(
                  _formatTimer(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: 0.5,
                  ),
                ),

                if (_isRecording) ...[
                  const SizedBox(width: 14),
                  // Mini Pause/Resume
                  InkWell(
                    onTap: _togglePauseResume,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Color(0xFF58ACF6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Mini Stop
                  InkWell(
                    onTap: _stopRecording,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.stop_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildWaveformBars() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const barWidth = 3.0;
        const spacing = 4.0;
        final halfWidth = constraints.maxWidth / 2;
        final maxBars = (halfWidth / (barWidth + spacing)).floor();

        // Get the latest recorded amplitudes that fit within the left half
        List<double> bars = List<double>.from(_waveAmplitudes);
        if (bars.length > maxBars) {
          bars = bars.sublist(bars.length - maxBars);
        } else {
          while (bars.length < maxBars) {
            bars.insert(0, 0.05);
          }
        }

        return Row(
          children: [
            // Left Half: audio bars aligned to the right (adjacent to the center needle)
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: bars.map((amp) {
                  final barHeight = (amp * 160).clamp(6.0, 160.0);

                  return Container(
                    width: barWidth,
                    height: barHeight,
                    margin: const EdgeInsets.symmetric(horizontal: spacing / 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B2041),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  );
                }).toList(),
              ),
            ),
            // Right Half: Blank/empty upcoming timeline
            const Expanded(
              child: SizedBox(),
            ),
          ],
        );
      },
    );
  }
}

// Audio Ruler with fine vertical tick marks matching Recorder(Running).svg
class _AudioRuler extends StatelessWidget {
  final bool isTop;

  const _AudioRuler({required this.isTop});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 19,
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
    final majorPaint = Paint()
      ..color = const Color(0xFF42A5F5)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.square;

    final minorPaint = Paint()
      ..color = const Color(0xFF42A5F5)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.square;

    const tickSpacing = 5.0;
    final totalTicks = (size.width / tickSpacing).ceil();

    for (int i = 0; i <= totalTicks; i++) {
      final x = i * tickSpacing;
      final isMajor = i % 4 == 0; // Every 20px (0, 20, 40, 60...)
      final tickHeight = isMajor ? 17.0 : 12.0;
      final paint = isMajor ? majorPaint : minorPaint;

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

  AutoTagResult? _autoTagResult;
  bool _isLoadingAutoTag = false;

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

    // Auto-fetch AI course recommendation if not preselected and transcript is available
    if (_selectedCourseId == null && widget.initialTranscript.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchAutoTagSuggestion();
      });
    }
  }

  Future<void> _fetchAutoTagSuggestion() async {
    final text = widget.initialTranscript.trim();
    if (text.isEmpty) return;

    setState(() => _isLoadingAutoTag = true);
    try {
      final res = await ref.read(notesListProvider.notifier).suggestCourse(content: text);
      if (mounted && res != null && res.suggestedCourseId != null) {
        setState(() {
          _autoTagResult = res;
          _selectedCourseId = res.suggestedCourseId;
          _isLoadingAutoTag = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingAutoTag = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAutoTag = false);
    }
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
      final isWav = widget.filePath.toLowerCase().endsWith('.wav');
      final mimeType = isWav ? 'audio/wav' : 'audio/m4a';

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
            mimeType: mimeType,
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

            // AI Course Recommendation Card
            if (_isLoadingAutoTag)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF16A34A)),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'AI sedang mencocokkan mata kuliah dari transkrip...',
                        style: TextStyle(fontSize: 12, color: Color(0xFF15803D)),
                      ),
                    ),
                  ],
                ),
              )
            else if (_autoTagResult != null && _autoTagResult!.suggestedCourseId != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Saran AI Berdasarkan Transkrip',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E40AF),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _autoTagResult!.isTimeMatched
                                ? 'Jadwal Hari Ini'
                                : '${(_autoTagResult!.confidenceScore > 1 ? _autoTagResult!.confidenceScore : _autoTagResult!.confidenceScore * 100).toInt()}% Cocok',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _autoTagResult!.suggestedCourseName ?? 'Mata Kuliah',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (_autoTagResult!.matchedKeywords.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _autoTagResult!.matchedKeywords
                            .take(4)
                            .map(
                              (kw) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Text(
                                  kw,
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),

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
