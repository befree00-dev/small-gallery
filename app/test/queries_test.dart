import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// PostgREST refuses an embed when two tables are linked more than one way.
/// galleries and profiles are (owner_id, and blocked_authors), so each
/// profiles embed must name its foreign key: `profiles!<fkey>(...)`.
void main() {
  test('every profiles embed names its foreign key', () {
    final source = File('lib/data/supabase_repository.dart').readAsStringSync();
    final bare = RegExp(r'profiles\(').allMatches(source);
    expect(bare, isEmpty, reason: 'use profiles!galleries_owner_id_fkey(...) or profiles!comments_author_id_fkey(...)');
  });
}
