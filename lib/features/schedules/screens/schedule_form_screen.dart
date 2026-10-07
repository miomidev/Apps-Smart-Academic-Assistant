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
      appBar: AppBar(
        title: const Text('Tambah Jadwal / Tugas'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Course Dropdown
            coursesAsync.when(
              data: (courses) {
                if (courses.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Tambahkan mata kuliah terlebih dahulu sebelum membuat jadwal.',
                      style: TextStyle(color: AppColors.error),
                    ),
                  );
                }

                return DropdownButtonFormField<String>(
                  initialValue: _selectedCourseId ?? courses.first.id,
                  decoration: const InputDecoration(
                    labelText: 'Mata Kuliah *',
                    prefixIcon: Icon(Icons.school_rounded),
                  ),
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
            const SizedBox(height: 16),

            // Type Segment
            SegmentedButton<ScheduleType>(
              segments: const [
                ButtonSegment(
                  value: ScheduleType.classType,
                  label: Text('Kuliah'),
                  icon: Icon(Icons.menu_book_rounded),
                ),
                ButtonSegment(
                  value: ScheduleType.task,
                  label: Text('Tugas'),
                  icon: Icon(Icons.assignment_rounded),
                ),
                ButtonSegment(
                  value: ScheduleType.exam,
                  label: Text('Ujian'),
                  icon: Icon(Icons.quiz_rounded),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (val) {
                setState(() => _selectedType = val.first);
              },
            ),
            const SizedBox(height: 16),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Judul Jadwal / Topik *',
                hintText: _selectedType == ScheduleType.classType
                    ? 'Contoh: Pertemuan 3: REST API'
                    : 'Contoh: Tugas Mandiri Bab 2',
                prefixIcon: const Icon(Icons.title_rounded),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Judul wajib diisi' : null,
            ),
            const SizedBox(height: 16),

            // Meeting Number (if class)
            if (_selectedType == ScheduleType.classType) ...[
              TextFormField(
                controller: _meetingNumController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Pertemuan Ke- (opsional)',
                  hintText: '1, 2, 3 ...',
                  prefixIcon: Icon(Icons.numbers_rounded),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Date & Time
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Tanggal',
                        prefixIcon: Icon(Icons.calendar_today_rounded),
                      ),
                      child: Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _pickTime,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Jam (WIB)',
                        prefixIcon: Icon(Icons.access_time_rounded),
                      ),
                      child: Text(
                        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Reminder Dropdown
            DropdownButtonFormField<int>(
              initialValue: _reminderMinutes,
              decoration: const InputDecoration(
                labelText: 'Ingatkan Sebelum',
                prefixIcon: Icon(Icons.notifications_active_rounded),
              ),
              items: const [
                DropdownMenuItem(value: 15, child: Text('15 Menit Sebelumnya')),
                DropdownMenuItem(value: 30, child: Text('30 Menit Sebelumnya')),
                DropdownMenuItem(value: 60, child: Text('1 Jam Sebelumnya')),
                DropdownMenuItem(value: 120, child: Text('2 Jam Sebelumnya')),
                DropdownMenuItem(value: 1440, child: Text('1 Hari Sebelumnya')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _reminderMinutes = val);
              },
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Simpan Jadwal',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
