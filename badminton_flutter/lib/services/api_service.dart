import '../models/match_log.dart';
import '../models/player.dart';
import '../models/session.dart';
import '../models/tournament.dart';
import 'api_client.dart';

/// The web build's data layer: mirrors DatabaseService's surface, speaking
/// the backend's player-scoped routes. Payloads are exactly the models'
/// toMap()/fromMap() maps — no translation layer.
class ApiService {
  final ApiClient _client;
  final String Function() activePlayerId;

  ApiService({required ApiClient client, required this.activePlayerId})
      : _client = client;

  String get _base => '/players/${activePlayerId()}';

  // ── Sessions ─────────────────────────────────────────────────────────────

  Future<List<TrainingSession>> getSessions() async {
    final body = await _client.getJson('$_base/sessions') as List;
    return [
      for (final item in body)
        TrainingSession.fromMap(item as Map<String, dynamic>),
    ];
  }

  Future<void> insertSession(TrainingSession session) =>
      _client.postJson('$_base/sessions', session.toMap());

  Future<void> insertSessions(List<TrainingSession> sessions) =>
      _client.postJson(
        '$_base/sessions/batch',
        [for (final s in sessions) s.toMap()],
      );

  Future<void> updateSession(TrainingSession session) =>
      _client.putJson('$_base/sessions/${session.id}', session.toMap());

  Future<void> deleteSession(String id) =>
      _client.delete('$_base/sessions/$id');

  Future<bool> hasAnySessions() async {
    final body = await _client.getJson('$_base/sessions/any');
    return body['any'] as bool;
  }

  // ── Match logs ───────────────────────────────────────────────────────────

  Future<List<MatchLog>> getMatchLogs() async {
    final body = await _client.getJson('$_base/match-logs') as List;
    return [
      for (final item in body) MatchLog.fromMap(item as Map<String, dynamic>),
    ];
  }

  Future<void> insertMatchLog(MatchLog log) =>
      _client.postJson('$_base/match-logs', log.toMap());

  Future<void> insertMatchLogs(List<MatchLog> logs) => _client.postJson(
        '$_base/match-logs/batch',
        [for (final log in logs) log.toMap()],
      );

  Future<void> updateMatchLog(MatchLog log) =>
      _client.putJson('$_base/match-logs/${log.id}', log.toMap());

  Future<void> deleteMatchLog(String id) =>
      _client.delete('$_base/match-logs/$id');

  Future<bool> hasAnyMatchLogs() async {
    final body = await _client.getJson('$_base/match-logs/any');
    return body['any'] as bool;
  }

  // ── Tournaments ──────────────────────────────────────────────────────────

  Future<List<Tournament>> getTournaments() async {
    final body = await _client.getJson('$_base/tournaments') as List;
    return [
      for (final item in body)
        Tournament.fromMap(
          item as Map<String, dynamic>,
          matches: [
            for (final m in (item['matches'] as List? ?? []))
              TournamentMatch.fromMap(m as Map<String, dynamic>),
          ],
        ),
    ];
  }

  Future<void> insertTournament(Tournament tournament) =>
      _client.postJson('$_base/tournaments', tournament.toMap());

  Future<void> deleteTournament(String id) =>
      _client.delete('$_base/tournaments/$id');

  Future<void> insertMatch(TournamentMatch match) => _client.postJson(
        '$_base/tournaments/${match.tournamentId}/matches',
        match.toMap(),
      );

  Future<void> deleteMatch(String id) async {
    // DatabaseService's surface only carries the match id; resolve its
    // tournament from the nested list (family-scale data, one extra GET).
    for (final tournament in await getTournaments()) {
      for (final match in tournament.matches) {
        if (match.id == id) {
          await _client.delete(
            '$_base/tournaments/${tournament.id}/matches/$id',
          );
          return;
        }
      }
    }
  }

  // ── Custom tags ──────────────────────────────────────────────────────────

  Future<List<String>> getCustomTags() async {
    final body = await _client.getJson('$_base/tags') as List;
    return body.cast<String>();
  }

  Future<void> insertCustomTag(String name) =>
      _client.postJson('$_base/tags', {'name': name});

  Future<void> deleteCustomTag(String name) =>
      _client.delete('$_base/tags/${Uri.encodeComponent(name)}');

  // ── Players (used by PlayerProvider via its own client, here for reuse) ──

  Future<List<Player>> getPlayers() async {
    final body = await _client.getJson('/players') as List;
    return [
      for (final item in body) Player.fromMap(item as Map<String, dynamic>),
    ];
  }
}
