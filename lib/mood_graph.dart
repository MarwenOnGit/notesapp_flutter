import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class MoodGraphPage extends StatelessWidget {
  final List<Map<String, dynamic>> notesWithScores;

  const MoodGraphPage({Key? key, required this.notesWithScores}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();

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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.show_chart,
                        size: 80,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No mood data yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Add some mood notes to see your insights!',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Statistics Cards
                Row(
                  children: [
                    _buildStatCard(
                      context,
                      'Average Mood',
                      '${(stats['average'] * 100).toStringAsFixed(0)}%',
                      _getMoodEmoji(stats['average'] as double),
                      _getMoodColor(stats['average'] as double),
                    ),
                    const SizedBox(width: 16),
                    _buildStatCard(
                      context,
                      'Total Notes',
                      '${notesWithScores.length}',
                      '📝',
                      Colors.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Mood Distribution
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mood Distribution',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 300,
                        child: PieChart(
                          PieChartData(
                            sections: _getMoodDistributionSections(stats),
                            centerSpaceRadius: 60,
                            sectionsSpace: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildLegendItem('Happy', Colors.green),
                          _buildLegendItem('Neutral', Colors.yellow),
                          _buildLegendItem('Sad', Colors.red),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Line Chart
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mood Trend',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 250,
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(show: true, drawVerticalLine: true),
                            titlesData: FlTitlesData(show: false),
                            borderData: FlBorderData(show: true),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _getMoodTrendSpots(),
                                isCurved: true,
                                color: Theme.of(context).colorScheme.primary,
                                barWidth: 3,
                                dotData: FlDotData(show: true),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Recent Notes List
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Notes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...notesWithScores.reversed.take(5).map(
                            (note) => _buildNoteItem(context, note),
                          ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Map<String, dynamic> _calculateStats() {
    if (notesWithScores.isEmpty) {
      return {'average': 0.5, 'happy': 0, 'neutral': 0, 'sad': 0};
    }

    double totalScore = 0;
    int happy = 0;
    int neutral = 0;
    int sad = 0;

    for (var note in notesWithScores) {
      final score = note['sentimentScore'] as double;
      totalScore += score;

      if (score >= 0.7) {
        happy++;
      } else if (score >= 0.4) {
        neutral++;
      } else {
        sad++;
      }
    }

    return {
      'average': totalScore / notesWithScores.length,
      'happy': happy,
      'neutral': neutral,
      'sad': sad,
    };
  }

  List<PieChartSectionData> _getMoodDistributionSections(Map<String, dynamic> stats) {
    final total = notesWithScores.length;
    return [
      PieChartSectionData(
        value: stats['happy'].toDouble(),
        title: '${((stats['happy'] / total) * 100).toStringAsFixed(0)}%',
        color: Colors.green,
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        value: stats['neutral'].toDouble(),
        title: '${((stats['neutral'] / total) * 100).toStringAsFixed(0)}%',
        color: Colors.yellow,
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      PieChartSectionData(
        value: stats['sad'].toDouble(),
        title: '${((stats['sad'] / total) * 100).toStringAsFixed(0)}%',
        color: Colors.red,
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ];
  }

  List<FlSpot> _getMoodTrendSpots() {
    return notesWithScores.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value['sentimentScore'] as double,
      );
    }).toList();
  }

  Widget _buildStatCard(BuildContext context, String label, String value,
      String emoji, Color color) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 36),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildNoteItem(BuildContext context, Map<String, dynamic> note) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _getMoodColor(note['sentimentScore'] as double).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _getMoodColor(note['sentimentScore'] as double).withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    note['content'].length > 60
                        ? '${note['content'].substring(0, 60)}...'
                        : note['content'],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                  ),
                ),
                Text(
                  _getMoodEmoji(note['sentimentScore'] as double),
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              note['date'],
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getMoodColor(double sentimentScore) {
    if (sentimentScore >= 0.7) {
      return Colors.green;
    } else if (sentimentScore >= 0.4) {
      return Colors.yellow;
    } else {
      return Colors.red;
    }
  }

  String _getMoodEmoji(double sentimentScore) {
    if (sentimentScore >= 0.7) {
      return '😊';
    } else if (sentimentScore >= 0.4) {
      return '😐';
    } else {
      return '😞';
    }
  }
}