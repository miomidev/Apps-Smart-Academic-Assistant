import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
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
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteNote() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Catatan?'),
        content: const Text(
          'Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
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
      appBar: AppBar(
        title: const Text('Detail Catatan'),
        actions: [
          if (_hasChanges)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check, color: AppColors.primary),
              tooltip: 'Simpan Perubahan',
              onPressed: _isSaving ? null : _saveChanges,
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
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
                  child: Chip(
                    avatar: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.fromHex(currentCourse.colorHex),
                        shape: BoxShape.circle,
                      ),
                    ),
                    label: Text(
                      currentCourse.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    deleteIcon: const Icon(Icons.arrow_drop_down, size: 18),
                    onDeleted: () {},
                  ),
                ),

                // Note Type badge
                Chip(
                  avatar: Icon(
                    widget.note.type == NoteType.voice
                        ? Icons.mic
                        : Icons.description,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  label: Text(
                    widget.note.type == NoteType.voice ? 'Voice' : 'Dokumen',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                ),

                // Duration badge if voice
                if (widget.note.durationSeconds != null)
                  Chip(
                    avatar: const Icon(Icons.timer_outlined, size: 14),
                    label: Text(
                      '${widget.note.durationSeconds} dtk',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),

                // Date badge
                Chip(
                  label: Text(
                    DateFormat('d MMM yyyy, HH:mm', 'id_ID')
                        .format(widget.note.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  backgroundColor: AppColors.neutral200,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title
            TextField(
              controller: _titleController,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Judul catatan...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const Divider(height: 24),

            // If Document, show file card
            if (widget.note.type == NoteType.document &&
                widget.note.fileName != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.neutral200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.note.fileName ?? 'File Dokumen',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (widget.note.fileSize != null)
                            Text(
                              '${(widget.note.fileSize! / 1024).toStringAsFixed(1)} KB',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
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

            // Content / Transcript Editor
            const Text(
              'Transkrip / Isi Catatan:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.neutral200),
              ),
              child: TextField(
                controller: _contentController,
                maxLines: null,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Belum ada konten transkrip...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
