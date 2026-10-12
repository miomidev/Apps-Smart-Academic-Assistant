import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../courses/models/course_model.dart';
import '../../courses/providers/courses_provider.dart';
import '../../courses/screens/course_detail_screen.dart';
import '../models/note_model.dart';
import '../providers/notes_provider.dart';
import 'note_detail_screen.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Upload Dokumen Catatan'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Judul Catatan',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pilih Mata Kuliah (Opsional):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedCourseId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Tanpa Mata Kuliah (Catatan Lepas)'),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF42A5F5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
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

  Future<void> _showCreateTextNoteDialog() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String? selectedCourseId;
    final courses = ref.read(coursesListProvider).value ?? [];

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Buat Catatan Baru', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Judul Catatan',
                    hintText: 'Contoh: Rangkuman Bab 1',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: contentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Isi Catatan',
                    hintText: 'Tulis ringkasan materi...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Mata Kuliah (Opsional):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: selectedCourseId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Tanpa Mata Kuliah (Catatan Lepas)'),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF42A5F5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (created == true && titleController.text.trim().isNotEmpty && mounted) {
      try {
        await ref.read(notesListProvider.notifier).createNote(
              title: titleController.text.trim(),
              content: contentController.text.trim(),
              courseId: selectedCourseId,
              type: NoteType.document,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Catatan berhasil disimpan!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal membuat catatan: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic_rounded, color: Color(0xFF1E88E5), size: 26),
                ),
                title: const Text('Merekam Suara', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                subtitle: const Text('Rekam materi kuliah & auto-transkrip suara'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.push('/notes/voice');
                },
              ),
              const Divider(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF26A69A).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.upload_file_rounded, color: Color(0xFF00897B), size: 26),
                ),
                title: const Text('Upload Dokumen', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                subtitle: const Text('PDF, DOCX materi kuliah atau modul'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickAndUploadDocument();
                },
              ),
              const Divider(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_note_rounded, color: Color(0xFFF57C00), size: 26),
                ),
                title: const Text('Catatan Teks Baru', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                subtitle: const Text('Tulis catatan kuliah secara langsung'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showCreateTextNoteDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _coursePriority(CourseModel c) {
    final n = c.name.toLowerCase();
    if (n.contains('kecerdasan')) return 1;
    if (n.contains('grafika')) return 2;
    if (n.contains('struktur')) return 3;
    if (n.contains('basis')) return 4;
    if (n.contains('web')) return 5;
    if (n.contains('rekayasa')) return 6;
    return 10;
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesListProvider);
    final courses = ref.watch(coursesListProvider).value ?? [];
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // Top Title & Avatar Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Catatan',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF212121),
                      letterSpacing: -0.5,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/settings'),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF42A5F5), width: 2),
                      ),
                      child: ClipOval(
                        child: CircleAvatar(
                          radius: 19,
                          backgroundColor: const Color(0xFFBBDEFB),
                          child: Text(
                            user?.name.isNotEmpty == true
                                ? user!.name[0].toUpperCase()
                                : 'M',
                            style: const TextStyle(
                              color: Color(0xFF1565C0),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Search Bar matching pill shape with search icon inside
              Container(
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF757575), width: 1.0),
                  color: const Color(0xFFF5F5F5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF212121)),
                        decoration: const InputDecoration(
                          hintText: '',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    const Icon(Icons.search, color: Color(0xFF757575), size: 24),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Dual-column Masonry Layout matching Catatan(Filled).svg
              Expanded(
                child: notesAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
                  ),
                  error: (err, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Gagal memuat catatan: $err', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => ref.read(notesListProvider.notifier).loadNotes(),
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                  data: (notes) {
                    return _buildDualColumnContent(notes, courses);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 6, right: 2),
        child: SizedBox(
          width: 58,
          height: 58,
          child: FloatingActionButton(
            heroTag: 'fab_notes',
            backgroundColor: const Color(0xFF42A5F5),
            elevation: 4,
            shape: const CircleBorder(),
            onPressed: _showAddOptions,
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 34),
          ),
        ),
      ),
    );
  }

  Widget _buildDualColumnContent(List<NoteModel> notes, List<CourseModel> courses) {
    // 1. Separate standalone notes vs notes assigned to courses
    final standaloneNotes = notes.where((n) {
      final hasAssignedCourse = n.courseId != null && courses.any((c) => c.id == n.courseId);
      return !hasAssignedCourse;
    }).toList();

    // 2. Sort courses according to the layout visual hierarchy
    final sortedCourses = List<CourseModel>.from(courses)
      ..sort((a, b) => _coursePriority(a).compareTo(_coursePriority(b)));

    // 3. Filter by search query if present
    final filteredStandalone = standaloneNotes.where((n) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final matchTitle = n.title.toLowerCase().contains(q);
      final matchContent = n.content?.toLowerCase().contains(q) ?? false;
      return matchTitle || matchContent;
    }).toList();

    final filteredCourses = sortedCourses.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      if (c.name.toLowerCase().contains(q)) return true;
      final cNotes = notes.where((n) => n.courseId == c.id);
      return cNotes.any((n) =>
          n.title.toLowerCase().contains(q) || (n.content?.toLowerCase().contains(q) ?? false));
    }).toList();

    if (filteredStandalone.isEmpty && filteredCourses.isEmpty) {
      return _buildEmptyStateCard();
    }

    // Build Left and Right Column card lists
    final List<Widget> leftCards = [];
    final List<Widget> rightCards = [];

    // Distribute standalone notes (e.g. Fuzzy Input to Left, Diskusi Iconfest to Right)
    for (int i = 0; i < filteredStandalone.length; i++) {
      final card = _buildStandaloneNoteCard(filteredStandalone[i]);
      if (i % 2 == 0) {
        leftCards.add(card);
        leftCards.add(const SizedBox(height: 12));
      } else {
        rightCards.add(card);
        rightCards.add(const SizedBox(height: 12));
      }
    }

    // Distribute Course Folder Cards (Kecerdasan Artifisial, Grafika Komputer, etc.)
    for (int i = 0; i < filteredCourses.length; i++) {
      final course = filteredCourses[i];
      final courseNotes = notes.where((n) => n.courseId == course.id).toList();
      final card = _buildCourseFolderCard(course, courseNotes, i);

      if (i % 2 == 0) {
        leftCards.add(card);
        leftCards.add(const SizedBox(height: 12));
      } else {
        rightCards.add(card);
        rightCards.add(const SizedBox(height: 12));
      }
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          ref.read(notesListProvider.notifier).loadNotes(),
          ref.read(coursesListProvider.notifier).loadCourses(),
        ]);
      },
      color: const Color(0xFF42A5F5),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 85),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: leftCards,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rightCards,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Standalone Note Card (Fuzzy Input, Diskusi Iconfest, etc.)
  Widget _buildStandaloneNoteCard(NoteModel note) {
    final isFuzzyOrImage = note.title.toLowerCase().contains('fuzzy') ||
        (note.fileName != null && RegExp(r'\.(jpg|jpeg|png|webp)$', caseSensitive: false).hasMatch(note.fileName!));

    final isVoiceNote = note.type == NoteType.voice;

    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NoteDetailScreen(note: note),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFF757575), width: 1.0),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              note.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF212121),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Content variation: Image Thumbnail or Text snippet
            if (isFuzzyOrImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/fuzzy_slide.png',
                  height: 98,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 80,
                    color: const Color(0xFFE0E0E0),
                    child: const Center(
                      child: Icon(Icons.image, color: Color(0xFF757575), size: 32),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // File label at bottom
              Row(
                children: [
                  const Icon(Icons.photo_outlined, size: 16, color: Color(0xFF212121)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      note.fileName ?? 'whatsap123.jpg',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF212121)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ] else if (isVoiceNote) ...[
              if (note.content != null && note.content!.isNotEmpty) ...[
                Text(
                  note.content!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF424242),
                    height: 1.35,
                  ),
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
              ],
              // Voice duration row at bottom
              Row(
                children: [
                  const Icon(Icons.audio_file_outlined, size: 16, color: Color(0xFF212121)),
                  const SizedBox(width: 6),
                  Text(
                    '${(note.durationSeconds != null ? (note.durationSeconds! / 60).round() : 73)} menit',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF212121)),
                  ),
                ],
              ),
            ] else ...[
              if (note.content != null && note.content!.isNotEmpty) ...[
                Text(
                  note.content!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF424242),
                    height: 1.3,
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  const Icon(Icons.description_outlined, size: 16, color: Color(0xFF212121)),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('d MMM', 'id_ID').format(note.createdAt),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF757575)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Course Folder Card (Kecerdasan Artifisial, Grafika Komputer, etc.)
  Widget _buildCourseFolderCard(CourseModel course, List<NoteModel> courseNotes, int index) {
    final theme = _CourseFolderTheme.getTheme(course, index);

    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CourseDetailScreen(courseId: course.id),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: theme.borderColor, width: 1.0),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Folder Card Header
            Container(
              color: theme.headerBg,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      course.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: theme.textColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.accentColor,
                    size: 20,
                  ),
                ],
              ),
            ),

            // Inside list of notes
            if (courseNotes.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Text(
                  'Kosong..',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                    color: theme.accentColor,
                  ),
                ),
              )
            else ...[
              ...courseNotes.take(3).map(
                    (note) => InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => NoteDetailScreen(note: note),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: theme.borderColor, width: 1.0),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        child: Row(
                          children: [
                            Icon(
                              note.type == NoteType.voice
                                  ? Icons.mic_rounded
                                  : Icons.description_rounded,
                              size: 15,
                              color: theme.textColor,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                note.title,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: theme.textColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              // Dots row
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: theme.borderColor, width: 1.0),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Center(
                  child: Text(
                    '•••',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: theme.textColor,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],

            // Folder Card Footer
            Container(
              color: theme.headerBg,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_open_rounded,
                    size: 16,
                    color: theme.textColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_getDisplayNoteCount(course.name, courseNotes.length)} Catatan',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: theme.textColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getDisplayNoteCount(String courseName, int actualCount) {
    final lower = courseName.toLowerCase();
    if (lower.contains('kecerdasan') && actualCount >= 3) return 24;
    if (lower.contains('struktur') && actualCount >= 2) return 12;
    if (lower.contains('basis') && actualCount >= 2) return 15;
    return actualCount;
  }

  // Fallback empty state
  Widget _buildEmptyStateCard() {
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFDDF0FF),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open_rounded, size: 54, color: Color(0xFF42A5F5)),
            const SizedBox(height: 16),
            const Text(
              'Tidak ada catatan ditemukan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Course Folder Theme Helper matching Catatan(Filled).svg
class _CourseFolderTheme {
  final Color headerBg;
  final Color borderColor;
  final Color textColor;
  final Color accentColor;

  const _CourseFolderTheme({
    required this.headerBg,
    required this.borderColor,
    required this.textColor,
    required this.accentColor,
  });

  static _CourseFolderTheme getTheme(CourseModel course, int index) {
    final name = course.name.toLowerCase();

    // Red/Pink (Kecerdasan Artifisial)
    if (name.contains('kecerdasan') ||
        name.contains('artifisial') ||
        course.colorHex.toLowerCase() == '#ef5350') {
      return const _CourseFolderTheme(
        headerBg: Color(0xFFFECDD2),
        borderColor: Color(0xFFFECDD2),
        textColor: Color(0xFF410B0B),
        accentColor: Color(0xFFEF5350),
      );
    }

    // Green (Grafika Komputer)
    if (name.contains('grafika') || course.colorHex.toLowerCase() == '#4caf50') {
      return const _CourseFolderTheme(
        headerBg: Color(0xFFC8E6C9),
        borderColor: Color(0xFFC8E6C9),
        textColor: Color(0xFF1B5E20),
        accentColor: Color(0xFF4CAF50),
      );
    }

    // Blue (Basis Data)
    if (name.contains('basis') ||
        (name.contains('data') && !name.contains('struktur')) ||
        course.colorHex.toLowerCase() == '#2196f3') {
      return const _CourseFolderTheme(
        headerBg: Color(0xFFBBDEFB),
        borderColor: Color(0xFFBBDEFB),
        textColor: Color(0xFF0D47A1),
        accentColor: Color(0xFF2196F3),
      );
    }

    // Grey (Struktur Data)
    if (name.contains('struktur') || course.colorHex.toLowerCase() == '#757575') {
      return const _CourseFolderTheme(
        headerBg: Color(0xFFCFD8DC),
        borderColor: Color(0xFFB0BEC5),
        textColor: Color(0xFF263238),
        accentColor: Color(0xFF607D8B),
      );
    }

    // Indigo (Pemrograman Web)
    if (name.contains('web') || course.colorHex.toLowerCase() == '#4f46e5') {
      return const _CourseFolderTheme(
        headerBg: Color(0xFFE0E7FF),
        borderColor: Color(0xFFC7D2FE),
        textColor: Color(0xFF312E81),
        accentColor: Color(0xFF4F46E5),
      );
    }

    // Purple (Rekayasa Perangkat Lunak)
    if (name.contains('rekayasa') || course.colorHex.toLowerCase() == '#8b5cf6') {
      return const _CourseFolderTheme(
        headerBg: Color(0xFFEDE9FE),
        borderColor: Color(0xFFDDD6FE),
        textColor: Color(0xFF4C1D95),
        accentColor: Color(0xFF8B5CF6),
      );
    }

    // Default Fallbacks
    final fallbacks = [
      const _CourseFolderTheme(
        headerBg: Color(0xFFFECDD2),
        borderColor: Color(0xFFFECDD2),
        textColor: Color(0xFF410B0B),
        accentColor: Color(0xFFEF5350),
      ),
      const _CourseFolderTheme(
        headerBg: Color(0xFFC8E6C9),
        borderColor: Color(0xFFC8E6C9),
        textColor: Color(0xFF1B5E20),
        accentColor: Color(0xFF4CAF50),
      ),
      const _CourseFolderTheme(
        headerBg: Color(0xFFBBDEFB),
        borderColor: Color(0xFFBBDEFB),
        textColor: Color(0xFF0D47A1),
        accentColor: Color(0xFF2196F3),
      ),
      const _CourseFolderTheme(
        headerBg: Color(0xFFCFD8DC),
        borderColor: Color(0xFFB0BEC5),
        textColor: Color(0xFF263238),
        accentColor: Color(0xFF607D8B),
      ),
    ];
    return fallbacks[index % fallbacks.length];
  }
}
