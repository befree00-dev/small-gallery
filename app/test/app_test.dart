import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_gallery/app.dart';
import 'package:small_gallery/data/models.dart';
import 'package:small_gallery/state/providers.dart';

import 'fakes.dart';

Future<ProviderContainer> pumpApp(WidgetTester tester, FakeRepository repo, {String locale = 'ko'}) async {
  SharedPreferences.setMockInitialValues({'app_locale': locale});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [repositoryProvider.overrideWithValue(repo), prefsProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const SmallGalleryApp()));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('signed-out people land on the welcome screen', (tester) async {
    await pumpApp(tester, FakeRepository());
    expect(find.text('누구나 자신만의 작은 갤러리를 가질 수 있는 곳'), findsOneWidget);
  });

  testWidgets('the welcome screen switches to English', (tester) async {
    await pumpApp(tester, FakeRepository());
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    expect(find.text('Where anyone can have a small gallery of their own'), findsOneWidget);
  });

  testWidgets('an artist goes straight to their gallery and its rooms', (tester) async {
    await pumpApp(tester, FakeRepository(userId: artistId));
    expect(find.text('지수의 작은 정원'), findsOneWidget);
    expect(find.text('봄의 산책'), findsOneWidget);
    expect(find.text('업로드'), findsOneWidget, reason: 'studio navigation is shown');
  });

  testWidgets('a new account is sent to onboarding', (tester) async {
    await pumpApp(tester, FakeRepository(userId: artistId)..gallery = null);
    expect(find.text('어떤 작품을 하시나요?'), findsOneWidget);
  });

  testWidgets('signing in moves from welcome to the studio', (tester) async {
    final repo = FakeRepository();
    await pumpApp(tester, repo);
    repo.signInAs(artistId);
    await tester.pumpAndSettle();
    expect(find.text('지수의 작은 정원'), findsOneWidget);
  });

  testWidgets('visitors open a gallery and an artwork without an account', (tester) async {
    // Images fail to load in tests (no network); their error placeholder is what renders.
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = await pumpApp(tester, FakeRepository());
    final router = container.read(routerProvider);
    router.go('/g/jisu');
    await tester.pumpAndSettle();
    expect(find.text('지수의 작은 정원'), findsOneWidget);
    expect(find.text('방명록'), findsOneWidget);

    await tester.tap(find.text('4월, 개천 옆 벚나무'));
    await tester.pumpAndSettle();
    expect(find.text('공감 128'), findsOneWidget);

    await tester.tap(find.text('공감 128'));
    await tester.pumpAndSettle();
    expect(find.text('공감 129'), findsOneWidget);
  });

  testWidgets('an unknown address says the gallery was not found', (tester) async {
    final container = await pumpApp(tester, FakeRepository());
    container.read(routerProvider).go('/g/nobody');
    await tester.pumpAndSettle();
    expect(find.text('갤러리를 찾을 수 없어요'), findsOneWidget);
  });

  testWidgets('when loading the gallery fails, the artist can sign out', (tester) async {
    final repo = _FailingGalleryRepository();
    await pumpApp(tester, repo);
    expect(find.text('문제가 생겼어요. 잠시 후 다시 시도해 주세요.'), findsOneWidget);

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    expect(find.text('누구나 자신만의 작은 갤러리를 가질 수 있는 곳'), findsOneWidget);
  });

  testWidgets('visitors step through works with buttons and arrow keys, across rooms', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeRepository();
    // Room order then sort order; stored out of order on purpose.
    repo.rooms_.add(const Room(id: 'r2', galleryId: 'g1', title: '작은 정물', sortOrder: 1));
    repo.artworks_.insertAll(0, [_work('a3', 'r2', 0, '창가의 레몬'), _work('a2', 'r1', 1, '비 갠 골목')]);
    final container = await pumpApp(tester, repo);
    container.read(routerProvider).go('/g/jisu/a/a1');
    await tester.pumpAndSettle();

    expect(find.text('1 / 3 · 봄의 산책'), findsOneWidget);
    expect(find.byTooltip('이전 작품: 4월, 개천 옆 벚나무'), findsNothing);

    await tester.tap(find.byTooltip('다음 작품: 비 갠 골목'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3 · 봄의 산책'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('3 / 3 · 작은 정물'), findsOneWidget, reason: '→ crosses into the next room');
    final nextButtons = tester.widgetList<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right));
    expect(nextButtons.single.onPressed, isNull, reason: 'no next on the last work');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('2 / 3 · 봄의 산책'), findsOneWidget);
  });

  testWidgets('a feed-theme gallery shows works in a square grid', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeRepository()
      ..gallery = const Gallery(
        id: 'g1',
        ownerId: artistId,
        handle: 'jisu',
        title: '지수의 작은 정원',
        theme: GalleryTheme.feed,
      );
    final container = await pumpApp(tester, repo);
    container.read(routerProvider).go('/g/jisu');
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('4월, 개천 옆 벚나무')), findsOneWidget);
  });
}

class _FailingGalleryRepository extends FakeRepository {
  _FailingGalleryRepository() : super(userId: artistId);

  @override
  Future<Gallery?> myGallery() async {
    if (currentUserId == null) return null;
    throw const AppException('unknown:42501:permission denied');
  }
}

Artwork _work(String id, String roomId, int order, String title) => Artwork(
  id: id,
  galleryId: 'g1',
  roomId: roomId,
  title: title,
  imagePath: 'p/$id.jpg',
  thumbPath: 't/$id.jpg',
  width: 1600,
  height: 1200,
  sortOrder: order,
);
