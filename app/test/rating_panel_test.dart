import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:small_gallery/data/models.dart';
import 'package:small_gallery/features/visitor/rating_panel.dart';

import 'fakes.dart';

Widget panel() => const Scaffold(body: SingleChildScrollView(child: RatingPanel(gallery: testGallery, artwork: testArtwork)));

FilledButton sendButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, '평가 남기기'));

const threeRatings = RatingStats(count: 3, composition: 4, color: 4.5, technique: 3, emotion: 4);
const fiveRatings = RatingStats(count: 5, composition: 4, color: 4.5, technique: 3, emotion: 4);

void main() {
  testWidgets('a visitor scores all four criteria before sending', (tester) async {
    final repo = FakeRepository(userId: visitorId);
    await pumpWithApp(tester, panel(), repo: repo);

    expect(sendButton(tester).onPressed, isNull);

    await tester.tap(find.byTooltip('구도 4점'));
    await tester.tap(find.byTooltip('색감 5점'));
    await tester.tap(find.byTooltip('기술 3점'));
    await tester.pump();
    expect(sendButton(tester).onPressed, isNull, reason: 'one criterion is still empty');

    await tester.tap(find.byTooltip('감성 4점'));
    await tester.pump();
    expect(find.text('4 / 5'), findsNWidgets(2));

    await tester.tap(find.text('평가 남기기'));
    await tester.pumpAndSettle();

    expect(repo.ratings.single.$1, testArtwork.id);
    expect(repo.ratings.single.$2.toJson(), {'composition': 4, 'color': 5, 'technique': 3, 'emotion': 4});
    expect(find.text('평가를 작가에게 전달했어요'), findsOneWidget);
  });

  testWidgets('a returning visitor sees their earlier scores and can update them', (tester) async {
    final repo = FakeRepository(userId: visitorId)
      ..existingRating = const Rating(composition: 2, color: 3, technique: 4, emotion: 5);
    await pumpWithApp(tester, panel(), repo: repo);

    expect(find.text('평가 수정하기'), findsOneWidget);
    expect(find.text('5 / 5'), findsOneWidget);
  });

  testWidgets('visitors who are not signed in are asked to sign in', (tester) async {
    await pumpWithApp(tester, panel(), repo: FakeRepository());

    expect(find.text('로그인하면 평가와 감상평을 남길 수 있어요'), findsOneWidget);
    expect(find.byTooltip('구도 1점'), findsNothing);
  });

  testWidgets('averages stay hidden from visitors until 5 people have rated', (tester) async {
    await pumpWithApp(tester, panel(), repo: FakeRepository(userId: visitorId, stats: threeRatings));
    expect(find.textContaining('평균 평점'), findsNothing);
  });

  testWidgets('averages show once 5 people have rated', (tester) async {
    await pumpWithApp(tester, panel(), repo: FakeRepository(userId: visitorId, stats: fiveRatings));
    expect(find.text('평균 평점 · 5명 참여'), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);
  });

  testWidgets('the artist sees averages from the first rating but cannot rate', (tester) async {
    await pumpWithApp(tester, panel(), repo: FakeRepository(userId: artistId, stats: threeRatings));
    expect(find.text('평균 평점 · 3명 참여'), findsOneWidget);
    expect(find.text('내 작품은 평가할 수 없어요'), findsOneWidget);
    expect(find.text('평가 남기기'), findsNothing);
  });

  testWidgets('works in English', (tester) async {
    await pumpWithApp(tester, panel(), repo: FakeRepository(userId: visitorId), locale: const Locale('en'));
    expect(find.text('Rate this work'), findsOneWidget);
    expect(find.byTooltip('Composition: 5 stars'), findsOneWidget);
  });
}
