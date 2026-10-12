import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/config/api_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../../courses/models/course_model.dart';
import '../../courses/providers/courses_provider.dart';
import '../models/note_model.dart';
import '../providers/notes_provider.dart';

class NoteDetailScreen extends ConsumerStatefulWidget {
  final NoteModel note;

  const NoteDetailScreen({
    super.key,
    required this.note,
  });

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  String? _selectedCourseId;
  bool _isSaving = false;
  bool _hasChanges = false;
  bool _isAnalyzingAi = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content ?? '');
    _selectedCourseId = widget.note.courseId;

    _titleController.addListener(_markChanged);
    _contentController.addListener(_markChanged);
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  int get _wordCount {
    final text = _contentController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  int get _charCount => _contentController.text.length;

  Future<void> _copyContentToClipboard() async {
    final text = _contentController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konten catatan masih kosong.')),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transkrip berhasil disalin ke clipboard!'),
          backgroundColor: Color(0xFF1E88E5),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _suggestCourseWithAi() async {
    final text = _contentController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tulis atau rekam konten catatan terlebih dahulu.'),
        ),
      );
      return;
    }

    setState(() => _isAnalyzingAi = true);

    try {
      final result = await ref.read(notesListProvider.notifier).suggestCourse(
            content: text,
            createdAt: widget.note.createdAt,
          );

      if (mounted) {
        setState(() => _isAnalyzingAi = false);

        if (result != null && result.suggestedCourseId != null) {
          final courses = ref.read(coursesListProvider).value ?? [];
          final matchedCourse = courses.firstWhere(
            (c) => c.id == result.suggestedCourseId,
            orElse: () => CourseModel(
              id: result.suggestedCourseId!,
              name: result.suggestedCourseName ?? 'Mata Kuliah',
              colorHex: '#42A5F5',
            ),
          );

          final confidencePercent = (result.confidenceScore * 100).toInt();

          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (ctx) => Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFF1E88E5),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rekomendasi Mata Kuliah AI',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF212121),
                              ),
                            ),
                            Text(
                              'Berdasarkan kata kunci materi dalam catatan',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.fromHex(matchedCourse.colorHex),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            matchedCourse.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF212121),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$confidencePercent% Cocok',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E88E5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedCourseId = matchedCourse.id;
                          _hasChanges = true;
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Mata kuliah diatur ke "${matchedCourse.name}"',
                            ),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF42A5F5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Terapkan Mata Kuliah Ini',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('AI belum menemukan mata kuliah yang cocok.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzingAi = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal analisis AI: $e')),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(notesListProvider.notifier).updateNote(
            id: widget.note.id,
            title: _titleController.text.trim(),
            content: _contentController.text.trim(),
            courseId: _selectedCourseId,
          );
      if (mounted) {
        setState(() {
          _isSaving = false;
          _hasChanges = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Catatan berhasil diperbarui!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _deleteNote() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Hapus Catatan?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Catatan ini beserta file terkait akan dihapus secara permanen.',
          style: TextStyle(color: Color(0xFF64748B), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final ok =
          await ref.read(notesListProvider.notifier).deleteNote(widget.note.id);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Catatan dihapus.')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(coursesListProvider).value ?? [];
    final currentCourse = courses.firstWhere(
      (c) => c.id == _selectedCourseId,
      orElse: () => CourseModel(
        id: '',
        name: 'Tanpa Mata Kuliah',
        colorHex: '#94A3B8',
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Detail Catatan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF212121),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF212121)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_hasChanges)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF42A5F5),
                      ),
                    )
                  : const Icon(Icons.check_rounded, color: Color(0xFF42A5F5), size: 26),
              tooltip: 'Simpan Perubahan',
              onPressed: _isSaving ? null : _saveChanges,
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
            tooltip: 'Hapus',
            onPressed: _deleteNote,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Metadata chips row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Course tag picker dropdown/chip
                PopupMenuButton<String?>(
                  tooltip: 'Ganti Mata Kuliah',
                  onSelected: (val) {
                    setState(() {
                      _selectedCourseId = val;
                      _hasChanges = true;
                    });
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: null,
                      child: Text('Tanpa Mata Kuliah'),
                    ),
                    ...courses.map(
                      (c) => PopupMenuItem(
                        value: c.id,
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: AppColors.fromHex(c.colorHex),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(c.name),
                          ],
                        ),
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.fromHex(currentCourse.colorHex),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currentCourse.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Color(0xFF212121),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),
                ),

                // Note Type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.note.type == NoteType.voice
                            ? Icons.mic_rounded
                            : Icons.description_rounded,
                        size: 13,
                        color: const Color(0xFF1E88E5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.note.type == NoteType.voice ? 'Voice' : 'Dokumen',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E88E5),
                        ),
                      ),
                    ],
                  ),
                ),

                // Duration badge if voice
                if (widget.note.durationSeconds != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 13,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.note.durationSeconds} dtk',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Date badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    DateFormat('d MMM yyyy, HH:mm', 'id_ID')
                        .format(widget.note.createdAt.toLocal()),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: TextField(
                controller: _titleController,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF212121),
                ),
                decoration: const InputDecoration(
                  hintText: 'Judul catatan perkuliahan...',
                  hintStyle: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // If Voice note with audio file, show Audio Player Card
            if (widget.note.type == NoteType.voice &&
                widget.note.fileUrl != null &&
                widget.note.fileUrl!.isNotEmpty)
              _VoiceNotePlayerCard(
                audioUrl: widget.note.fileUrl!,
                fallbackDurationSeconds: widget.note.durationSeconds,
              ),

            // If Document, show file card
            if (widget.note.type == NoteType.document &&
                widget.note.fileName != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Color(0xFF1E88E5),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.note.fileName ?? 'File Dokumen',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF212121),
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (widget.note.fileSize != null)
                            Text(
                              '${(widget.note.fileSize! / 1024).toStringAsFixed(1)} KB',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Content / Transcript Card with Header Actions
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEEEEEE)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Transcript Toolbar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(
                      children: [
                        const Text(
                          'Transkrip / Isi Catatan',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF212121),
                          ),
                        ),
                        const Spacer(),
                        // Word Count chip
                        Text(
                          '$_wordCount kata • $_charCount karakter',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Copy Button
                        GestureDetector(
                          onTap: _copyContentToClipboard,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.copy_rounded,
                                  size: 13,
                                  color: Color(0xFF475569),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Salin',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // AI Suggest Button
                        GestureDetector(
                          onTap: _isAnalyzingAi ? null : _suggestCourseWithAi,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isAnalyzingAi)
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: Color(0xFF1E88E5),
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 13,
                                    color: Color(0xFF1E88E5),
                                  ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Saran AI',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E88E5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),

                  // Text Editor Area
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _contentController,
                      maxLines: null,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Color(0xFF212121),
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Belum ada konten transkrip atau catatan...',
                        hintStyle: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _VoiceNotePlayerCard extends ConsumerStatefulWidget {
  final String audioUrl;
  final int? fallbackDurationSeconds;

  const _VoiceNotePlayerCard({
    required this.audioUrl,
    this.fallbackDurationSeconds,
  });

  @override
  ConsumerState<_VoiceNotePlayerCard> createState() => _VoiceNotePlayerCardState();
}

class _VoiceNotePlayerCardState extends ConsumerState<_VoiceNotePlayerCard> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isSourceSet = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initAudioPlayer();
    if (widget.fallbackDurationSeconds != null) {
      _duration = Duration(seconds: widget.fallbackDurationSeconds!);
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
        setState(() => _position = pos);
      }
    });

    _player.onDurationChanged.listen((dur) {
      if (mounted) {
        setState(() => _duration = dur);
      }
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (!_isSourceSet) {
        final storage = ref.read(storageServiceProvider);
        final resolvedUrl = ApiConfig.resolveMediaUrl(
          widget.audioUrl,
          customBaseUrl: storage.getBaseUrl(),
        );

        if (resolvedUrl.startsWith('http://') || resolvedUrl.startsWith('https://')) {
          await _player.play(UrlSource(resolvedUrl));
        } else {
          await _player.play(DeviceFileSource(resolvedUrl));
        }
        _isSourceSet = true;
      } else {
        await _player.resume();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = _duration.inMilliseconds > 0
        ? _duration.inMilliseconds
        : (widget.fallbackDurationSeconds ?? 0) * 1000;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: _togglePlay,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFF42A5F5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rekaman Audio Kuliah',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic_rounded, size: 14, color: Color(0xFF42A5F5)),
                    SizedBox(width: 4),
                    Text(
                      'Audio',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF42A5F5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (totalMs > 0) ...[
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3.5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: const Color(0xFF42A5F5),
                inactiveTrackColor: const Color(0xFFCBD5E1),
                thumbColor: const Color(0xFF42A5F5),
              ),
              child: Slider(
                min: 0.0,
                max: totalMs.toDouble(),
                value: _position.inMilliseconds
                    .toDouble()
                    .clamp(0.0, totalMs.toDouble()),
                onChanged: (val) async {
                  final target = Duration(milliseconds: val.toInt());
                  await _player.seek(target);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
