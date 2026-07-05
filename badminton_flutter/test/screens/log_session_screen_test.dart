import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:badminton_flutter/models/reflection_data.dart';
import 'package:badminton_flutter/models/session.dart';
import 'package:badminton_flutter/providers/session_provider.dart';
import 'package:badminton_flutter/screens/train/log_session_screen.dart';
import 'package:badminton_flutter/services/database_service.dart';
import 'package:badminton_flutter/widgets/star_rating.dart';

final _existing = TrainingSession(
  id: 'edit-me',
  date: DateTime(2026, 7, 3),
  durationMinutes: 90,
  drills: const ['Footwork', 'Shadow Drill'], // second one is NOT built-in
  intensity: 4,
  notes: 'existing notes',
  sessionGoal: 'Original goal',
  goalAchievementScore: 4,
  playerRemarks: 'net kills were sharp',
  coachRemarks: 'good recovery steps',
  reflectionAnswersJson: encodeReflectionAnswers([
    ReflectionAnswer(
      questionKey: kReflectionQuestions[0],
      answer: 'coach picked the goal',
    ),
  ]),
);

Widget _app(SessionProvider provider, {TrainingSession? session}) =>
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: LogSessionScreen(session: session)),
    );

/// The redesigned form is tall; a big surface keeps every section built so
/// finders and taps work without scroll choreography.
Future<void> _pumpTall(
  WidgetTester tester,
  SessionProvider provider, {
  TrainingSession? session,
}) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(provider, session: session));
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbName = 'log_session_screen_test.db';
  });

  Future<SessionProvider> seed(
    WidgetTester tester, {
    bool insertExisting = false,
  }) async {
    final provider = SessionProvider();
    await tester.runAsync(() async {
      await DatabaseService.resetForTests();
      await provider.loadSessions();
      if (insertExisting) await provider.addSession(_existing);
    });
    return provider;
  }

  Future<void> saveViaButton(WidgetTester tester, String label) async {
    await tester.runAsync(() async {
      await tester.tap(find.text(label, skipOffstage: false));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
  }

  group('mode chrome', () {
    testWidgets('create mode keeps Log Session title and Save Session button', (
      tester,
    ) async {
      final provider = await seed(tester);

      await _pumpTall(tester, provider);

      expect(find.text('Log Session'), findsOneWidget);
      expect(find.text('Save Session', skipOffstage: false), findsOneWidget);
      expect(find.text('Update Session', skipOffstage: false), findsNothing);
    });

    testWidgets(
      'edit mode shows Edit Session title and Update Session button',
      (tester) async {
        final provider = await seed(tester);

        await _pumpTall(tester, provider, session: _existing);

        expect(find.text('Edit Session'), findsOneWidget);
        expect(
          find.text('Update Session', skipOffstage: false),
          findsOneWidget,
        );
        expect(find.text('Save Session', skipOffstage: false), findsNothing);
      },
    );
  });

  group('form layout', () {
    testWidgets('goal field and reflection sections are present', (
      tester,
    ) async {
      final provider = await seed(tester);

      await _pumpTall(tester, provider);

      expect(
        find.byKey(const ValueKey('goalField'), skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('playerRemarks'), skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('coachRemarks'), skipOffstage: false),
        findsOneWidget,
      );
      for (var i = 0; i < kReflectionQuestions.length; i++) {
        expect(
          find.byKey(ValueKey('reflection-$i'), skipOffstage: false),
          findsOneWidget,
          reason: 'question $i must have an answer field',
        );
      }
      expect(find.byType(StarRating, skipOffstage: false), findsOneWidget);
    });

    testWidgets('intensity slider is gone', (tester) async {
      final provider = await seed(tester);

      await _pumpTall(tester, provider);

      expect(find.text('Intensity', skipOffstage: false), findsNothing);
    });

    testWidgets('duration lives inside a collapsed Advanced section', (
      tester,
    ) async {
      final provider = await seed(tester);

      await _pumpTall(tester, provider);

      expect(find.text('Advanced', skipOffstage: false), findsOneWidget);
      expect(
        find.byType(Slider, skipOffstage: false),
        findsNothing,
        reason: 'duration slider hidden until Advanced is expanded',
      );

      await tester.tap(find.text('Advanced'));
      await tester.pumpAndSettle();

      expect(find.byType(Slider, skipOffstage: false), findsOneWidget);
    });
  });

  group('validation', () {
    testWidgets('save is blocked with a snackbar when the goal is empty', (
      tester,
    ) async {
      final provider = await seed(tester);

      await _pumpTall(tester, provider);
      await tester.tap(find.widgetWithText(FilterChip, 'Footwork'));
      await tester.pump();
      await saveViaButton(tester, 'Save Session');

      expect(
        find.textContaining('goal'),
        findsWidgets,
        reason: 'snackbar must say a goal is required',
      );
      expect(provider.sessions, isEmpty);
    });

    testWidgets('save is blocked when no drill is selected', (tester) async {
      final provider = await seed(tester);

      await _pumpTall(tester, provider);
      await tester.enterText(
        find.byKey(const ValueKey('goalField')),
        'Sharper smashes',
      );
      await saveViaButton(tester, 'Save Session');

      expect(find.textContaining('drill'), findsWidgets);
      expect(provider.sessions, isEmpty);
    });
  });

  group('save payload', () {
    testWidgets(
      'saved session carries goal, score, remarks, and reflection answers; intensity is null',
      (tester) async {
        final provider = await seed(tester);

        await _pumpTall(tester, provider);
        await tester.enterText(
          find.byKey(const ValueKey('goalField')),
          'Sharper smashes',
        );
        await tester.tap(find.widgetWithText(FilterChip, 'Smash'));
        await tester.pump();

        await tester.enterText(
          find.byKey(const ValueKey('reflection-0')),
          'coach picked it',
        );
        await tester.enterText(
          find.byKey(const ValueKey('playerRemarks')),
          'felt strong',
        );
        await tester.enterText(
          find.byKey(const ValueKey('coachRemarks')),
          'watch the base',
        );
        await saveViaButton(tester, 'Save Session');

        final saved = provider.sessions.single;
        expect(saved.sessionGoal, 'Sharper smashes');
        expect(
          saved.intensity,
          isNull,
          reason: 'new sessions have no intensity rating',
        );
        expect(saved.playerRemarks, 'felt strong');
        expect(saved.coachRemarks, 'watch the base');
        final answers = decodeReflectionAnswers(saved.reflectionAnswersJson);
        expect(
          answers,
          hasLength(1),
          reason: 'empty answers are skipped, answered ones kept',
        );
        expect(answers.single.questionKey, kReflectionQuestions[0]);
        expect(answers.single.answer, 'coach picked it');
      },
    );

    testWidgets('star tap sets goalAchievementScore on the saved session', (
      tester,
    ) async {
      final provider = await seed(tester);

      await _pumpTall(tester, provider);
      await tester.enterText(
        find.byKey(const ValueKey('goalField')),
        'Sharper smashes',
      );
      await tester.tap(find.widgetWithText(FilterChip, 'Smash'));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.star_border).last);
      await tester.pump();
      await saveViaButton(tester, 'Save Session');

      expect(provider.sessions.single.goalAchievementScore, 5);
    });
  });

  group('custom drill tags', () {
    testWidgets('New tag chip opens a dialog and adds a selectable chip', (
      tester,
    ) async {
      final provider = await seed(tester);

      await _pumpTall(tester, provider);
      await tester.tap(find.text('New tag'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Deception',
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Add'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      final chipFinder = find.widgetWithText(FilterChip, 'Deception');
      expect(
        chipFinder,
        findsOneWidget,
        reason: 'the new tag must appear as a drill chip',
      );
      await tester.tap(chipFinder);
      await tester.pump();
      expect(tester.widget<FilterChip>(chipFinder).selected, isTrue);
    });

    testWidgets('long-press deletes a custom tag after confirmation', (
      tester,
    ) async {
      final provider = await seed(tester);
      await tester.runAsync(() => provider.addCustomTag('Deception'));

      await _pumpTall(tester, provider);
      await tester.longPress(find.widgetWithText(FilterChip, 'Deception'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Delete'),
        findsWidgets,
        reason: 'deleting a tag must confirm first',
      );

      await tester.runAsync(() async {
        await tester.tap(find.text('Delete'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilterChip, 'Deception'), findsNothing);
      expect(provider.customTags, isEmpty);
    });

    testWidgets('long-press on a built-in drill does nothing', (tester) async {
      final provider = await seed(tester);

      await _pumpTall(tester, provider);
      await tester.longPress(find.widgetWithText(FilterChip, 'Footwork'));
      await tester.pumpAndSettle();

      expect(
        find.byType(AlertDialog),
        findsNothing,
        reason: 'built-in drills are not deletable',
      );
    });
  });

  group('edit mode', () {
    testWidgets('pre-fills goal, remarks, reflection answers, and star score', (
      tester,
    ) async {
      final provider = await seed(tester, insertExisting: true);

      await _pumpTall(tester, provider, session: _existing);

      expect(find.text('Original goal', skipOffstage: false), findsOneWidget);
      expect(
        find.text('net kills were sharp', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('good recovery steps', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('coach picked the goal', skipOffstage: false),
        findsOneWidget,
      );
      final stars = tester.widget<StarRating>(
        find.byType(StarRating, skipOffstage: false),
      );
      expect(stars.value, 4);
    });

    testWidgets('pre-fills date and pre-selects drills incl. non-built-in', (
      tester,
    ) async {
      final provider = await seed(tester, insertExisting: true);

      await _pumpTall(tester, provider, session: _existing);

      expect(find.text('Fri, 3 Jul 2026'), findsOneWidget);
      final footworkChip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Footwork'),
      );
      expect(footworkChip.selected, isTrue);
      final shadowChip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Shadow Drill'),
      );
      expect(
        shadowChip.selected,
        isTrue,
        reason: 'legacy/custom drills must not be dropped in edit mode',
      );
    });

    testWidgets(
      'updating keeps the id, edits the goal, keeps legacy intensity',
      (tester) async {
        final provider = await seed(tester, insertExisting: true);

        await _pumpTall(tester, provider, session: _existing);
        await tester.enterText(
          find.byKey(const ValueKey('goalField')),
          'Edited goal',
        );
        await tester.pump();
        await saveViaButton(tester, 'Update Session');

        expect(
          provider.sessions,
          hasLength(1),
          reason: 'update must not duplicate the session',
        );
        final updated = provider.sessions.single;
        expect(updated.id, 'edit-me');
        expect(updated.sessionGoal, 'Edited goal');
        expect(
          updated.intensity,
          4,
          reason: 'legacy intensity is preserved through edits',
        );
      },
    );
  });
}
