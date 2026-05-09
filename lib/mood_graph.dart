import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:sentiment_analyzer/database_helper.dart';

class MoodGraphPage extends StatelessWidget {
  final List<Mood> notesWithScores;

  const MoodGraphPage({Key? key, required this.notesWithScores}) : super(key: key);

  // Group moods by date and calculate daily averages
  Map<String, double> _getGroupedMoodsByDate() {
    final Map<String, List<double>> dailyMoods = {};

    for (final mood in notesWithScores) {
      // Extract date part (YYYY-MM-DD) from the date field
      final dateStr = mood.date.substring(0, 10); // e.g., "2026-05-09"
      if (!dailyMoods.containsKey(dateStr)) {
        dailyMoods[dateStr] = [];
      }
      dailyMoods[dateStr]!.add(mood.sentimentScore);
    }

    // Calculate average mood per day
    final Map<String, double> dailyAverages = {};
    dailyMoods.forEach((date, scores) {
      final avg = scores.reduce((a, b) => a + b) / scores.length;
      dailyAverages[date] = avg;
    });

    // Sort by date
    final sortedMap = Map.fromEntries(
      dailyAverages.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );

    return sortedMap;
  }

  @override
  Widget build(BuildContext context) {
    final dailyMoods = _getGroupedMoodsByDate();
    final stats = _calculateStats(dailyMoods);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Mood Insights',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
      ),
      body: notesWithScores.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Add some mood notes to see your insights!',
                  style: TextStyle(
                    fontSize: 16,
                    color:
                        Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : CustomScrollView(
              slivers: [
                // Statistics cards - Now showing trend-based stats
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mood Overview',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                context,
                                'Overall Average',
                                '${(stats['overallAverage'] * 100).toStringAsFixed(0)}%',
                                _getMoodEmojiFromScore(stats['overallAverage']),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildStatCard(
                                context,
                                'Days Tracked',
                                '${dailyMoods.length}',
                                '📅',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                context,
                                'Best Day',
                                '${(stats['bestDay'] * 100).toStringAsFixed(0)}%',
                                '🎉',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildStatCard(
                                context,
                                'Trend',
                                stats['trend'] as String,
                                stats['trendEmoji'] as String,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Main line chart - Mood over time by dates
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Mood Journey',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Daily average mood score over time',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.shadow
                                    .withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: SizedBox(
                            height: 350,
                            child: LineChart(
                              LineChartData(
                                gridData: FlGridData(
                                  show: true,
                                  horizontalInterval: 0.25,
                                  verticalInterval: 1,
                                  drawVerticalLine: true,
                                ),
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      interval: (dailyMoods.length / 5).ceil().toDouble(),
                                      getTitlesWidget: (value, meta) {
                                        final index = value.toInt();
                                        final dates = dailyMoods.keys.toList();
                                        if (index < 0 || index >= dates.length) {
                                          return const SizedBox();
                                        }
                                        final dateStr = dates[index];
                                        // Show as MM-DD format
                                        final parts = dateStr.split('-');
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Text(
                                            '${parts[1]}-${parts[2]}',
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      interval: 0.25,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          '${(value * 100).toInt()}%',
                                          style: const TextStyle(fontSize: 11),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                borderData: FlBorderData(
                                  show: true,
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline,
                                    width: 1,
                                  ),
                                ),
                                minY: 0,
                                maxY: 1,
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: _getMoodTrendSpotsFromDaily(dailyMoods),
                                    isCurved: true,
                                    color: Theme.of(context).colorScheme.primary,
                                    barWidth: 3,
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.1),
                                    ),
                                    dotData: FlDotData(
                                      show: true,
                                      getDotPainter:
                                          (spot, percent, barData, index) =>
                                              FlDotCirclePainter(
                                        radius: 5,
                                        color: _getMoodColorFromScore(spot.y),
                                        strokeWidth: 2,
                                        strokeColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Daily breakdown
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Breakdown',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${dailyMoods.length} days tracked',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, index) {
                        final dates = dailyMoods.keys.toList();
                        if (index >= dates.length) {
                          return const SizedBox();
                        }
                        final dateStr = dates[dates.length - 1 - index]; // Reverse order (newest first)
                        final moodScore = dailyMoods[dateStr]!;
                        final entriesForDate = notesWithScores
                            .where((m) => m.date.substring(0, 10) == dateStr)
                            .toList();
                        
                        return _buildDailyCard(context, dateStr, moodScore, entriesForDate.length);
                      },
                      childCount: dailyMoods.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 20),
                ),
              ],
            ),
    );
  }

  Map<String, dynamic> _calculateStats(Map<String, double> dailyMoods) {
    if (dailyMoods.isEmpty) {
      return {
        'overallAverage': 0.5,
        'bestDay': 0.5,
        'trend': 'N/A',
        'trendEmoji': '➡️',
      };
    }

    // Overall average
    double total = 0;
    for (final score in dailyMoods.values) {
      total += score;
    }
    final overallAverage = total / dailyMoods.length;

    // Best day
    final bestDay = dailyMoods.values.reduce((a, b) => a > b ? a : b);

    // Calculate trend (compare last 3 days vs previous 3 days if available)
    final dates = dailyMoods.keys.toList();
    String trend = 'Stable 📊';
    String trendEmoji = '📊';
    
    if (dates.length >= 6) {
      final recentAvg = dailyMoods.values.toList().sublist(dates.length - 3)
          .reduce((a, b) => a + b) / 3;
      final previousAvg = dailyMoods.values.toList().sublist(dates.length - 6, dates.length - 3)
          .reduce((a, b) => a + b) / 3;
      
      if (recentAvg > previousAvg + 0.1) {
        trend = 'Improving 📈';
        trendEmoji = '📈';
      } else if (recentAvg < previousAvg - 0.1) {
        trend = 'Declining 📉';
        trendEmoji = '📉';
      }
    } else if (dates.length >= 2) {
      final lastScore = dailyMoods.values.last;
      final prevScore = dailyMoods.values.toList()[dates.length - 2];
      
      if (lastScore > prevScore + 0.1) {
        trend = 'Improving 📈';
        trendEmoji = '📈';
      } else if (lastScore < prevScore - 0.1) {
        trend = 'Declining 📉';
        trendEmoji = '📉';
      }
    }

    return {
      'overallAverage': overallAverage,
      'bestDay': bestDay,
      'trend': trend,
      'trendEmoji': trendEmoji,
    };
  }

  List<FlSpot> _getMoodTrendSpotsFromDaily(Map<String, double> dailyMoods) {
    final spots = <FlSpot>[];
    int index = 0;
    for (final moodScore in dailyMoods.values) {
      spots.add(FlSpot(index.toDouble(), moodScore));
      index++;
    }
    return spots;
  }

  Widget _buildStatCard(
      BuildContext context, String label, String value, String emoji) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyCard(BuildContext context, String date, double moodScore, int entryCount) {
    final moodColor = _getMoodColorFromScore(moodScore);
    final emoji = _getMoodEmojiFromScore(moodScore);
    
    // Format date from YYYY-MM-DD to readable format
    final parts = date.split('-');
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthName = months[int.parse(parts[1]) - 1];
    final dayName = parts[2];
    final displayDate = '$monthName $dayName';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: moodColor.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: moodColor.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Emoji
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: moodColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(width: 12),
            // Date and entry count
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayDate,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$entryCount ${entryCount == 1 ? 'entry' : 'entries'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            // Mood score and label
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${(moodScore * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: moodColor,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: moodColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getMoodLabel(moodScore),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: moodColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getMoodColorFromScore(double sentimentScore) {
    if (sentimentScore >= 0.7) {
      return Colors.green;
    } else if (sentimentScore >= 0.4) {
      return Colors.amber;
    } else {
      return Colors.red;
    }
  }

  String _getMoodEmojiFromScore(double sentimentScore) {
    if (sentimentScore >= 0.7) {
      return '😊';
    } else if (sentimentScore >= 0.4) {
      return '😐';
    } else {
      return '😞';
    }
  }

  String _getMoodLabel(double sentimentScore) {
    if (sentimentScore >= 0.7) {
      return 'Happy';
    } else if (sentimentScore >= 0.4) {
      return 'Neutral';
    } else {
      return 'Sad';
    }
  }
}