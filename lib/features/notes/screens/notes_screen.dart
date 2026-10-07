import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../courses/models/course_model.dart';
import '../../courses/providers/courses_provider.dart';
import '../models/note_model.dart';
import '../providers/notes_provider.dart';
import 'note_detail_screen.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String _filterType = 'ALL'; // ALL, VOICE, DOCUMENT
  String? _filterCourseId;
  String _searchQuery = '';

  Future<void> _pickAndUploadDocument() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'ppt', 'pptx'],
    );

    if (files.isNotEmpty && files.first.path != null && mounted) {
      final file = files.first;
      final titleController = TextEditingController(
        text: file.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''),
      );
      String? selectedCourseId;

      final courses = ref.read(coursesListProvider).value ?? [];

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Upload Dokumen Catatan'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Judul Catatan',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Pilih Mata Kuliah (Opsional):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedCourseId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Tanpa Mata Kuliah'),
                      ),
                      ...courses.map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setDialogState(() => selectedCourseId = val);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Upload'),
              ),
            ],
          ),
        ),
      );

      if (confirmed == true && mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mengunggah dokumen...')),
          );
          await ref.read(notesListProvider.notifier).uploadDocument(
                filePath: file.path!,
                fileName: file.name,
                title: titleController.text.trim(),
                courseId: selectedCourseId,
              );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Dokumen berhasil diunggah!'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Gagal upload: $e'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      }
    }
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic, color: AppColors.primary),
                ),
                title: const Text('Rekam Suara (AI Auto-Tag)'),
                subtitle: const Text('Transkrip otomatis & deteksi mata kuliah'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.push('/notes/voice');
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.upload_file, color: AppColors.secondary),
                ),
                title: const Text('Upload Dokumen'),
                subtitle: const Text('PDF, DOCX materi perkuliahan'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickAndUploadDocument();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesListProvider);
    final courses = ref.watch(coursesListProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan Perkuliahan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(notesListProvider.notifier).loadNotes(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari catatan...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String?>(
                  icon: Icon(
                    Icons.filter_list,
                    color: _filterCourseId != null
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  tooltip: 'Filter Mata Kuliah',
                  onSelected: (val) => setState(() => _filterCourseId = val),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: null,
                      child: Text('Semua Mata Kuliah'),
                    ),
                    ...courses.map(
                      (c) => PopupMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Type Segment Filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildTypeChip('ALL', 'Semua'),
                const SizedBox(width: 8),
                _buildTypeChip('VOICE', 'Suara / AI'),
                const SizedBox(width: 8),
                _buildTypeChip('DOCUMENT', 'Dokumen'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Notes List
          Expanded(
            child: notesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Gagal: $err'),
                    ElevatedButton(
                      onPressed: () =>
                          ref.read(notesListProvider.notifier).loadNotes(),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
              data: (notes) {
                // Apply filters
                final filtered = notes.where((n) {
                  if (_filterType == 'VOICE' && n.type != NoteType.voice) {
                    return false;
                  }
                  if (_filterType == 'DOCUMENT' && n.type != NoteType.document) {
                    return false;
                  }
                  if (_filterCourseId != null && n.courseId != _filterCourseId) {
                    return false;
                  }
                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    final matchTitle = n.title.toLowerCase().contains(q);
                    final matchContent =
                        n.content?.toLowerCase().contains(q) ?? false;
                    return matchTitle || matchContent;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.note_alt_outlined,
                          size: 64,
                          color: AppColors.neutral300,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Belum ada catatan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Rekam suara dosen atau unggah dokumen materi Anda',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/notes/voice'),
                          icon: const Icon(Icons.mic),
                          label: const Text('Mulai Rekam Suara'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final note = filtered[i];
                    return _buildNoteCard(note, courses);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOptions,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Catatan'),
      ),
    );
  }

  Widget _buildTypeChip(String key, String label) {
    final isSelected = _filterType == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filterType = key),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  Widget _buildNoteCard(NoteModel note, List<CourseModel> courses) {
    final course = courses.firstWhere(
      (c) => c.id == note.courseId,
      orElse: () => CourseModel(
        id: '',
        name: note.course?.name ?? 'Tanpa Mata Kuliah',
        colorHex: note.course?.colorHex ?? '#94A3B8',
      ),
    );

    final isVoice = note.type == NoteType.voice;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: AppColors.surfaceVariant,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => NoteDetailScreen(note: note),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Course chip + Type badge
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.fromHex(course.colorHex),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    course.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.fromHex(course.colorHex),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isVoice ? Icons.mic : Icons.description,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isVoice
                        ? (note.durationSeconds != null
                            ? '${note.durationSeconds}s'
                            : 'Voice')
                        : 'Doc',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                note.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),

              // Content snippet
              if (note.content != null && note.content!.isNotEmpty)
                Text(
                  note.content!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),

              const SizedBox(height: 12),

              // Date
              Row(
                children: [
                  Text(
                    DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(note.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.neutral400,
                    ),
                  ),
                  if (note.confidenceScore != null) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'AI: ${(note.confidenceScore! * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
