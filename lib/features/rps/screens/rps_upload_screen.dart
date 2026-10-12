import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../courses/models/course_model.dart';
import '../../courses/providers/courses_provider.dart';
import '../providers/rps_provider.dart';
import 'rps_review_screen.dart';

class RpsUploadScreen extends ConsumerStatefulWidget {
  final String? initialCourseId;

  const RpsUploadScreen({
    super.key,
    this.initialCourseId,
  });

  @override
  ConsumerState<RpsUploadScreen> createState() => _RpsUploadScreenState();
}

class _RpsUploadScreenState extends ConsumerState<RpsUploadScreen> {
  String? _selectedCourseId;
  PlatformFile? _selectedFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedCourseId = widget.initialCourseId;
  }

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (files.isNotEmpty) {
      setState(() {
        _selectedFile = files.first;
      });
    }
  }

  int? _getFileSize() {
    if (_selectedFile?.path != null) {
      try {
        return File(_selectedFile!.path!).lengthSync();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _processRps() async {
    if (_selectedCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih mata kuliah terlebih dahulu.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (_selectedFile == null || _selectedFile!.path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih file RPS format PDF terlebih dahulu.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final extractionResult =
          await ref.read(rpsExtractionProvider.notifier).parseRpsPdf(
                courseId: _selectedCourseId!,
                filePath: _selectedFile!.path!,
                fileName: _selectedFile!.name,
              );

      if (mounted && extractionResult != null) {
        setState(() => _isLoading = false);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => RpsReviewScreen(
              courseId: _selectedCourseId!,
              extractionResult: extractionResult,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekstrak RPS: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(coursesListProvider).value ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Ekstraksi Dokumen RPS',
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
      ),
      body: _isLoading
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE3F2FD),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Color(0xFF42A5F5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'AI sedang mengekstrak RPS...',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Menganalisis 16 pertemuan perkuliahan, CPMK, topik materi, dan deadline tugas...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info banner AI Auto-Scheduler
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFF1E88E5),
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Auto-Scheduler dari RPS',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Unggah dokumen RPS format PDF dari dosen. AI kami akan otomatis membedah 16 pertemuan dan tugas langsung ke kalender akademik Anda.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF475569),
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Main Card Form
                  Container(
                    padding: const EdgeInsets.all(20),
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
                        // Select Course
                        const Text(
                          'Mata Kuliah Target',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF212121),
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCourseId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            hintText: 'Pilih mata kuliah target...',
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFF42A5F5)),
                            ),
                            prefixIcon: const Icon(
                              Icons.school_outlined,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          items: courses.map((CourseModel c) {
                            return DropdownMenuItem<String>(
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
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      c.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF212121),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedCourseId = val),
                        ),
                        const SizedBox(height: 24),

                        // Upload Box
                        const Text(
                          'Dokumen RPS (.PDF)',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF212121),
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _pickFile,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 28,
                              horizontal: 20,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedFile != null
                                  ? const Color(0xFFF0FDF4)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _selectedFile != null
                                    ? const Color(0xFF86EFAC)
                                    : const Color(0xFFCBD5E1),
                                width: _selectedFile != null ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: _selectedFile != null
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFE3F2FD),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _selectedFile != null
                                        ? Icons.picture_as_pdf_rounded
                                        : Icons.cloud_upload_outlined,
                                    size: 30,
                                    color: _selectedFile != null
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFF42A5F5),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _selectedFile != null
                                      ? _selectedFile!.name
                                      : 'Ketuk untuk memilih file PDF RPS',
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: _selectedFile != null
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFF212121),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (_selectedFile != null) ...[
                                  if (_getFileSize() != null)
                                    Text(
                                      _formatFileSize(_getFileSize()!),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ] else
                                  const Text(
                                    'Mendukung format standar RPS Universitas (.pdf)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                if (_selectedFile != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFF86EFAC),
                                      ),
                                    ),
                                    child: const Text(
                                      'Ketuk untuk mengganti file',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF16A34A),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _processRps,
                      icon: const Icon(Icons.bolt_rounded),
                      label: const Text(
                        'Ekstrak & Tinjau Jadwal',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF42A5F5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
