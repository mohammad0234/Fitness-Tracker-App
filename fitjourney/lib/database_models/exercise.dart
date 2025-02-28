class Exercise {
  final int? exerciseId;
  final String name;
  final String? muscleGroup;
  final String? description;

  Exercise({
    this.exerciseId,
    required this.name,
    this.muscleGroup,
    this.description,
  });

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      exerciseId: map['exercise_id'],
      name: map['name'],
      muscleGroup: map['muscle_group'],
      description: map['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'exercise_id': exerciseId,
      'name': name,
      'muscle_group': muscleGroup,
      'description': description,
    };
  }
}
