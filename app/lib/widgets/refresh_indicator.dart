import 'package:flutter/material.dart';

/// A themed refresh indicator tuned for Ancora's editorial identity.
///
/// Uses the app's color scheme with a slightly thicker stroke
/// and tuned displacement for a polished pull-to-refresh feel.
class AncoraRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const AncoraRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      displacement: 50,
      edgeOffset: 8,
      color: Theme.of(context).colorScheme.primary,
      backgroundColor: Theme.of(context).colorScheme.surface,
      strokeWidth: 2,
      child: child,
    );
  }
}
