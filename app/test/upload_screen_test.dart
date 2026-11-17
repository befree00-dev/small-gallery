import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:small_gallery/data/models.dart';
import 'package:small_gallery/features/studio/upload_screen.dart';
import 'package:small_gallery/state/providers.dart';

import 'fakes.dart';

XFile photo(String name) => XFile.fromData(
  img.encodePng(img.Image(width: 8, height: 8)),
  name: name,
  path: '/picked/$name',
  mimeType: 'image/png',
);

Future<void> pumpUpload(WidgetTester tester, FakeRepository repo, List<XFile> picked) async {
  // Tall enough that the whole form is built (ListView builds lazily).
  await tester.binding.setSurfaceSize(const Size(800, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await pumpWithApp(
    tester,
    const UploadScreen(),
    repo: repo,
    overrides: [
      pickImagesProvider.overrideWithValue(() async => picked),
      enableDropTargetProvider.overrideWithValue(false),
      // The studio shell normally loads this before any tab opens.
      myGalleryProvider.overrideWith((ref) async => testGallery),
    ],
  );
}

void main() {
  testWidgets('uploads each picked photo with its own title and the shared details', (tester) async {
    final repo = FakeRepository(userId: artistId);
    await pumpUpload(tester, repo, [photo('봄 개천.png'), photo('IMG_2041.png')]);

    await tester.tap(find.text('사진 선택'));
    await tester.pumpAndSettle();

    // A meaningful file name becomes the title; a camera file name does not.
    expect(find.widgetWithText(TextField, '봄 개천'), findsOneWidget, reason: 'the first new photo is selected');
    await tester.tap(find.bySemanticsLabel('IMG_2041.png'));
    await tester.pump();
    expect(find.widgetWithText(TextField, '봄 개천'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, '제목'), '비 갠 골목');
    await tester.ensureVisible(find.text('수채화'));
    await tester.tap(find.text('수채화'));
    await tester.pump();

    await tester.tap(find.text('전시실에 걸기'));
    await tester.pumpAndSettle();

    expect(repo.uploads.map((d) => d.title), ['봄 개천', '비 갠 골목']);
    expect(repo.uploads.every((d) => d.medium == '수채화' && d.roomId == testRoom.id), isTrue);
    expect(find.text('작품을 걸었어요'), findsOneWidget);
  });

  testWidgets('asks for a title before uploading', (tester) async {
    final repo = FakeRepository(userId: artistId);
    await pumpUpload(tester, repo, [photo('IMG_0001.png')]);

    await tester.tap(find.text('사진 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전시실에 걸기'));
    await tester.pumpAndSettle();

    expect(repo.uploads, isEmpty);
    expect(find.text('제목을 입력해 주세요'), findsOneWidget);
  });

  testWidgets('says so when the free plan is full and keeps the photo', (tester) async {
    final repo = FakeRepository(userId: artistId)..uploadError = const AppException('quota_exceeded');
    await pumpUpload(tester, repo, [photo('정물.png')]);

    await tester.tap(find.text('사진 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전시실에 걸기'));
    await tester.pumpAndSettle();

    expect(find.text('무료 플랜은 작품 100점까지 올릴 수 있어요'), findsOneWidget);
    expect(find.widgetWithText(TextField, '정물'), findsOneWidget);
  });
}
