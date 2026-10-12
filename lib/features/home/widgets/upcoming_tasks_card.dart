import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../schedules/models/schedule_model.dart';

class UpcomingTasksCard extends StatelessWidget {
  final List<ScheduleModel> upcomingTasks;
  final Function(String id) onToggleComplete;
  final VoidCallback onViewAll;

  const UpcomingTasksCard({
    super.key,
    required this.upcomingTasks,
    required this.onToggleComplete,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Tenggat Tugas Terdekat',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF212121),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: onViewAll,
                  child: const Text(
                    'Lihat Semua',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF42A5F5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          if (upcomingTasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.task_alt_rounded,
                      size: 20,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Hebat! Semua tugas akademik sudah selesai dikerjakan.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: upcomingTasks.take(3).length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final task = upcomingTasks[index];
                final dueFormatted =
                    DateFormat('d MMM, HH:mm').format(task.dueDate.toLocal());
                final isUrgent =
                    task.dueDate.difference(DateTime.now()).inHours < 24;

                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onViewAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isUrgent ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isUrgent ? const Color(0xFFFECACA) : const Color(0xFFF1F5F9),
                      ),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => onToggleComplete(task.id),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                                width: 1.8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF212121),
                                ),
                              ),
                              if (task.course != null)
                                Text(
                                  task.course!.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isUrgent ? const Color(0xFFFEE2E2) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isUrgent ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            dueFormatted,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isUrgent ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
