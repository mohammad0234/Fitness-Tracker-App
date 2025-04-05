// lib/utils/notification_helper.dart

/// Utility class for creating notification messages
class NotificationMessages {
  // Goal-related notification messages
  static String goalProgress(String goalName, double percentComplete) {
    final percentage = (percentComplete * 100).toInt();
    return "You're $percentage% of the way to your $goalName goal!";
  }

  static String goalAchieved(String goalName) {
    return "Congratulations! You've reached your $goalName goal!";
  }

  static String goalExpiring(String goalName, int daysLeft) {
    return "Your $goalName goal expires in $daysLeft days!";
  }

  // Streak-related notification messages
  static String streakMaintenance(int currentStreak) {
    return "Don't break your $currentStreak-day streak - log a workout today!";
  }

  static String streakMilestone(int streakDays) {
    return "$streakDays-day streak achieved! Keep it up!";
  }

  static String streakAtRisk() {
    return "Your streak will break if you don't log a workout today!";
  }

  // Performance notification messages
  static String personalBest(String exerciseName, double weight) {
    return "New personal best on $exerciseName: ${weight.toStringAsFixed(1)}kg!";
  }

  static String progressInsight(String muscleGroup, int percentage) {
    return "You've increased your $muscleGroup workout volume by $percentage% this month!";
  }

  // Engagement notification messages
  static String inactivityReminder(int days) {
    return "It's been $days days since your last workout. Time to get back to it!";
  }

  static String workoutSuggestion(String muscleGroup) {
    return "It's time for $muscleGroup day based on your routine!";
  }
}