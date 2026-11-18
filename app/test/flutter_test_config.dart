import 'dart:async';

import 'package:small_gallery/theme.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  useWebFonts = false;
  await testMain();
}
