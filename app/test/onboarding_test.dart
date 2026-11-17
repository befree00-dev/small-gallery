import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:small_gallery/features/onboarding/onboarding_screen.dart';

import 'fakes.dart';

FilledButton nextButton(WidgetTester tester) => tester.widget<FilledButton>(find.byType(FilledButton));

void main() {
  testWidgets('opens a gallery in three steps with a checked address', (tester) async {
    final repo = FakeRepository(userId: artistId)..gallery = null;
    await pumpWithApp(tester, const OnboardingScreen(), repo: repo);

    // Step 1: field
    await tester.tap(find.text('사진'));
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    // Step 2: name and address
    expect(nextButton(tester).onPressed, isNull);
    await tester.enterText(find.widgetWithText(TextField, '갤러리 이름'), '민호의 풍경');
    await tester.enterText(find.widgetWithText(TextField, '갤러리 주소'), 'taken');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('이미 쓰이고 있는 주소예요'), findsOneWidget);
    expect(nextButton(tester).onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, '갤러리 주소'), 'Minho_Photo');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byIcon(Icons.check), findsOneWidget);
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    // Step 3: theme
    await tester.tap(find.text('다크 룸'));
    await tester.tap(find.widgetWithText(FilledButton, '갤러리 열기'));
    await tester.pumpAndSettle();

    expect(repo.createdGalleries, ['minho_photo']);
    expect(repo.gallery!.title, '민호의 풍경');
  });

  testWidgets('explains the address rule when it is broken', (tester) async {
    await pumpWithApp(tester, const OnboardingScreen(), repo: FakeRepository(userId: artistId)..gallery = null);
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '갤러리 주소'), 'ab');
    await tester.pump();
    // Shown once as the helper and once as the error.
    expect(find.text('영문 소문자, 숫자, _ 3–30자'), findsWidgets);
    expect(nextButton(tester).onPressed, isNull);
  });
}
