// Visitor pages against a small fake Supabase (PostgREST + storage) on :54321.
// Visitor pages read on the server, so the fake must be a real HTTP server.
//
//   NEXT_PUBLIC_SUPABASE_URL=http://localhost:54321 NEXT_PUBLIC_SUPABASE_ANON_KEY=test npm run build
//   npx next start -p 3201 &
//   BASE_URL=http://localhost:3201 node e2e/visitor.e2e.mjs

import { readFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { createRequire } from 'node:module';

const { chromium } = createRequire(import.meta.url)('playwright');
const BASE = process.env.BASE_URL ?? 'http://localhost:3201';
const SHOTS = process.env.SHOTS_DIR;

const id = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const gallery = {
  id: id(1), owner_id: id(9), handle: 'jisu', title: '지수의 작은 정원', title_en: null, bio: '', bio_en: null,
  theme: 'white', visibility: 'unlisted', rating_enabled: true, comment_policy: 'approve', profiles: { display_name: '김지수' },
};
const rooms = [
  { id: id(21), gallery_id: id(1), title: '봄의 산책', title_en: 'Spring walk', statement: '', statement_en: null, sort_order: 0 },
  { id: id(22), gallery_id: id(1), title: '작은 정물', title_en: null, statement: '', statement_en: null, sort_order: 1 },
];
const work = (n, room, order, title) => ({
  id: id(n), gallery_id: id(1), room_id: room, title, title_en: null, year: 2025, medium: '수채화', size_text: '', note: '',
  note_en: null, sort_order: order, is_featured: false, rating_enabled: true, image_path: `a/${n}/display.jpg`,
  thumb_path: `a/${n}/thumb.jpg`, width: 3000, height: 2000, exif: {}, like_count: 3, comment_count: 0,
});
// Stored out of order on purpose: the page must follow room order, then sort_order.
const artworks = [work(33, id(22), 0, '창가의 레몬'), work(32, id(21), 1, '비 갠 골목'), work(31, id(21), 0, '4월, 개천 옆 벚나무')];
const tables = { galleries: [gallery], rooms, artworks, comments: [], artwork_rating_stats: [] };
const otpRequests = [];
const visitorUser = { id: id(77), aud: 'authenticated', role: 'authenticated', email: 'visitor@example.com', app_metadata: {}, user_metadata: {}, created_at: '2026-11-18T00:00:00Z' };
const photo = readFileSync(new URL('./fixtures/camera-with-gps.jpg', import.meta.url));

function filterRows(rows, params) {
  return rows.filter((row) =>
    [...params].every(([key, value]) => {
      if (['select', 'order', 'limit', 'offset'].includes(key)) return true;
      if (value === 'is.null') return row[key] == null;
      if (value.startsWith('eq.')) return String(row[key]) === value.slice(3);
      if (value.startsWith('neq.')) return String(row[key]) !== value.slice(4);
      return true;
    }),
  );
}

const fake = createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  const send = (status, body, type = 'application/json') => {
    res.writeHead(status, { 'content-type': type, 'access-control-allow-origin': '*', 'access-control-allow-headers': '*' });
    res.end(type === 'application/json' ? JSON.stringify(body) : body);
  };
  if (req.method === 'OPTIONS') return send(204, '', 'text/plain');
  if (url.pathname.startsWith('/storage/v1/object/public/')) return send(200, photo, 'image/jpeg');
  if (url.pathname === '/rest/v1/rpc/has_liked') return send(200, false);
  if (url.pathname === '/rest/v1/rpc/toggle_like') return send(200, [{ liked: true, like_count: 4 }]);
  if (url.pathname.startsWith('/rest/v1/rpc/')) return send(200, null);
  if (url.pathname === '/auth/v1/otp') {
    otpRequests.push({ redirectTo: url.searchParams.get('redirect_to') });
    let body = '';
    req.on('data', (c) => (body += c));
    req.on('end', () => {
      otpRequests.at(-1).body = JSON.parse(body || '{}');
      send(200, {});
    });
    return;
  }
  if (url.pathname === '/auth/v1/user') return send(200, visitorUser);
  if (url.pathname.startsWith('/auth/v1/')) return send(200, {});
  const table = url.pathname.replace('/rest/v1/', '');
  const rows = filterRows(tables[table] ?? [], url.searchParams);
  if ((req.headers.accept ?? '').includes('vnd.pgrst.object')) {
    return rows.length ? send(200, rows[0]) : send(406, { code: 'PGRST116', message: 'no rows' });
  }
  return send(200, rows);
});
await new Promise((r) => fake.listen(54321, r));

const failures = [];
const check = (ok, message) => {
  console.log(`${ok ? '✓' : '✗'} ${message}`);
  if (!ok) failures.push(message);
};
const position = (page) => page.locator('.position').innerText();

const browser = await chromium.launch();
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  page.on('pageerror', (e) => failures.push(`page error: ${e.message}`));

  await page.goto(`${BASE}/ko/@jisu/a/${id(31)}`);
  check((await position(page)) === '1 / 3 · 봄의 산책', `first work shows its place (${await position(page)})`);
  check((await page.locator('a[rel=prev]').count()) === 0, 'no previous link on the first work');
  check((await page.locator('a[rel=next]').getAttribute('aria-label')) === '다음 작품: 비 갠 골목', 'next link names the next work');
  if (SHOTS) await page.screenshot({ path: `${SHOTS}/viewer-desktop.png` });

  await page.locator('a[rel=next]').click();
  await page.waitForURL(`**/a/${id(32)}`);
  check((await position(page)) === '2 / 3 · 봄의 산책', 'next button goes to the second work');

  await page.keyboard.press('ArrowRight');
  await page.waitForURL(`**/a/${id(33)}`);
  check((await position(page)) === '3 / 3 · 작은 정물', '→ key crosses into the next room');
  check((await page.locator('a[rel=next]').count()) === 0, 'no next link on the last work');

  await page.keyboard.press('ArrowLeft');
  await page.waitForURL(`**/a/${id(32)}`);
  check(true, '← key goes back');

  await page.locator('a[rel=prev]').click();
  await page.waitForURL(`**/a/${id(31)}`);
  check(true, 'previous button goes back');

  // Typing must not flip pages.
  await page.getByLabel('로그인하면 평가와 감상평을 남길 수 있어요').first().click();
  await page.keyboard.press('ArrowRight');
  await page.waitForTimeout(500);
  check(page.url().endsWith(id(31)), 'arrow keys inside a text field do not change the work');

  await page.goto(`${BASE}/en/@jisu/a/${id(31)}`);
  check((await position(page)) === '1 of 3 · Spring walk', 'English position and room name');

  // Link-only galleries stay out of search engines; public ones do not.
  const robots = async (path) => {
    await page.goto(`${BASE}${path}`);
    return (await page.locator('meta[name="robots"]').getAttribute('content').catch(() => null)) ?? '';
  };
  check((await robots('/ko/@jisu')).includes('noindex'), 'a link-only gallery asks search engines not to index it');
  check((await robots(`/ko/@jisu/a/${id(31)}`)).includes('noindex'), '…and its artworks');
  gallery.visibility = 'public';
  check(!(await robots('/ko/@jisu')).includes('noindex'), 'a public gallery can be indexed');
  gallery.visibility = 'unlisted';

  const phone = await browser.newPage({ viewport: { width: 390, height: 844 } });
  await phone.goto(`${BASE}/ko/@jisu/a/${id(32)}`);
  check(!(await phone.evaluate(() => document.documentElement.scrollWidth > innerWidth)), 'no sideways scrolling on a phone');
  const box = await phone.locator('a[rel=next]').boundingBox();
  check(box !== null && box.width >= 44 && box.height >= 44, 'arrow buttons are at least 44px on a phone');
  if (SHOTS) await phone.screenshot({ path: `${SHOTS}/viewer-phone.png` });
} finally {
  // Signing in from a gallery: the emailed link may open on another page (or in another
  // browser), and must still sign the visitor in and bring them back to the gallery.
  const visitor = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  await visitor.goto(`${BASE}/ko/@jisu`);
  await visitor.getByLabel('로그인하면 평가와 감상평을 남길 수 있어요').fill('visitor@example.com');
  await visitor.getByRole('button', { name: '로그인 링크 받기' }).click();
  await visitor.getByText('메일로 로그인 링크를 보냈어요').waitFor();
  const otp = otpRequests.at(-1);
  check(otp?.redirectTo === `${BASE}/ko/@jisu`, `the link returns to the gallery (${otp?.redirectTo})`);
  check(otp?.body && !otp.body.code_challenge, 'the link does not depend on the requesting browser (no PKCE challenge)');

  // Supabase falls back to the site root when a redirect is not allow-listed: still lands back in the gallery.
  const token = 'header.' + Buffer.from(JSON.stringify({ sub: id(77), exp: Math.floor(Date.now() / 1000) + 3600 })).toString('base64url') + '.sig';
  await visitor.goto(`${BASE}/ko#access_token=${token}&refresh_token=r1&expires_in=3600&expires_at=${Math.floor(Date.now() / 1000) + 3600}&token_type=bearer&type=magiclink`);
  await visitor.waitForURL(`${BASE}/ko/@jisu`, { timeout: 10000 }).catch(() => {});
  check(visitor.url() === `${BASE}/ko/@jisu`, `after the link, the visitor is back in the gallery (${visitor.url()})`);
  await visitor.getByRole('status').filter({ hasText: '로그인했어요' }).waitFor({ timeout: 5000 }).catch(() => {});
  check(await visitor.getByText('로그인했어요').isVisible(), 'a message says they are signed in');
  check((await visitor.getByLabel('로그인하면 평가와 감상평을 남길 수 있어요').count()) === 0, 'the email form is replaced by the comment form');
  if (SHOTS) await visitor.screenshot({ path: `${SHOTS}/signed-in.png` });

  // An expired link explains itself instead of doing nothing.
  const fresh = await browser.newPage({ viewport: { width: 390, height: 844 } });
  await fresh.goto(`${BASE}/ko/@jisu#error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid+or+has+expired`);
  await fresh.getByRole('alert').filter({ hasText: '만료' }).waitFor({ timeout: 5000 }).catch(() => {});
  check(await fresh.getByText('로그인 링크가 만료됐거나').isVisible(), 'an expired link shows what to do');
  check(!(await fresh.evaluate(() => location.hash.includes('error'))), 'the error is cleared from the address');
  check(!(await fresh.evaluate(() => document.documentElement.scrollWidth > innerWidth)), 'the message fits a phone');
  if (SHOTS) await fresh.screenshot({ path: `${SHOTS}/link-expired.png` });

  await browser.close();
  fake.close();
}

if (failures.length) {
  console.error(`\n${failures.length} check(s) failed:\n- ${failures.join('\n- ')}`);
  process.exit(1);
}
console.log('\nAll visitor checks passed.');
