import 'package:flutter_test/flutter_test.dart';

import 'package:badminton_flutter/models/player.dart';

void main() {
  test('player toMap/fromMap round-trips all fields', () {
    const player = Player(
      id: 'p1',
      name: 'Kid One',
      age: 12,
      club: 'North Shore BC',
      playingStyle: 'attacking',
      preferredGrip: 'forehand',
      shortTermGoal: 'Sharper net kills',
      longTermGoal: 'Regional top 8',
      photoPath: null,
    );

    final restored = Player.fromMap(player.toMap());

    expect(restored.id, 'p1');
    expect(restored.name, 'Kid One');
    expect(restored.age, 12);
    expect(restored.club, 'North Shore BC');
    expect(restored.playingStyle, 'attacking');
    expect(restored.preferredGrip, 'forehand');
    expect(restored.shortTermGoal, 'Sharper net kills');
    expect(restored.longTermGoal, 'Regional top 8');
    expect(restored.photoPath, isNull);
  });

  test('fromMap tolerates missing optional fields', () {
    final restored = Player.fromMap({'id': 'p2', 'name': 'Kid Two'});

    expect(restored.age, isNull);
    expect(restored.club, '');
    expect(restored.longTermGoal, '');
  });
}
