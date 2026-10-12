import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../notes/models/note_model.dart';
import '../../notes/providers/notes_provider.dart';
import '../../notes/screens/note_detail_screen.dart';
import '../../notes/screens/voice_capture_screen.dart';
import '../../rps/screens/rps_upload_screen.dart';
import '../../schedules/models/schedule_model.dart';
import '../../schedules/providers/schedules_provider.dart';
import '../../schedules/screens/schedule_form_screen.dart';
import '../providers/courses_provider.dart';
import 'course_form_screen.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  final String courseId;

  const CourseDetailScreen({super.key, required this.courseId});

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _uploadDocumentForCourse(String courseId) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt'],
    );

    if (files.isNotEmpty && files.first.path != null && mounted) {
      final file = files.first;
      final titleController = TextEditingController(
        text: file.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''),
      );

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Unggah Dokumen Materi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Berkas: ${file.name}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Judul Dokumen',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Unggah'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mengunggah dokumen materi...')),
        );
        try {
          await ref.read(notesListProvider.notifier).uploadDocument(
                filePath: file.path!,
                fileName: file.name,
                title: titleController.text.trim().isNotEmpty
                    ? titleController.text.trim()
                    : file.name,
                courseId: courseId,
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
                content: Text('Gagal mengunggah: $e'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesListProvider);
    final schedules = ref.watch(schedulesListProvider).value ?? [];
    final notes = ref.watch(notesListProvider).value ?? [];

    return coursesAsync.when(
      data: (courses) {
        final course = courses.where((c) => c.id == widget.courseId).firstOrNull;

        if (course == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detail Mata Kuliah')),
            body: const Center(child: Text('Mata kuliah tidak ditemukan')),
          );
        }

        final color = AppColors.fromHex(course.colorCode);
        final courseSchedules =
            schedules.where((s) => s.courseId == course.id).toList()
              ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
        final courseNotes = notes.where((n) => n.courseId == course.id).toList();

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
            title: Text(
              course.name,
              style: const TextStyle(
                color: Color(0xFF212121),
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF42A5F5)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CourseFormScreen(initialCourse: course),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text('Hapus Mata Kuliah?', style: TextStyle(fontWeight: FontWeight.bold)),
                      content: const Text(
                        'Menghapus mata kuliah akan menghapus jadwal terkait. Catatan yang sudah dibuat akan tetap tersimpan sebagai catatan lepas.',
                      ),
                      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
                          child: const Text('Batal'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Hapus'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    final ok = await ref
                        .read(coursesListProvider.notifier)
                        .deleteCourse(course.id);
                    if (ok && context.mounted) {
                      Navigator.pop(context);
                    }
                  }
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF42A5F5),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF42A5F5),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: [
                const Tab(text: 'Ringkasan'),
                Tab(text: 'Jadwal (${courseSchedules.length})'),
                Tab(text: 'Catatan (${courseNotes.length})'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // TAB 1: Ringkasan & Jam Kuliah
              ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // Course Header Card
                  Container(
                    padding: const EdgeInsets.all(20),
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
                        Row(
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              course.code ?? 'Mata Kuliah',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          course.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (course.lecturer != null && course.lecturer!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.person_outline,
                                  size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                'Dosen: ${course.lecturer}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // RPS Extractor CTA Banner
                  Container(
                    padding: const EdgeInsets.all(18),
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
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.picture_as_pdf_rounded,
                                color: Color(0xFF2563EB),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ekstrak Jadwal dari PDF RPS',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF1E40AF),
                                    ),
                                  ),
                                  Text(
                                    'Unggah RPS untuk otomatis membuat 16 pertemuan kuliah.',
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
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF42A5F5),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      RpsUploadScreen(initialCourseId: course.id),
                                ),
                              );
                            },
                            icon: const Icon(Icons.upload_file_rounded, size: 18),
                            label: const Text('Unggah RPS Kuliah Ini', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Weekly Slots Section
                  const Text(
                    'Jadwal Kuliah Mingguan',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (course.slots.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEEEEEE)),
                      ),
                      child: const Text(
                        'Belum ada jam kuliah mingguan yang diatur.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    )
                  else
                    ...course.slots.map((s) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFEEEEEE)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.event_seat_rounded, size: 20, color: color),
                              const SizedBox(width: 12),
                              Text(
                                s.dayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF212121),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${s.startTime} - ${s.endTime} WIB',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                ),
                              ),
                              const Spacer(),
                              if (s.room != null && s.room!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    s.room!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )),

                  const SizedBox(height: 24),

                  // Keywords Section
                  const Text(
                    'Kata Kunci Auto-Tag',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (course.keywords.isEmpty)
                    const Text(
                      'Belum ada kata kunci. Kata kunci akan bertambah otomatis saat RPS diekstrak.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: course.keywords.map((kw) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            kw,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),

              // TAB 2: Jadwal & Tugas Kuliah Ini
              ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total ${courseSchedules.length} Jadwal / Tugas',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Tambah Tugas'),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF42A5F5)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ScheduleFormScreen(preselectedCourseId: course.id),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (courseSchedules.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFEEEEEE)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 44, color: Color(0xFFCBD5E1)),
                          SizedBox(height: 12),
                          Text(
                            'Belum ada jadwal untuk mata kuliah ini.',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF212121),
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Unggah RPS atau tambahkan tugas manual.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...courseSchedules.map((schedule) {
                      final isClass = schedule.type == ScheduleType.classType;
                      final dateFormatted = DateFormat('EEE, dd MMM yyyy • HH:mm', 'id')
                          .format(schedule.dueDate.toLocal());

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: schedule.isCompleted
                                ? const Color(0xFFEEEEEE)
                                : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x04000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: schedule.isCompleted,
                              activeColor: const Color(0xFF42A5F5),
                              onChanged: (_) {
                                ref
                                    .read(schedulesListProvider.notifier)
                                    .toggleComplete(schedule.id);
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    schedule.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: schedule.isCompleted
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF212121),
                                      decoration: schedule.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isClass
                                              ? const Color(0xFFE0F2FE)
                                              : const Color(0xFFFFF7ED),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isClass ? 'Kelas' : 'Tugas',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isClass
                                                ? const Color(0xFF0284C7)
                                                : const Color(0xFFEA580C),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        dateFormatted,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),

              // TAB 3: Catatan Suara & Dokumen Materi
              ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF42A5F5),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.mic_rounded, size: 18),
                          label: const Text('Rekam Suara', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    VoiceCaptureScreen(preselectedCourseId: course.id),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF42A5F5),
                            side: const BorderSide(color: Color(0xFF42A5F5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.attach_file_rounded, size: 18),
                          label: const Text('Upload File', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => _uploadDocumentForCourse(course.id),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (courseNotes.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFEEEEEE)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.notes_rounded,
                              size: 44, color: Color(0xFFCBD5E1)),
                          SizedBox(height: 12),
                          Text(
                            'Belum ada catatan untuk mata kuliah ini.',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF212121),
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Rekam suara saat dosen menjelaskan atau unggah slide materi.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...courseNotes.map((note) {
                      final isVoice = note.type == NoteType.voice;
                      final dateFormatted =
                          DateFormat('dd MMM yyyy, HH:mm', 'id')
                              .format(note.createdAt.toLocal());

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEEEEEE)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x04000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NoteDetailScreen(note: note),
                              ),
                            );
                          },
                          leading: CircleAvatar(
                            backgroundColor: isVoice
                                ? const Color(0xFFE0F2FE)
                                : const Color(0xFFE0F2FE),
                            child: Icon(
                              isVoice
                                  ? Icons.mic_rounded
                                  : Icons.description_rounded,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                          title: Text(
                            note.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF212121)),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              if (note.content != null &&
                                  note.content!.isNotEmpty)
                                Text(
                                  note.content!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                dateFormatted,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded,
                              color: Color(0xFF94A3B8)),
                        ),
                      );
                    }),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
    );
  }
}
