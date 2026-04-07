import 'package:flutter/material.dart';
import '../services/database_helper.dart';

/// Reading streaks and stats screen.
///
/// Shows articles read this week, current streak, total reads,
/// and a bar chart of daily activity over the past 7 days.
class ReadingStatsScreen extends StatefulWidget {
  const ReadingStatsScreen({super.key});

  @override
  State<ReadingStatsScreen> createState() => _ReadingStatsScreenState();
}

class _ReadingStatsScreenState extends State<ReadingStatsScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  bool _isLoading = true;
  int _totalArticles = 0;
  int _readThisWeek = 0;
  int _totalRead = 0;
  int _currentStreak = 0;
  int _longestStreak = 0;
  List<MapEntry<String, int>> _dailyReads = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final articles = await _db.getAllArticles();
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    int readThisWeek = 0;
    int totalRead = 0;

    for (final article in articles) {
      if ((article['is_read'] ?? 0) == 1) {
        totalRead++;
        final fetchedAt = article['fetched_at']?.toString();
        if (fetchedAt != null) {
          try {
            final date = DateTime.parse(fetchedAt);
            if (date.isAfter(startOfWeek.subtract(const Duration(days: 1)))) {
              readThisWeek++;
            }
          } catch (e) {}
        }
      }
    }

    // Calculate streaks from read timestamps
    final readDates = <DateTime>{};
    for (final article in articles) {
      if ((article['is_read'] ?? 0) == 1) {
        final fetchedAt = article['fetched_at']?.toString();
        if (fetchedAt != null) {
          try {
            final date = DateTime.parse(fetchedAt);
            readDates.add(DateTime(date.year, date.month, date.day));
          } catch (e) {}
        }
      }
    }

    final sortedDates = readDates.toList()..sort((a, b) => b.compareTo(a));
    final currentStreak = _calculateStreak(sortedDates, fromEnd: true);
    final longestStreak = _calculateLongestStreak(sortedDates);

    // Daily reads for past 7 days
    final dailyReads = <MapEntry<String, int>>[];
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      int count = 0;
      for (final date in readDates) {
        if (date.isAtSameMomentAs(dayStart) ||
            (date.isAfter(dayStart) && date.isBefore(dayEnd))) {
          count++;
        }
      }
      final dayLabel = i == 0
          ? 'Today'
          : i == 1
              ? 'Yesterday'
              : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][
                  day.weekday - 1];
      dailyReads.add(MapEntry(dayLabel, count));
    }

    final maxDaily = dailyReads.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    setState(() {
      _totalArticles = articles.length;
      _readThisWeek = readThisWeek;
      _totalRead = totalRead;
      _currentStreak = currentStreak;
      _longestStreak = longestStreak;
      _dailyReads = dailyReads;
      _isLoading = false;
      _maxDaily = maxDaily;
    });
  }

  int _calculateStreak(List<DateTime> dates, {bool fromEnd = false}) {
    if (dates.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Check if the streak includes today or yesterday (otherwise it's broken)
    final mostRecent = dates.first;
    if (!mostRecent.isAtSameMomentAs(today) &&
        !mostRecent.isAtSameMomentAs(yesterday)) {
      return 0;
    }

    int streak = 1;
    for (int i = 1; i < dates.length; i++) {
      final diff = dates[i - 1].difference(dates[i]).inDays;
      if (diff == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  int _calculateLongestStreak(List<DateTime> dates) {
    if (dates.isEmpty) return 0;

    int longest = 1;
    int current = 1;
    for (int i = 1; i < dates.length; i++) {
      final diff = dates[i - 1].difference(dates[i]).inDays;
      if (diff == 1) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }
    return longest;
  }

  int _maxDaily = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reading Stats')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary cards
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.newspaper_rounded,
                          value: _totalArticles.toString(),
                          label: 'Articles Available',
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.check_circle_rounded,
                          value: _totalRead.toString(),
                          label: 'Articles Read',
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.calendar_today_rounded,
                          value: _readThisWeek.toString(),
                          label: 'Read This Week',
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.local_fire_department_rounded,
                          value: _currentStreak.toString(),
                          label: 'Day Streak',
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Streak summary
                  if (_longestStreak > 1)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.emoji_events_rounded,
                              color: Colors.amber[600], size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Longest Streak: $_longestStreak days',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Your best reading run so far',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 28),

                  // Weekly chart
                  const Text(
                    'PAST 7 DAYS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 140,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: _dailyReads.map((entry) {
                        final height = _maxDaily > 0
                            ? (entry.value / _maxDaily) * 100
                            : 0.0;
                        final isToday = entry.key == 'Today';
                        return Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (entry.value > 0)
                                Text(
                                  '${entry.value}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isToday
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey[500],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                height: height > 0 ? height : 4,
                                width: 24,
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                entry.key.length > 3
                                    ? entry.key.substring(0, 3)
                                    : entry.key,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isToday
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey[500],
                                  fontWeight:
                                      isToday
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
