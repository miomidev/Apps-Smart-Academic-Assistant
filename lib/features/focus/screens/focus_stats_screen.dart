import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/focus_session_model.dart';
import '../providers/focus_provider.dart';

class FocusStatsScreen extends ConsumerWidget {
  const FocusStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(focusStatsProvider);
    final sessionsAsync = ref.watch(focusSessionsProvider);

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
          'Statistik & Analitik Fokus',
          style: TextStyle(
            color: Color(0xFF212121),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(focusStatsProvider);
          ref.read(focusSessionsProvider.notifier).loadSessions();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary cards grid
              statsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => Center(child: Text('Gagal memuat statistik: $e')),
                data: (stats) {
                  final totalSessions = stats.completedSessions + stats.failedSessions;
                  final successRate = totalSessions > 0
                      ? ((stats.completedSessions / totalSessions) * 100).toInt()
                      : 100;

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Total Fokus',
                              value: '${stats.totalMinutes}',
                              unit: 'Menit',
                              icon: Icons.timer_rounded,
                              iconColor: const Color(0xFF0284C7),
                              iconBgColor: const Color(0xFFE0F2FE),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Streak Belajar',
                              value: '${stats.currentStreak}',
                              unit: 'Hari',
                              icon: Icons.local_fire_department_rounded,
                              iconColor: const Color(0xFFEA580C),
                              iconBgColor: const Color(0xFFFFF7ED),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Sesi Selesai',
                              value: '${stats.completedSessions}',
                              unit: 'Sesi',
                              icon: Icons.check_circle_rounded,
                              iconColor: const Color(0xFF16A34A),
                              iconBgColor: const Color(0xFFDCFCE7),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Tingkat Sukses',
                              value: '$successRate',
                              unit: '%',
                              icon: Icons.pie_chart_rounded,
                              iconColor: const Color(0xFF7C3AED),
                              iconBgColor: const Color(0xFFEDE9FE),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Weekly Bar Chart
                      _buildWeeklyBarChart(stats.dailyStats),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // Recent sessions list header
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  'Riwayat Sesi Terakhir',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF212121),
                  ),
                ),
              ),

              sessionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('Gagal memuat riwayat: $err'),
                data: (sessions) {
                  if (sessions.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(28),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFEEEEEE)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.hourglass_empty_rounded, size: 36, color: Color(0xFFCBD5E1)),
                          SizedBox(height: 10),
                          Text(
                            'Belum ada riwayat sesi fokus.',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sessions.take(10).length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final item = sessions[i];
                      final isSuccess = item.status == FocusStatus.completed;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSuccess
                                    ? const Color(0xFFECFDF5)
                                    : const Color(0xFFFEF2F2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isSuccess ? Icons.check_rounded : Icons.close_rounded,
                                color: isSuccess
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.course?.name ?? 'Fokus Bebas',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF212121),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('d MMM, HH:mm').format(item.startedAt),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${item.actualMinutes} Menit',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSuccess ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isSuccess ? 'Selesai' : 'Dibatalkan',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isSuccess
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFEF4444),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyBarChart(List<FocusDailyStat> dailyStats) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 20, color: Color(0xFF42A5F5)),
              SizedBox(width: 8),
              Text(
                'Aktivitas Fokus 7 Hari Terakhir',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF212121),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: dailyStats.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada data grafik',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _calculateMaxY(dailyStats),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final stat = dailyStats[groupIndex];
                            return BarTooltipItem(
                              '${stat.minutes} mnt',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (val, _) {
                              return Text(
                                val.toInt().toString(),
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, _) {
                              final idx = val.toInt();
                              if (idx >= 0 && idx < dailyStats.length) {
                                return Text(
                                  dailyStats[idx].dayName,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      gridData: const FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        drawHorizontalLine: true,
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: dailyStats.asMap().entries.map((entry) {
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.minutes.toDouble(),
                              color: const Color(0xFF42A5F5),
                              width: 16,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  double _calculateMaxY(List<FocusDailyStat> stats) {
    double max = 60;
    for (final s in stats) {
      if (s.minutes > max) max = s.minutes.toDouble();
    }
    return (max * 1.2).ceilToDouble();
  }
}
