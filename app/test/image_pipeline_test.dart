import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:small_gallery/data/image_pipeline.dart';
import 'package:small_gallery/data/models.dart';

/// A camera-like JPEG: 3000×2000, with make/model, exposure and a GPS position.
Uint8List cameraJpeg({int width = 3000, int height = 2000, int orientation = 1}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 180, 160));
  image.exif.imageIfd[0x010F] = 'FUJIFILM';
  image.exif.imageIfd[0x0110] = 'X-T30';
  image.exif.imageIfd[0x0112] = orientation;
  image.exif.exifIfd[0x8827] = 400;
  image.exif.gpsIfd[0x0001] = 'N';
  image.exif.gpsIfd[0x0002] = img.IfdValueRational.list([img.Rational(37, 1), img.Rational(33, 1), img.Rational(0, 1)]);
  return img.encodeJpg(image);
}

void main() {
  test('makes a 2048px display image and a 480px thumbnail', () {
    final out = processImage(cameraJpeg());
    expect((out.width, out.height), (2048, 1365));
    final thumb = img.decodeJpg(out.thumbnail)!;
    expect(thumb.width, 480);
  });

  test('keeps small images at their own size', () {
    final out = processImage(cameraJpeg(width: 800, height: 600));
    expect((out.width, out.height), (800, 600));
  });

  test('strips all EXIF, GPS included, from what visitors download', () {
    final source = cameraJpeg();
    expect(img.decodeJpgExif(source)!.gpsIfd.isEmpty, isFalse, reason: 'fixture has GPS');

    final out = processImage(source);
    for (final bytes in [out.display, out.thumbnail]) {
      final exif = img.decodeJpgExif(bytes);
      expect(exif == null || exif.isEmpty, isTrue);
    }
    expect(out.exif.keys, isNot(contains(anyOf('gps', 'latitude', 'longitude'))));
  });

  test('keeps camera details worth showing', () {
    final out = processImage(cameraJpeg());
    expect(out.exif['camera'], 'FUJIFILM X-T30');
    expect(out.exif['iso'], '400');
  });

  test('turns portrait photos upright using the EXIF orientation', () {
    final out = processImage(cameraJpeg(width: 3000, height: 2000, orientation: 6));
    expect(out.height > out.width, isTrue);
  });

  test('adds a watermark without changing the size', () {
    final plain = processImage(cameraJpeg(width: 1600, height: 1200));
    final marked = processImage(cameraJpeg(width: 1600, height: 1200), watermark: 'jisu');
    expect((marked.width, marked.height), (plain.width, plain.height));
    expect(marked.display, isNot(equals(plain.display)));
  });

  test('refuses files that are not images', () {
    expect(
      () => processImage(Uint8List.fromList(List.filled(64, 7))),
      throwsA(isA<AppException>().having((e) => e.code, 'code', 'unsupported_image')),
    );
  });

  test('refuses files over 50 MB before decoding', () {
    expect(
      () => processImage(Uint8List(maxUploadBytes + 1)),
      throwsA(isA<AppException>().having((e) => e.code, 'code', 'file_too_large')),
    );
  });
}
