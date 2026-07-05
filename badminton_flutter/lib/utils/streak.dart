/// Pure streak calculations over session dates. `today` is injected so the
/// logic is testable — no DateTime.now() in here.
library;

/// Distinct calendar days, most recent first.
List<DateTime> _uniqueDays(Iterable<DateTime> dates) {
  final days = dates
      .map((d) => DateTime(d.year, d.month, d.day))
      .toSet()
      .toList()
    ..sort((a, b) => b.compareTo(a));
  return days;
}

/// Consecutive-day run that is still "alive": its most recent day is today
/// or yesterday.
int currentStreak(Iterable<DateTime> sessionDates, DateTime today) {
  final days = _uniqueDays(sessionDates);
  if (days.isEmpty) return 0;

  final todayDay = DateTime(today.year, today.month, today.day);
  if (todayDay.difference(days.first).inDays > 1) return 0;

  var streak = 1;
  for (var i = 1; i < days.length; i++) {
    if (days[i - 1].difference(days[i]).inDays != 1) break;
    streak++;
  }
  return streak;
}

/// Longest consecutive-day run anywhere in history.
int bestStreak(Iterable<DateTime> sessionDates) {
  final days = _uniqueDays(sessionDates);
  if (days.isEmpty) return 0;

  var best = 1;
  var run = 1;
  for (var i = 1; i < days.length; i++) {
    if (days[i - 1].difference(days[i]).inDays == 1) {
      run++;
      if (run > best) best = run;
    } else {
      run = 1;
    }
  }
  return best;
}
