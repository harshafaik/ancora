import 'package:flutter/material.dart';
import '../utils/dark_mode_scheduler.dart';

/// Settings screen for configuring auto dark mode scheduling.
class DarkModeScheduleScreen extends StatefulWidget {
  const DarkModeScheduleScreen({super.key});

  @override
  State<DarkModeScheduleScreen> createState() =>
      _DarkModeScheduleScreenState();
}

class _DarkModeScheduleScreenState extends State<DarkModeScheduleScreen> {
  bool _enabled = false;
  int _startHour = DarkModeScheduler.defaultStartHour;
  int _endHour = DarkModeScheduler.defaultEndHour;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await DarkModeScheduler.isEnabled();
    final start = await DarkModeScheduler.getStartHour();
    final end = await DarkModeScheduler.getEndHour();
    setState(() {
      _enabled = enabled;
      _startHour = start;
      _endHour = end;
    });
  }

  Future<void> _saveSettings() async {
    await DarkModeScheduler.setEnabled(_enabled);
    await DarkModeScheduler.setHours(_startHour, _endHour);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule saved.')),
      );
    }
  }

  String _formatHour(int hour) {
    if (hour == 0 || hour == 24) return '12 AM (Midnight)';
    if (hour == 12) return '12 PM (Noon)';
    final period = hour >= 12 ? 'PM' : 'AM';
    final display = hour > 12 ? hour - 12 : hour;
    return '$display $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dark Mode Schedule')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Auto Dark Mode',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Switch(
                  value: _enabled,
                  onChanged: (value) {
                    setState(() => _enabled = value);
                    _saveSettings();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _enabled
                  ? 'Theme switches automatically based on time of day'
                  : 'Manually toggle theme using the sun/moon icon',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 32),

            if (_enabled) ...[
              // Start hour
              const Text(
                'Dark Mode Starts',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              _HourPicker(
                value: _startHour,
                onChanged: (value) {
                  setState(() => _startHour = value);
                  _saveSettings();
                },
                label: _formatHour(_startHour),
              ),
              const SizedBox(height: 24),

              // End hour
              const Text(
                'Light Mode Resumes',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              _HourPicker(
                value: _endHour,
                onChanged: (value) {
                  setState(() => _endHour = value);
                  _saveSettings();
                },
                label: _formatHour(_endHour),
              ),
              const SizedBox(height: 32),

              // Info card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 20, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'The theme will switch automatically at the scheduled times. '
                        'You can still manually toggle the theme, but it will disable the schedule.',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HourPicker extends StatelessWidget {
  final int value;
  final Function(int) onChanged;
  final String label;

  const _HourPicker({
    required this.value,
    required this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 8),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: 23,
          divisions: 23,
          label: _formatHour(value),
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }

  String _formatHour(int hour) {
    if (hour == 0 || hour == 24) return '12 AM';
    if (hour == 12) return '12 PM';
    final period = hour >= 12 ? 'PM' : 'AM';
    final display = hour > 12 ? hour - 12 : hour;
    return '$display $period';
  }
}
