// lib/utils/notification_helper.dart

/// Utility class for creating notification messages
class NotificationMessages {
  // Goal-related notification messages

  static String goalAchieved(String goalName) {
    return "Congratulations! You've reached your $goalName goal!";
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

  // Engagement notification messages
  static String inactivityReminder(int days) {
    return "It's been $days days since your last workout. Time to get back to it!";
  }
}
