// End-to-end check of the web studio in real Chromium, with Supabase mocked.
//
//   NEXT_PUBLIC_SUPABASE_URL=https://test.supabase.co NEXT_PUBLIC_SUPABASE_ANON_KEY=test npm run build
//   npx next start -p 3200 &
//   BASE_URL=http://localhost:3200 node e2e/studio.e2e.mjs
//
// Walks: sign in → create a gallery → upload a photo that carries GPS data,
// and checks that what leaves the browser has no EXIF and no location.

import { readFileSync, mkdirSync } from 'node:fs';
import { createRequire } from 'node:module';

// Playwright is installed globally in CI images; resolve it the CommonJS way.
const { chromium } = createRequire(import.meta.url)('playwright');

const BASE = process.env.BASE_URL ?? 'http://localhost:3200';
const SUPABASE = 'https://test.supabase.co';
const SHOTS = process.env.SHOTS_DIR;
const USER = { id: '00000000-0000-4000-8000-00000000000a', aud: 'authenticated', role: 'authenticated', email: 'artist@example.com' };

const state = { gallery: null, rooms: [], artworks: [], uploads: {}, inserts: [] };

function json(route, status, body, headers = {}) {
  return route.fulfill({ status, contentType: 'application/json', headers: { 'access-control-allow-origin': '*', ...headers }, body: JSON.stringify(body) });
}

/** PostgREST answers single()/maybeSingle() with an object when asked for one. */
function rows(route, list) {
  const wantsObject = (route.request().headers()['accept'] ?? '').includes('vnd.pgrst.object');
  if (wantsObject) return list.length ? json(route, 200, list[0]) : json(route, 406, { code: 'PGRST116', message: 'no rows' });
  return json(route, 200, list);
}

async function mockSupabase(page) {
  await page.route(`${SUPABASE}/**`, async (route) => {
    const req = route.request();
    const url = new URL(req.url());
    const method = req.method();
    if (method === 'OPTIONS') return route.fulfill({ status: 204, headers: { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*', 'access-control-allow-methods': '*' } });

    if (url.pathname === '/auth/v1/token') {
      const now = Math.floor(Date.now() / 1000);
      return json(route, 200, { access_token: 'test-token', token_type: 'bearer', expires_in: 3600, expires_at: now + 3600, refresh_token: 'refresh', user: USER });
    }
    if (url.pathname.startsWith('/auth/v1/')) return json(route, 200, {});

    if (url.pathname.startsWith('/storage/v1/object/public/')) return route.fulfill({ status: 404 });
    if (url.pathname.startsWith('/storage/v1/object/') && method === 'POST') {
      state.uploads[url.pathname.replace('/storage/v1/object/', '')] = req.postDataBuffer() ?? Buffer.alloc(0);
      return json(route, 200, { Key: url.pathname });
    }

    const table = url.pathname.replace('/rest/v1/', '');
    const body = req.postDataJSON?.() ?? null;

    if (table === 'galleries') {
      if (method === 'POST') {
        // Like the database default: new galleries start link-only.
        state.gallery = { id: 'g1', owner_id: USER.id, bio: '', title_en: null, bio_en: null, visibility: 'unlisted', rating_enabled: true, comment_policy: 'approve', ...body };
        return rows(route, [state.gallery]);
      }
      if (method === 'PATCH') return json(route, 204, null);
      const handle = url.searchParams.get('handle');
      if (handle) return rows(route, state.gallery && `eq.${state.gallery.handle}` === handle ? [state.gallery] : []);
      return rows(route, state.gallery ? [state.gallery] : []);
    }
    if (table === 'reserved_handles') return rows(route, []);
    if (table === 'rooms') {
      if (method === 'POST') {
        const room = { id: `r${state.rooms.length + 1}`, statement: '', title_en: null, statement_en: null, visibility: 'public', ...body };
        state.rooms.push(room);
        return rows(route, [{ ...room, artworks: [{ count: 0 }] }]);
      }
      return rows(route, state.rooms.map((r) => ({ ...r, artworks: [{ count: state.artworks.filter((a) => a.room_id === r.id).length }] })));
    }
    if (table === 'artworks') {
      if (method === 'POST') {
        state.inserts.push(body);
        state.artworks.push({ like_count: 0, comment_count: 0, visibility: 'public', is_featured: false, ...body });
        return json(route, 201, null);
      }
      if (method === 'HEAD') return route.fulfill({ status: 200, headers: { 'content-range': `*/${state.artworks.length}`, 'access-control-allow-origin': '*', 'access-control-expose-headers': 'content-range' } });
      return rows(route, state.artworks);
    }
    if (table === 'profiles') return rows(route, [{ plan: 'free' }]);
    return rows(route, []);
  });
}

const failures = [];
function check(ok, message) {
  console.log(`${ok ? '✓' : '✗'} ${message}`);
  if (!ok) failures.push(message);
}

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
page.on('pageerror', (e) => failures.push(`page error: ${e.message}`));
await mockSupabase(page);
if (SHOTS) mkdirSync(SHOTS, { recursive: true });
const shot = async (name) => SHOTS && page.screenshot({ path: `${SHOTS}/${name}.png`, fullPage: true });

// Home page offers the studio.
await page.goto(`${BASE}/ko`);
check(await page.getByRole('link', { name: '무료로 시작하기' }).waitFor({ timeout: 5000 }).then(() => true, () => false), 'home page links to the studio');
await shot('1-home');

// Sign in.
await page.goto(`${BASE}/ko/studio`);
await page.getByLabel('이메일').fill(USER.email);
await page.getByLabel('비밀번호').fill('correct-horse');
await shot('2-sign-in');
await page.getByRole('button', { name: '로그인' }).first().click();
await page.getByRole('heading', { name: '내 갤러리 만들기' }).waitFor();
check(true, 'a new artist is taken to "create your gallery"');

// Create the gallery.
await page.getByLabel('사진').check();
await page.getByRole('button', { name: '다음' }).click();
await page.getByLabel('갤러리 이름').fill('민호의 풍경');
await page.getByLabel('갤러리 주소').fill('Minho_Photo');
await page.getByText('쓸 수 있는 주소예요').waitFor();
check(true, 'the address is checked and normalized');
await shot('3-create-address');
await page.getByRole('button', { name: '다음' }).click();
check(await page.getByText('처음에는 링크가 있는 사람만 볼 수 있어요', { exact: false }).isVisible(), 'creating a gallery says it starts link-only');
check((await page.locator('.theme-swatch').count()) === 6, 'six themes to choose from');
await shot('3b-themes');
await page.getByText('다크 룸').click();
await page.getByRole('button', { name: '갤러리 열기' }).click();
await page.getByRole('heading', { name: '민호의 풍경' }).waitFor();
check(state.gallery?.handle === 'minho_photo' && state.gallery?.theme === 'dark' && state.gallery?.field === 'photo', 'gallery created with handle, theme and field');
check(await page.getByText('첫 번째 전시실').waitFor({ timeout: 5000 }).then(() => true, () => false), 'a first room is created');
check(await page.getByText('공개 범위: 링크가 있는 사람만').isVisible(), 'the studio shows the gallery is link-only');
check((await page.locator('.room-row', { hasText: '첫 번째 전시실' }).innerText()).includes('링크가 있는 사람만'), 'a room inside shows what actually applies, not "public"');
await shot('4-studio-home');

// Upload a photo that carries GPS data.
await page.getByRole('link', { name: '업로드' }).first().click();
await page.locator('input[type=file]').setInputFiles('e2e/fixtures/camera-with-gps.jpg');
check((await page.getByLabel('제목', { exact: true }).inputValue()) === 'camera-with-gps', 'title starts from the file name');
await page.getByLabel('제목', { exact: true }).fill('개천의 봄');
await page.getByRole('button', { name: '사진', exact: true }).click();
await page.getByLabel('작가명 워터마크 넣기').check();
await shot('5-upload');
await page.getByRole('button', { name: '전시실에 걸기' }).click();
await page.getByText('작품을 걸었어요').waitFor();

const insert = state.inserts[0] ?? {};
check(insert.title === '개천의 봄' && insert.medium === '사진' && insert.watermark === true && insert.room_id === 'r1', 'artwork row saved with its details');
check(insert.width === 2048 && insert.height === 1365, `display image fits 2048px (got ${insert.width}×${insert.height})`);
check(JSON.stringify(insert.exif) === JSON.stringify({ camera: 'FUJIFILM X-T30', iso: '400' }), `camera details kept (${JSON.stringify(insert.exif)})`);

const display = Object.entries(state.uploads).find(([k]) => k.startsWith('artworks/') && k.endsWith('display.jpg'))?.[1];
const thumb = Object.entries(state.uploads).find(([k]) => k.startsWith('artworks/') && k.endsWith('thumb.jpg'))?.[1];
const original = Object.entries(state.uploads).find(([k]) => k.startsWith('originals/'))?.[1];
const hasExif = (buf) => buf.includes(Buffer.from('Exif\0\0'));
const isJpeg = (buf) => buf.includes(Buffer.from([0xff, 0xd8, 0xff]));
check(display && isJpeg(display) && !hasExif(display), 'display image uploaded as JPEG without any EXIF (GPS included)');
check(thumb && isJpeg(thumb) && !hasExif(thumb), 'thumbnail uploaded without any EXIF');
// Chromium does not expose the bytes of a user-picked File to interception,
// so only the request itself can be checked here.
check(original !== undefined, 'the original goes to the private originals bucket');
check(Object.keys(state.uploads).every((k) => k.split('/')[1] === USER.id), 'files go under the artist\'s own folder');
check(readFileSync('e2e/fixtures/camera-with-gps.jpg').includes(Buffer.from('Exif\0\0')), 'fixture really has EXIF');

// The room lists the new work.
await page.getByRole('link', { name: '갤러리' }).first().click();
await page.getByRole('link', { name: /첫 번째 전시실/ }).click();
await page.getByText('개천의 봄').waitFor();
check(true, 'the room lists the uploaded work');
const roomSelect = page.getByLabel('공개 범위', { exact: true }).first();
check((await roomSelect.locator('option:checked').innerText()) === '갤러리와 같게 (지금: 링크가 있는 사람만)', 'the room says it follows the link-only gallery');
check((await page.getByText('방문자에게 적용: 링크가 있는 사람만').count()) >= 1, 'the room spells out what visitors get');
check((await roomSelect.locator('option').allInnerTexts()).every((o) => o !== '전체 공개'), 'no misleading "public" choice inside a link-only gallery');
await roomSelect.selectOption('private');
check(await page.getByText('방문자에게 적용: 비공개').first().isVisible(), 'choosing private updates what visitors get');
await shot('6-room');

// Sign-out stays reachable at the bottom of the menu, even after scrolling.
await page.getByRole('link', { name: '업로드' }).first().click();
await page.locator('input[type=file]').setInputFiles('e2e/fixtures/camera-with-gps.jpg');
await page.mouse.wheel(0, 5000);
await page.waitForTimeout(300);
const signOut = page.locator('.studio-nav').getByRole('button', { name: '로그아웃' });
const inView = await signOut.evaluate((el) => {
  const r = el.getBoundingClientRect();
  return r.top >= 0 && r.bottom <= innerHeight;
});
check((await page.evaluate(() => scrollY)) > 0 && inView, 'sign-out is on screen after scrolling to the bottom');
check((await page.locator('.studio-email').innerText()) === USER.email, 'the menu shows which account is signed in');
if (SHOTS) await page.screenshot({ path: `${SHOTS}/6b-menu-signout.png` });

// English and phone width.
await page.setViewportSize({ width: 390, height: 844 });
await page.goto(`${BASE}/en/studio/upload`);
await page.getByRole('heading', { name: 'Upload work' }).waitFor();
check(true, 'studio works in English');
const overflow = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth);
check(!overflow, 'no sideways scrolling at phone width');
await shot('7-phone-en');
await page.locator('.studio-nav').getByRole('button', { name: 'Sign out' }).click();
check(await page.getByRole('heading', { name: 'Sign in' }).waitFor({ timeout: 5000 }).then(() => true, () => false), 'sign-out from the menu returns to sign-in');

await browser.close();
if (failures.length) {
  console.error(`\n${failures.length} check(s) failed:\n- ${failures.join('\n- ')}`);
  process.exit(1);
}
console.log('\nAll studio checks passed.');
