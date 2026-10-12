import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../courses/providers/courses_provider.dart';
import '../models/schedule_model.dart';
import '../providers/schedules_provider.dart';

class ScheduleFormScreen extends ConsumerStatefulWidget {
  final String? preselectedCourseId;

  const ScheduleFormScreen({super.key, this.preselectedCourseId});

  @override
  ConsumerState<ScheduleFormScreen> createState() => _ScheduleFormScreenState();
}

class _ScheduleFormScreenState extends ConsumerState<ScheduleFormScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedCourseId;
  late TextEditingController _titleController;
  late TextEditingController _meetingNumController;

  ScheduleType _selectedType = ScheduleType.classType;
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 2));
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _reminderMinutes = 60;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedCourseId = widget.preselectedCourseId;
    _titleController = TextEditingController();
    _meetingNumController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _meetingNumController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih mata kuliah terlebih dahulu'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final meetingNum = int.tryParse(_meetingNumController.text.trim());
      await ref.read(schedulesListProvider.notifier).createSchedule(
            courseId: _selectedCourseId!,
            title: _titleController.text.trim(),
            type: _selectedType,
            meetingNumber: meetingNum,
            dueDate: _selectedDate,
            reminderMinutes: _reminderMinutes,
          );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan jadwal: $e'),
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
    final coursesAsync = ref.watch(coursesListProvider);

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
        title: const Text(
          'Tambah Jadwal / Tugas',
          style: TextStyle(
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
                  // Type Segment
                  const Text(
                    'Kategori Jadwal',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildTypeChip(ScheduleType.classType, 'Kuliah', Icons.menu_book_rounded),
                      const SizedBox(width: 8),
                      _buildTypeChip(ScheduleType.task, 'Tugas', Icons.assignment_rounded),
                      const SizedBox(width: 8),
                      _buildTypeChip(ScheduleType.exam, 'Ujian', Icons.quiz_rounded),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Course Dropdown
                  const Text(
                    'Mata Kuliah',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 8),
                  coursesAsync.when(
                    data: (courses) {
                      if (courses.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: const Text(
                            'Tambahkan mata kuliah terlebih dahulu sebelum membuat jadwal.',
                            style: TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                          ),
                        );
                      }

                      return DropdownButtonFormField<String>(
                        initialValue: _selectedCourseId ?? courses.first.id,
                        isExpanded: true,
                        decoration: _inputDecoration('Pilih Mata Kuliah', Icons.school_rounded),
                        items: courses.map((c) {
                          return DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedCourseId = val),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (err, stack) => const Text('Gagal memuat mata kuliah'),
                  ),
                  const SizedBox(height: 18),

                  // Title
                  const Text(
                    'Judul / Topik',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    decoration: _inputDecoration(
                      _selectedType == ScheduleType.classType
                          ? 'Contoh: Pertemuan 3: REST API'
                          : 'Contoh: Tugas Mandiri Bab 2',
                      Icons.title_rounded,
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Judul wajib diisi' : null,
                  ),
                  const SizedBox(height: 18),

                  // Meeting Number (if class)
                  if (_selectedType == ScheduleType.classType) ...[
                    const Text(
                      'Pertemuan Ke-',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _meetingNumController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Contoh: 1, 2, 3...', Icons.numbers_rounded),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Date & Time
                  const Text(
                    'Waktu Pelaksanaan',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: _inputDecoration('Tanggal', Icons.calendar_today_rounded),
                            child: Text(
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: _pickTime,
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: _inputDecoration('Jam (WIB)', Icons.access_time_rounded),
                            child: Text(
                              '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Reminder Dropdown
                  const Text(
                    'Pengingat Alarm',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _reminderMinutes,
                    decoration: _inputDecoration('Ingatkan Sebelum', Icons.notifications_active_rounded),
                    items: const [
                      DropdownMenuItem(value: 15, child: Text('15 Menit Sebelumnya', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 30, child: Text('30 Menit Sebelumnya', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 60, child: Text('1 Jam Sebelumnya', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 120, child: Text('2 Jam Sebelumnya', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 1440, child: Text('1 Hari Sebelumnya', style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _reminderMinutes = val);
                    },
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
                          : const Text(
                              'Simpan Jadwal',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
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

  Widget _buildTypeChip(ScheduleType type, String label, IconData icon) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF42A5F5) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
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
