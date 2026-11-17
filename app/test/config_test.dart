import 'package:flutter_test/flutter_test.dart';
import 'package:small_gallery/main.dart';

void main() {
  const url = 'https://qlnwtxxmoifwtbxtlwtd.supabase.co';
  const site = 'https://small-gallery-vert.vercel.app';

  test('accepts real settings', () {
    expect(configProblem(url: url, key: 'sb_publishable_VDKNwmPjeSsz7THqtBasYw_U8QoqW72', site: site), isNull);
    expect(configProblem(url: url, key: 'eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoiYW5vbiJ9.abc-_x', site: site), isNull);
  });

  test('catches what is left over from the example command', () {
    expect(configProblem(url: url, key: '여sb_publishable_abc', site: site), contains('SUPABASE_ANON_KEY'));
    expect(configProblem(url: url, key: '여기에_키', site: site), contains('SUPABASE_ANON_KEY'));
    expect(configProblem(url: url, key: 'sb_publishable_abc ', site: site), contains('SUPABASE_ANON_KEY'));
  });

  test('catches missing or malformed addresses', () {
    expect(configProblem(url: '', key: '', site: site), contains('not set'));
    expect(configProblem(url: 'qlnwtxxmoifwtbxtlwtd.supabase.co', key: 'sb_publishable_abc', site: site), contains('SUPABASE_URL'));
    expect(configProblem(url: url, key: 'sb_publishable_abc', site: 'https://실제주소.vercel.app'), contains('SITE_URL'));
    expect(configProblem(url: url, key: 'sb_publishable_abc', site: 'vercel.app'), contains('SITE_URL'));
  });
}
