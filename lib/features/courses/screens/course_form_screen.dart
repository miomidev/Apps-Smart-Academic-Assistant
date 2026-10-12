import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../models/course_model.dart';
import '../models/course_slot_model.dart';
import '../providers/courses_provider.dart';

class CourseFormScreen extends ConsumerStatefulWidget {
  final CourseModel? initialCourse;

  const CourseFormScreen({super.key, this.initialCourse});

  @override
  ConsumerState<CourseFormScreen> createState() => _CourseFormScreenState();
}

class _CourseFormScreenState extends ConsumerState<CourseFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _lecturerController;
  late TextEditingController _keywordsController;

  String _selectedColorHex = '#4F46E5';
  DateTime? _startDate;
  List<CourseSlotModel> _slots = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final c = widget.initialCourse;
    _nameController = TextEditingController(text: c?.name ?? '');
    _codeController = TextEditingController(text: c?.code ?? '');
    _lecturerController = TextEditingController(text: c?.lecturer ?? '');
    _keywordsController =
        TextEditingController(text: c?.keywords.join(', ') ?? '');

    if (c != null) {
      _selectedColorHex = c.colorCode;
      if (c.startDate != null) {
        _startDate = DateTime.tryParse(c.startDate!);
      }
      _slots = List.from(c.slots);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _lecturerController.dispose();
    _keywordsController.dispose();
    super.dispose();
  }

  void _addSlot() {
    setState(() {
      _slots.add(
        CourseSlotModel(
          dayOfWeek: 1, // Senin
          startTime: '08:00',
          endTime: '09:40',
          room: 'R. 101',
        ),
      );
    });
  }

  void _removeSlot(int index) {
    setState(() {
      _slots.removeAt(index);
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final keywords = _keywordsController.text
        .split(',')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();

    final startDateStr = _startDate != null
        ? '${_startDate!.year.toString().padLeft(4, '0')}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}'
        : null;

    try {
      if (widget.initialCourse != null) {
        await ref.read(coursesListProvider.notifier).updateCourse(
              id: widget.initialCourse!.id,
              name: _nameController.text.trim(),
              code: _codeController.text.trim(),
              lecturer: _lecturerController.text.trim(),
              colorCode: _selectedColorHex,
              startDate: startDateStr,
              keywords: keywords,
              slots: _slots,
            );
      } else {
        await ref.read(coursesListProvider.notifier).createCourse(
              name: _nameController.text.trim(),
              code: _codeController.text.trim(),
              lecturer: _lecturerController.text.trim(),
              colorCode: _selectedColorHex,
              startDate: startDateStr,
              keywords: keywords,
              slots: _slots,
            );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan mata kuliah: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialCourse != null;

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
          isEdit ? 'Ubah Mata Kuliah' : 'Tambah Mata Kuliah',
          style: const TextStyle(
            color: Color(0xFF212121),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
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
                  // Nama Mata Kuliah
                  const Text(
                    'Nama Mata Kuliah',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    decoration: _inputDecoration('Contoh: Pemrograman Web Lanjut', Icons.menu_book_rounded),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Nama mata kuliah wajib diisi' : null,
                  ),
                  const SizedBox(height: 18),

                  // Kode & Dosen
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Kode MK',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _codeController,
                              decoration: _inputDecoration('IF204', Icons.vpn_key_rounded),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dosen Pengampu',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _lecturerController,
                              decoration: _inputDecoration('Nama Dosen', Icons.person_rounded),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Warna Mata Kuliah
                  const Text(
                    'Warna Label Mata Kuliah',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: AppColors.courseColors.map((color) {
                      final hex = AppColors.toHex(color);
                      final isSelected = _selectedColorHex.toUpperCase() == hex.toUpperCase();
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColorHex = hex),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? const Color(0xFF212121) : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Tanggal Mulai Kuliah
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Tanggal Mulai Perkuliahan',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _startDate != null
                          ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                          : 'Belum ditentukan (default hari ini)',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    trailing: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF42A5F5),
                        side: const BorderSide(color: Color(0xFF42A5F5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _pickStartDate,
                      child: const Text('Pilih'),
                    ),
                  ),
                  const Divider(height: 28, color: Color(0xFFF1F5F9)),

                  // Jadwal Kuliah Mingguan (Course Slots)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Jadwal Kuliah Mingguan',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF212121)),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF42A5F5)),
                        onPressed: _addSlot,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Tambah Jam'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_slots.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Text(
                        'Belum ada jadwal mingguan. Tambahkan agar sistem dapat mencocokkan waktu kuliah untuk auto-tag catatan suara.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    )
                  else
                    ..._slots.asMap().entries.map((entry) {
                      final index = entry.key;
                      final slot = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: slot.dayOfWeek,
                                    decoration: InputDecoration(
                                      labelText: 'Hari',
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 1, child: Text('Senin')),
                                      DropdownMenuItem(value: 2, child: Text('Selasa')),
                                      DropdownMenuItem(value: 3, child: Text('Rabu')),
                                      DropdownMenuItem(value: 4, child: Text('Kamis')),
                                      DropdownMenuItem(value: 5, child: Text('Jumat')),
                                      DropdownMenuItem(value: 6, child: Text('Sabtu')),
                                      DropdownMenuItem(value: 7, child: Text('Minggu')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _slots[index] = CourseSlotModel(
                                            id: slot.id,
                                            courseId: slot.courseId,
                                            dayOfWeek: val,
                                            startTime: slot.startTime,
                                            endTime: slot.endTime,
                                            room: slot.room,
                                          );
                                        });
                                      }
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                                  onPressed: () => _removeSlot(index),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: slot.startTime,
                                    decoration: InputDecoration(
                                      labelText: 'Mulai',
                                      hintText: '08:00',
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onChanged: (val) {
                                      _slots[index] = CourseSlotModel(
                                        id: slot.id,
                                        courseId: slot.courseId,
                                        dayOfWeek: slot.dayOfWeek,
                                        startTime: val,
                                        endTime: slot.endTime,
                                        room: slot.room,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: slot.endTime,
                                    decoration: InputDecoration(
                                      labelText: 'Selesai',
                                      hintText: '09:40',
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onChanged: (val) {
                                      _slots[index] = CourseSlotModel(
                                        id: slot.id,
                                        courseId: slot.courseId,
                                        dayOfWeek: slot.dayOfWeek,
                                        startTime: slot.startTime,
                                        endTime: val,
                                        room: slot.room,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: slot.room,
                                    decoration: InputDecoration(
                                      labelText: 'Ruang',
                                      hintText: 'R. 102',
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onChanged: (val) {
                                      _slots[index] = CourseSlotModel(
                                        id: slot.id,
                                        courseId: slot.courseId,
                                        dayOfWeek: slot.dayOfWeek,
                                        startTime: slot.startTime,
                                        endTime: slot.endTime,
                                        room: val,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 18),
                  // Kata Kunci Tambahan
                  const Text(
                    'Kata Kunci Auto-Tag (opsional)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _keywordsController,
                    decoration: _inputDecoration('Contoh: react, flutter, html, api', Icons.tag_rounded),
                  ),
                  const SizedBox(height: 28),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF42A5F5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              isEdit ? 'Simpan Perubahan' : 'Buat Mata Kuliah',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData prefixIcon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF42A5F5), size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF42A5F5), width: 1.5),
      ),
    );
  }
}
