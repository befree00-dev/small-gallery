import 'package:flutter_test/flutter_test.dart';
import 'package:small_gallery/data/models.dart';
import 'package:small_gallery/data/supabase_repository.dart';
import 'dart:typed_data';

void main() {
  group('gallery addresses', () {
    test('normalizes what people type or paste', () {
      expect(normalizeHandle('  @Jisu '), 'jisu');
      expect(normalizeHandle('https://smallgallery.app/@jisu'), 'jisu');
      expect(normalizeHandle('smallgallery.app/jisu'), 'jisu');
    });

    test('matches the database rule', () {
      expect(isValidHandle('jisu_2025'), isTrue);
      expect(isValidHandle('ab'), isFalse);
      expect(isValidHandle('Jisu'), isFalse);
      expect(isValidHandle('ji-su'), isFalse);
      expect(isValidHandle('a' * 31), isFalse);
    });
  });

  test('shows English text only when the artist wrote one', () {
    expect(localized('봄의 산책', 'Spring walk', 'en'), 'Spring walk');
    expect(localized('봄의 산책', '  ', 'en'), '봄의 산책');
    expect(localized('봄의 산책', 'Spring walk', 'ko'), '봄의 산책');
  });

  test('reads rating averages whether Postgres sends numbers or strings', () {
    final s = RatingStats.fromJson({
      'rating_count': 5,
      'avg_composition': '3.40',
      'avg_color': 4,
      'avg_technique': 2.5,
      'avg_emotion': null,
    });
    expect([s.composition, s.color, s.technique, s.emotion], [3.4, 4.0, 2.5, 0.0]);
  });

  test('room reads its embedded artwork count', () {
    final r = Room.fromJson({
      'id': 'r1',
      'gallery_id': 'g1',
      'title': '봄',
      'artworks': [
        {'count': 8}
      ],
    });
    expect(r.artworkCount, 8);
  });

  test('blank English fields are stored as null', () {
    const g = Gallery(id: 'g', ownerId: 'o', handle: 'jisu', title: 't', titleEn: '  ');
    expect(g.toUpdateJson()['title_en'], isNull);
  });

  test('detects image types from their first bytes', () {
    expect(sniffImageType(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])), 'image/jpeg');
    expect(sniffImageType(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0, 0, 0])), 'image/png');
    expect(sniffImageType(Uint8List.fromList([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits])), 'image/webp');
    expect(sniffImageType(Uint8List.fromList([0, 0, 0, 0x18, ...'ftypheic'.codeUnits])), 'image/heic');
  });
}
