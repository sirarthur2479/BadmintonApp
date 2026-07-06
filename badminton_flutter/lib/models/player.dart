/// A player under the account (web/server model). Field names mirror the
/// backend payload exactly.
class Player {
  final String id;
  final String name;
  final int? age;
  final String club;
  final String playingStyle;
  final String preferredGrip;
  final String shortTermGoal;
  final String longTermGoal;
  final String? photoPath;

  const Player({
    required this.id,
    required this.name,
    this.age,
    this.club = '',
    this.playingStyle = '',
    this.preferredGrip = '',
    this.shortTermGoal = '',
    this.longTermGoal = '',
    this.photoPath,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'age': age,
        'club': club,
        'playingStyle': playingStyle,
        'preferredGrip': preferredGrip,
        'shortTermGoal': shortTermGoal,
        'longTermGoal': longTermGoal,
        'photoPath': photoPath,
      };

  factory Player.fromMap(Map<String, dynamic> map) => Player(
        id: map['id'] as String,
        name: map['name'] as String,
        age: map['age'] as int?,
        club: map['club'] as String? ?? '',
        playingStyle: map['playingStyle'] as String? ?? '',
        preferredGrip: map['preferredGrip'] as String? ?? '',
        shortTermGoal: map['shortTermGoal'] as String? ?? '',
        longTermGoal: map['longTermGoal'] as String? ?? '',
        photoPath: map['photoPath'] as String?,
      );
}
