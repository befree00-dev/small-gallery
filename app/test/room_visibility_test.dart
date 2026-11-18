import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:small_gallery/data/models.dart';
import 'package:small_gallery/features/studio/room_screen.dart';
import 'package:small_gallery/state/providers.dart';

import 'fakes.dart';

void main() {
  testWidgets('a room in a link-only gallery says it follows the gallery, not "public"', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const linkOnly = Gallery(
      id: 'g1',
      ownerId: artistId,
      handle: 'jisu',
      title: '지수의 작은 정원',
      visibility: Audience.unlisted,
    );
    final repo = FakeRepository(userId: artistId, gallery: linkOnly);
    await pumpWithApp(
      tester,
      const RoomScreen(roomId: 'r1'),
      repo: repo,
      overrides: [myGalleryProvider.overrideWith((ref) async => linkOnly)],
    );

    expect(find.text('갤러리와 같게 (지금: 링크가 있는 사람만)'), findsOneWidget);
    expect(find.text('방문자에게 적용: 링크가 있는 사람만'), findsOneWidget);
    expect(find.text('전체 공개'), findsNothing);

    // Choosing private changes what visitors get.
    await tester.tap(find.text('갤러리와 같게 (지금: 링크가 있는 사람만)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('비공개 (나만 보기)').last);
    await tester.pumpAndSettle();
    expect(find.text('방문자에게 적용: 비공개'), findsOneWidget);
  });
}
