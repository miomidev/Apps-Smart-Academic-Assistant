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
      appBar: AppBar(
        title: Text(isEdit ? 'Ubah Mata Kuliah' : 'Tambah Mata Kuliah'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Nama Mata Kuliah
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Mata Kuliah *',
                hintText: 'Contoh: Pemrograman Web Lanjut',
                prefixIcon: Icon(Icons.menu_book_rounded),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Nama mata kuliah wajib diisi' : null,
            ),
            const SizedBox(height: 16),

            // Kode & Dosen
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Kode MK',
                      hintText: 'IF204',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _lecturerController,
                    decoration: const InputDecoration(
                      labelText: 'Dosen Pengampu',
                      hintText: 'Nama Dosen',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Warna Mata Kuliah
            const Text(
              'Warna Label Mata Kuliah',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black87 : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Tanggal Mulai Kuliah
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tanggal Mulai Perkuliahan'),
              subtitle: Text(
                _startDate != null
                    ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                    : 'Belum ditentukan (default hari ini)',
              ),
              trailing: OutlinedButton(
                onPressed: _pickStartDate,
                child: const Text('Pilih Tanggal'),
              ),
            ),
            const Divider(height: 32),

            // Jadwal Kuliah Mingguan (Course Slots)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Jadwal Kuliah Mingguan',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                TextButton.icon(
                  onPressed: _addSlot,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tambah Jam'),
                ),
              ],
            ),
            if (_slots.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Belum ada jadwal mingguan. Tambahkan agar sistem dapat mencocokkan waktu kuliah untuk auto-tag catatan.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              )
            else
              ..._slots.asMap().entries.map((entry) {
                final index = entry.key;
                final slot = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: slot.dayOfWeek,
                              decoration: const InputDecoration(
                                labelText: 'Hari',
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                            icon: const Icon(Icons.delete_outline, color: AppColors.error),
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
                              decoration: const InputDecoration(
                                labelText: 'Mulai (WIB)',
                                hintText: '08:00',
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                              decoration: const InputDecoration(
                                labelText: 'Selesai (WIB)',
                                hintText: '09:40',
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                              decoration: const InputDecoration(
                                labelText: 'Ruangan',
                                hintText: 'R. 102',
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

            const SizedBox(height: 16),
            // Kata Kunci Tambahan
            TextFormField(
              controller: _keywordsController,
              decoration: const InputDecoration(
                labelText: 'Kata Kunci Auto-Tag (pisahkan koma)',
                hintText: 'Contoh: react, flutter, html, css, api',
                prefixIcon: Icon(Icons.tag_rounded),
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        isEdit ? 'Simpan Perubahan' : 'Buat Mata Kuliah',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
