import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'models.dart';

/// Display and thumbnail images made from an upload, plus the shooting
/// details worth showing. Location data never leaves this function: the
/// encoded JPEGs carry no EXIF at all, and [exif] has no GPS fields.
class ProcessedImage {
  const ProcessedImage({
    required this.display,
    required this.thumbnail,
    required this.width,
    required this.height,
    required this.exif,
  });

  final Uint8List display;
  final Uint8List thumbnail;
  final int width;
  final int height;
  final Map<String, String> exif;
}

const maxUploadBytes = 50 * 1024 * 1024;
const displayLongEdge = 2048;
const thumbLongEdge = 480;

/// Runs [processImage] off the UI thread.
Future<ProcessedImage> processImageInBackground(Uint8List bytes, {String? watermark}) =>
    Isolate.run(() => processImage(bytes, watermark: watermark));

ProcessedImage processImage(Uint8List bytes, {String? watermark}) {
  if (bytes.lengthInBytes > maxUploadBytes) throw const AppException('file_too_large');

  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const AppException('unsupported_image');

  final exif = _readExif(decoded.exif);

  // Apply the camera's rotation to the pixels, then drop every EXIF field.
  var image = img.bakeOrientation(decoded);
  image.exif = img.ExifData();

  final display = _fit(image, displayLongEdge);
  if (watermark != null && watermark.isNotEmpty) _drawWatermark(display, watermark);
  final thumb = _fit(image, thumbLongEdge);

  return ProcessedImage(
    display: img.encodeJpg(display, quality: 88),
    thumbnail: img.encodeJpg(thumb, quality: 80),
    width: display.width,
    height: display.height,
    exif: exif,
  );
}

img.Image _fit(img.Image image, int longEdge) {
  if (image.width <= longEdge && image.height <= longEdge) return img.Image.from(image);
  return image.width >= image.height
      ? img.copyResize(image, width: longEdge, interpolation: img.Interpolation.average)
      : img.copyResize(image, height: longEdge, interpolation: img.Interpolation.average);
}

void _drawWatermark(img.Image image, String text) {
  // Bitmap fonts cover Latin only; handles are always [a-z0-9_].
  final font = image.width >= 1200 ? img.arial24 : img.arial14;
  final label = '© $text';
  final textWidth = label.codeUnits.fold<int>(0, (w, c) => w + (font.characters[c]?.xAdvance ?? font.base ~/ 2));
  final x = image.width - textWidth - 24;
  final y = image.height - font.lineHeight - 20;
  img.drawString(image, label, font: font, x: x + 1, y: y + 1, color: img.ColorRgba8(0, 0, 0, 90));
  img.drawString(image, label, font: font, x: x, y: y, color: img.ColorRgba8(255, 255, 255, 170));
}

Map<String, String> _readExif(img.ExifData exif) {
  final out = <String, String>{};
  void put(String key, img.IfdValue? value, [String Function(img.IfdValue)? format]) {
    if (value == null) return;
    final text = (format ?? (v) => v.toString().trim())(value);
    if (text.isNotEmpty && text != '0') out[key] = text;
  }

  final ifd0 = exif.imageIfd;
  final sub = exif.exifIfd;
  final make = ifd0[0x010F]?.toString().trim() ?? '';
  final model = ifd0[0x0110]?.toString().trim() ?? '';
  final camera = model.toLowerCase().startsWith(make.toLowerCase()) ? model : '$make $model'.trim();
  if (camera.isNotEmpty) out['camera'] = camera;
  put('lens', sub[0xA434]);
  put('iso', sub[0x8827], (v) => v.toInt().toString());
  put('shutter', sub[0x829A], (v) {
    final s = v.toDouble();
    if (s <= 0) return '';
    return s >= 1 ? '${s.toStringAsFixed(s % 1 == 0 ? 0 : 1)}s' : '1/${(1 / s).round()}s';
  });
  put('aperture', sub[0x829D], (v) => v.toDouble() > 0 ? 'f/${v.toDouble().toStringAsFixed(1)}' : '');
  put('focal', sub[0x920A], (v) => v.toDouble() > 0 ? '${v.toDouble().round()}mm' : '');
  return out;
}
