import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The month currently selected for display across all screens.
/// Defaults to the first day of the current month.
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

/// The current shell tab index (0=Dashboard,1=History,2=Analytics,3=Settings).
final currentTabIndexProvider = StateProvider<int>((_) => 0);