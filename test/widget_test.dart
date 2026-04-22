import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:grouping_app/models/player.dart';
import 'package:grouping_app/services/match_maker.dart';

void main() {
  group('MatchMaker', () {
    List<Player> roster(int n) => [
      for (var i = 0; i < n; i++) Player(id: 'p$i', name: 'P$i'),
    ];

    test('人數 < 4 時無法開始', () {
      final m = MatchMaker(random: Random(1));
      expect(m.canStart(3), isFalse);
      expect(m.resolvedCourts(3, 2), 0);
    });

    test('4~7 人僅使用 1 個場地', () {
      final m = MatchMaker(random: Random(1));
      expect(m.resolvedCourts(4, 2), 1);
      expect(m.resolvedCourts(7, 2), 1);
    });

    test('8 人可使用 2 場地（尊重使用者偏好）', () {
      final m = MatchMaker(random: Random(1));
      expect(m.resolvedCourts(8, 2), 2);
      expect(m.resolvedCourts(8, 1), 1);
    });

    test('上場後 waitingRounds 歸零、未上場 +1', () {
      final m = MatchMaker(random: Random(42));
      final list = roster(6);
      final r1 = m.buildRound(roster: list, preferredCourts: 1, roundNumber: 1);
      expect(r1.courts.single.length, 4);
      expect(r1.waitingList.length, 2);

      m.commitRound(roster: list, result: r1);
      final playingIds = r1.currentPlaying.map((p) => p.id).toSet();
      for (final p in list) {
        if (playingIds.contains(p.id)) {
          expect(p.waitingRounds, 0);
          expect(p.gamesPlayed, 1);
          expect(p.lastPlayedRound, 1);
        } else {
          expect(p.waitingRounds, 1);
          expect(p.gamesPlayed, 0);
        }
      }
    });

    test('下一輪會優先讓等待中的人上場（6 人 / 1 場地）', () {
      final m = MatchMaker(random: Random(42));
      final list = roster(6);
      final r1 = m.buildRound(roster: list, preferredCourts: 1, roundNumber: 1);
      m.commitRound(roster: list, result: r1);

      final r2 = m.buildRound(roster: list, preferredCourts: 1, roundNumber: 2);
      final waitingIdsAfterR1 = r1.waitingList.map((p) => p.id).toSet();
      final playingIdsR2 = r2.currentPlaying.map((p) => p.id).toSet();
      // 之前 2 位等待者必定在第 2 輪上場。
      expect(playingIdsR2.containsAll(waitingIdsAfterR1), isTrue);
    });
  });
}
