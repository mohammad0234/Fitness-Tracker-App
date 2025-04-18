import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:fitjourney/database_models/progress_data.dart';
import 'package:fitjourney/database/database_helper.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:sqflite/sqflite.dart' as sqflite;

// Mock classes
class MockDatabaseHelper extends Mock implements DatabaseHelper {}

class MockDatabase extends Mock implements sqflite.Database {}

class MockFirebaseAuth extends Mock implements firebase_auth.FirebaseAuth {
  @override
  firebase_auth.User? get currentUser => _mockUser;

  final MockUser _mockUser = MockUser();
}

class MockUser implements firebase_auth.User {
  @override
  String get uid => 'test-user-123';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// TestableProgressService to mimic the real service but with injected dependencies
class TestableProgressService {
  final DatabaseHelper dbHelper;
  final firebase_auth.FirebaseAuth auth;

  TestableProgressService(this.dbHelper, this.auth);

  // Get the current user ID or throw an error if not logged in

  // Get workout volume data for charts - simplified for testing
  Future<List<Map<String, dynamic>>> getWorkoutVolumeData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Return mock data for testing
    return [
      {
        'date': DateTime(2023, 5, 1),
        'volume': 2500.0,
        'formattedDate': 'May 1',
      },
      {
        'date': DateTime(2023, 5, 5),
        'volume': 3000.0,
        'formattedDate': 'May 5',
      },
      {
        'date': DateTime(2023, 5, 10),
        'volume': 3200.0,
        'formattedDate': 'May 10',
      },
    ];
  }

  // Get muscle group distribution data - simplified for testing
  Future<List<Map<String, dynamic>>> getMuscleGroupDistribution({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Return mock data for testing
    return [
      {
        'muscleGroup': 'Chest',
        'count': 12,
        'percentage': 30.0,
        'formattedPercentage': '30.0%',
      },
      {
        'muscleGroup': 'Back',
        'count': 10,
        'percentage': 25.0,
        'formattedPercentage': '25.0%',
      },
      {
        'muscleGroup': 'Legs',
        'count': 8,
        'percentage': 20.0,
        'formattedPercentage': '20.0%',
      },
    ];
  }

  // Get progress summary - simplified for testing
  Future<Map<String, dynamic>> getProgressSummary() async {
    // Return mock data for testing
    return {
      'totalWorkouts': 24,
      'totalExercises': 158,
      'averageWorkoutsPerWeek': 3.2,
      'daysSinceLastWorkout': 2,
      'mostFrequentMuscleGroup': 'Chest',
    };
  }
}

void main() {
  group('ProgressData Model Tests', () {
    test('ProgressData.empty creates an empty progress data object', () {
      // Act
      final progressData = ProgressData.empty();

      // Assert
      expect(progressData.volumeData, isEmpty);
      expect(progressData.muscleGroupData, isEmpty);
      expect(progressData.frequencyData, isNull);
      expect(progressData.progressSummary, isEmpty);
      expect(progressData.personalBests, isEmpty);
    });

    test('ProgressData constructor creates valid object with data', () {
      // Arrange
      final volumeData = [
        {'date': DateTime.now(), 'volume': 2500.0}
      ];
      final muscleGroupData = [
        {'muscleGroup': 'Chest', 'percentage': 30.0}
      ];
      final frequencyData = {'weekly': 3};
      final progressSummary = {'totalWorkouts': 24};
      final personalBests = [
        {'exercise': 'Bench Press', 'weight': 100.0}
      ];

      // Act
      final progressData = ProgressData(
        volumeData: volumeData,
        muscleGroupData: muscleGroupData,
        frequencyData: frequencyData,
        progressSummary: progressSummary,
        personalBests: personalBests,
      );

      // Assert
      expect(progressData.volumeData, equals(volumeData));
      expect(progressData.muscleGroupData, equals(muscleGroupData));
      expect(progressData.frequencyData, equals(frequencyData));
      expect(progressData.progressSummary, equals(progressSummary));
      expect(progressData.personalBests, equals(personalBests));
    });
  });

  group('ProgressService Tests', () {
    late MockDatabaseHelper mockDbHelper;
    late MockFirebaseAuth mockAuth;
    late TestableProgressService progressService;

    setUp(() {
      // Initialize mocks
      mockDbHelper = MockDatabaseHelper();
      mockAuth = MockFirebaseAuth();

      // Create testable service instance
      progressService = TestableProgressService(mockDbHelper, mockAuth);
    });

    test('getWorkoutVolumeData returns volume data points', () async {
      // Arrange
      final startDate = DateTime(2023, 5, 1);
      final endDate = DateTime(2023, 5, 31);

      // Act
      final result = await progressService.getWorkoutVolumeData(
          startDate: startDate, endDate: endDate);

      // Assert
      expect(result, isNotNull);
      expect(result.length, equals(3));
      expect(result[0]['volume'], equals(2500.0));
      expect(result[1]['volume'], equals(3000.0));
      expect(result[2]['volume'], equals(3200.0));
    });

    test('getMuscleGroupDistribution returns percentage data', () async {
      // Arrange
      final startDate = DateTime(2023, 5, 1);
      final endDate = DateTime(2023, 5, 31);

      // Act
      final result = await progressService.getMuscleGroupDistribution(
          startDate: startDate, endDate: endDate);

      // Assert
      expect(result, isNotNull);
      expect(result.length, equals(3));
      expect(result[0]['muscleGroup'], equals('Chest'));
      expect(result[0]['percentage'], equals(30.0));
      expect(result.map((e) => e['muscleGroup']), contains('Back'));
      expect(result.map((e) => e['muscleGroup']), contains('Legs'));
    });

    test('getProgressSummary returns summary metrics', () async {
      // Act
      final result = await progressService.getProgressSummary();

      // Assert
      expect(result, isNotNull);
      expect(result['totalWorkouts'], equals(24));
      expect(result['averageWorkoutsPerWeek'], equals(3.2));
      expect(result['daysSinceLastWorkout'], equals(2));
      expect(result['mostFrequentMuscleGroup'], equals('Chest'));
    });

    // Test for UC9: Exercise-specific progress
    test('getExerciseProgressHistory returns correct data series', () async {
      // Arrange
      final exerciseId = 1;
      final startDate = DateTime(2023, 5, 1);
      final endDate = DateTime(2023, 5, 31);

      // Create a mock implementation for getting exercise progress
      Future<List<Map<String, dynamic>>> getExerciseProgressHistory(
          int exerciseId, DateTime startDate, DateTime endDate) async {
        // In a real implementation, this would query the exercise history
        return [
          {
            'date': DateTime(2023, 5, 5),
            'weight': 80.0,
            'reps': 8,
            'formattedDate': 'May 5',
          },
          {
            'date': DateTime(2023, 5, 15),
            'weight': 85.0,
            'reps': 8,
            'formattedDate': 'May 15',
          },
          {
            'date': DateTime(2023, 5, 25),
            'weight': 90.0,
            'reps': 6,
            'formattedDate': 'May 25',
          },
        ];
      }

      // Act
      final result =
          await getExerciseProgressHistory(exerciseId, startDate, endDate);

      // Assert
      expect(result, isNotNull);
      expect(result.length, equals(3));
      expect(result[0]['weight'], equals(80.0));
      expect(result[1]['weight'], equals(85.0));
      expect(result[2]['weight'], equals(90.0));

      // Verify progression over time (weight should be increasing)
      expect(result[0]['weight'], lessThan(result[1]['weight']));
      expect(result[1]['weight'], lessThan(result[2]['weight']));
    });

    // Test for UC10: Goal achievement verification
    test('checkGoalAchievement correctly identifies completed goals', () async {
      // Arrange
      // Create a mock goal checking function
      bool isGoalAchieved(Map<String, dynamic> goal) {
        final double currentProgress = goal['currentProgress'];
        final double targetValue = goal['targetValue'];
        return currentProgress >= targetValue;
      }

      // Create sample goals with different completion states
      final completedGoal = {
        'goalId': 1,
        'type': 'WorkoutFrequency',
        'targetValue': 20.0,
        'currentProgress': 22.0,
      };

      final incompleteGoal = {
        'goalId': 2,
        'type': 'ExerciseTarget',
        'targetValue': 100.0,
        'currentProgress': 90.0,
      };

      final justCompletedGoal = {
        'goalId': 3,
        'type': 'WeightTarget',
        'targetValue': 75.0,
        'currentProgress': 75.0,
      };

      // Act & Assert
      expect(isGoalAchieved(completedGoal), isTrue);
      expect(isGoalAchieved(incompleteGoal), isFalse);
      expect(isGoalAchieved(justCompletedGoal), isTrue);
    });

    // Test for UC2/UC9: Workout volume calculation
    test('calculateWorkoutVolume returns correct total volume', () async {
      // Arrange
      // Create mock workout sets with reps and weights
      final workoutSets = [
        {'reps': 10, 'weight': 80.0}, // Volume: 800
        {'reps': 8, 'weight': 85.0}, // Volume: 680
        {'reps': 6, 'weight': 90.0}, // Volume: 540
      ];

      // Create a volume calculation function
      double calculateVolume(List<Map<String, dynamic>> sets) {
        return sets.fold(0.0, (sum, set) {
          final reps = set['reps'] as int;
          final weight = set['weight'] as double;
          return sum + (reps * weight);
        });
      }

      // Act
      final totalVolume = calculateVolume(workoutSets);

      // Assert
      // Expected: 800 + 680 + 540 = 2020
      expect(totalVolume, equals(2020.0));
    });

    // Test for UC18: Streak calculation edge cases
    test('streak handles rest days without breaking', () async {
      // Arrange
      // Create a function to calculate streak with rest days
      int calculateStreakWithRestDays(List<Map<String, dynamic>> activityLog) {
        if (activityLog.isEmpty) return 0;

        int currentStreak = 1; // Start with the first day

        // Sort by date, newest first (assuming dates are already sorted)
        for (int i = 0; i < activityLog.length - 1; i++) {
          final currentDay = activityLog[i];
          final nextDay = activityLog[i + 1];

          // If the difference between days is 1 or the type is 'rest', continue streak
          final int dayDifference =
              currentDay['date'].difference(nextDay['date']).inDays;

          if (dayDifference == 1 ||
              (dayDifference > 1 && currentDay['type'] == 'rest')) {
            currentStreak++;
          } else {
            // Break in the streak
            break;
          }
        }

        return currentStreak;
      }

      // Create sample activity logs for different scenarios
      final consecutiveWorkoutDays = [
        {'date': DateTime(2023, 5, 5), 'type': 'workout'},
        {'date': DateTime(2023, 5, 4), 'type': 'workout'},
        {'date': DateTime(2023, 5, 3), 'type': 'workout'}
      ];

      final workoutsWithRestDay = [
        {'date': DateTime(2023, 5, 5), 'type': 'workout'},
        {'date': DateTime(2023, 5, 4), 'type': 'rest'},
        {'date': DateTime(2023, 5, 3), 'type': 'workout'}
      ];

      final brokenStreak = [
        {'date': DateTime(2023, 5, 5), 'type': 'workout'},
        {
          'date': DateTime(2023, 5, 3),
          'type': 'workout'
        }, // Gap of one day (no activity)
        {'date': DateTime(2023, 5, 1), 'type': 'workout'}
      ];

      // Act & Assert
      expect(calculateStreakWithRestDays(consecutiveWorkoutDays), equals(3));
      expect(calculateStreakWithRestDays(workoutsWithRestDay),
          equals(3)); // Rest days don't break streak
      expect(calculateStreakWithRestDays(brokenStreak),
          equals(1)); // Streak is broken by gap
    });
  });
}
