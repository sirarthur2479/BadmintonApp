/// Pure streak calculations over session dates. `today` is injected so the
/// logic is testable — no DateTime.now() in here.

int currentStreak(Iterable<DateTime> sessionDates, DateTime today) {
  return -1; // stub — behaviour driven by streak_test.dart
}

int bestStreak(Iterable<DateTime> sessionDates) {
  return -1; // stub
}
