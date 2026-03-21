class PlayerProfile {
  final String name;
  final int? age;
  final String club;
  final int? yearsPlaying;
  final String? photoPath;
  final String playingStyle; // attacking | defensive | all-round
  final String preferredGrip; // forehand | backhand
  final String shortTermGoal;
  final String longTermGoal;

  const PlayerProfile({
    this.name = '',
    this.age,
    this.club = '',
    this.yearsPlaying,
    this.photoPath,
    this.playingStyle = 'all-round',
    this.preferredGrip = 'forehand',
    this.shortTermGoal = '',
    this.longTermGoal = '',
  });

  PlayerProfile copyWith({
    String? name,
    int? age,
    String? club,
    int? yearsPlaying,
    String? photoPath,
    String? playingStyle,
    String? preferredGrip,
    String? shortTermGoal,
    String? longTermGoal,
  }) {
    return PlayerProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      club: club ?? this.club,
      yearsPlaying: yearsPlaying ?? this.yearsPlaying,
      photoPath: photoPath ?? this.photoPath,
      playingStyle: playingStyle ?? this.playingStyle,
      preferredGrip: preferredGrip ?? this.preferredGrip,
      shortTermGoal: shortTermGoal ?? this.shortTermGoal,
      longTermGoal: longTermGoal ?? this.longTermGoal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'age': age,
      'club': club,
      'yearsPlaying': yearsPlaying,
      'photoPath': photoPath,
      'playingStyle': playingStyle,
      'preferredGrip': preferredGrip,
      'shortTermGoal': shortTermGoal,
      'longTermGoal': longTermGoal,
    };
  }

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      name: json['name'] as String? ?? '',
      age: json['age'] as int?,
      club: json['club'] as String? ?? '',
      yearsPlaying: json['yearsPlaying'] as int?,
      photoPath: json['photoPath'] as String?,
      playingStyle: json['playingStyle'] as String? ?? 'all-round',
      preferredGrip: json['preferredGrip'] as String? ?? 'forehand',
      shortTermGoal: json['shortTermGoal'] as String? ?? '',
      longTermGoal: json['longTermGoal'] as String? ?? '',
    );
  }
}

const List<String> kPlayingStyles = ['attacking', 'defensive', 'all-round'];
const List<String> kGripTypes = ['forehand', 'backhand'];
