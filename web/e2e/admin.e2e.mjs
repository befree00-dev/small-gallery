// Admin page in real Chromium with Supabase mocked in the browser.
//
//   NEXT_PUBLIC_SUPABASE_URL=https://test.supabase.co NEXT_PUBLIC_SUPABASE_ANON_KEY=test npm run build
//   npx next start -p 3200 &
//   BASE_URL=http://localhost:3200 node e2e/admin.e2e.mjs

import { mkdirSync } from 'node:fs';
import { createRequire } from 'node:module';

const { chromium } = createRequire(import.meta.url)('playwright');
const BASE = process.env.BASE_URL ?? 'http://localhost:3200';
const SUPABASE = 'https://test.supabase.co';
const SHOTS = process.env.SHOTS_DIR;
const USER = { id: '00000000-0000-4000-8000-0000000000aa', aud: 'authenticated', role: 'authenticated', email: 'ops@example.com' };

const days = Array.from({ length: 30 }, (_, i) => {
  const d = new Date(Date.UTC(2026, 9, 20 + i));
  return { day: d.toISOString().slice(0, 10), users: i % 4, galleries: i % 3, artworks: i, comments: (i * 7) % 5, views: String(40 + ((i * 37) % 90)) };
});

function makeState(admin) {
  return {
    admin,
    calls: [],
    galleries: [
      { id: 'g1', handle: 'jisu', title: '지수의 작은 정원', owner_name: '김지수', visibility: 'public', artworks: '24', views: '512', created_at: '2026-11-18T01:00:00Z' },
      { id: 'g2', handle: 'minho_photo', title: '민호의 풍경', owner_name: '민호', visibility: 'private', artworks: '3', views: '0', created_at: '2026-11-17T09:00:00Z' },
    ],
    comments: [
      { id: 'c1', body: '분홍빛이 정말 좋아요', status: 'visible', author_name: '한결', gallery_handle: 'jisu', artwork_title: '4월, 개천 옆 벚나무', created_at: '2026-11-18T02:00:00Z' },
      { id: 'c2', body: '이건 좀 별로네요', status: 'pending', author_name: '익명', gallery_handle: 'jisu', artwork_title: null, created_at: '2026-11-18T03:00:00Z' },
    ],
    users: [
      { id: USER.id, email: 'befree@example.com', display_name: '관리자', plan: 'free', is_admin: true, email_confirmed: true, created_at: '2026-11-01T01:00:00Z', last_sign_in_at: '2026-11-18T05:00:00Z', gallery_handle: null, artworks: '0' },
      { id: 'u2', email: 'jisu@example.com', display_name: '김지수', plan: 'plus', is_admin: false, email_confirmed: true, created_at: '2026-11-18T01:00:00Z', last_sign_in_at: null, gallery_handle: 'jisu', artworks: '24' },
      { id: 'u4', email: 'other-admin@example.com', display_name: '운영2', plan: 'free', is_admin: true, email_confirmed: true, created_at: '2026-11-02T01:00:00Z', last_sign_in_at: null, gallery_handle: null, artworks: '0' },
      { id: 'u3', email: 'minho@example.com', display_name: '민호', plan: 'free', is_admin: false, email_confirmed: false, created_at: '2026-11-17T09:00:00Z', last_sign_in_at: null, gallery_handle: 'minho_photo', artworks: '3' },
    ],
    log: [],
    removed: [],
    reports: [
      { id: 'r1', target_type: 'comment', target_id: 'c2', reason: 'abuse', detail: '', reporter_name: '지수', target_label: '이건 좀 별로네요', gallery_handle: 'jisu', created_at: '2026-11-18T04:00:00Z' },
    ],
  };
}

async function mock(page, state) {
  await page.route(`${SUPABASE}/**`, async (route) => {
    const req = route.request();
    const url = new URL(req.url());
    const json = (body, status = 200) =>
      route.fulfill({ status, contentType: 'application/json', headers: { 'access-control-allow-origin': '*' }, body: JSON.stringify(body) });
    if (req.method() === 'OPTIONS') return route.fulfill({ status: 204, headers: { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*', 'access-control-allow-methods': '*' } });
    if (url.pathname === '/auth/v1/token') {
      const now = Math.floor(Date.now() / 1000);
      return json({ access_token: 't', token_type: 'bearer', expires_in: 3600, expires_at: now + 3600, refresh_token: 'r', user: USER });
    }
    if (url.pathname.startsWith('/auth/v1/')) return json({});
    if (url.pathname.startsWith('/storage/v1/object/') && req.method() === 'DELETE') {
      const bucket = url.pathname.split('/').pop();
      for (const p of req.postDataJSON()?.prefixes ?? []) state.removed.push(`${bucket}/${p}`);
      return json([]);
    }
    const fn = url.pathname.replace('/rest/v1/rpc/', '');
    const args = req.postDataJSON?.() ?? {};
    state.calls.push([fn, args]);
    const denied = () => json({ code: '42501', message: 'admin_only' }, 403);
    switch (fn) {
      case 'is_admin': return json(state.admin);
      case 'admin_overview':
        if (!state.admin) return denied();
        return json({
          day: '2026-11-18',
          users: { today: 4, total: '1203' }, galleries: { today: 3, total: '310' }, artworks: { today: 27, total: '5120' },
          comments: { today: 12, total: '2210' }, ratings: { today: 9, total: '1702' }, likes: { today: 140, total: '30551' },
          views: { today: '688', total: '120934' }, pending_comments: 1, open_reports: state.reports.length,
        });
      case 'admin_daily': return state.admin ? json(days) : denied();
      case 'admin_galleries': return json(state.galleries);
      case 'admin_comments': return json(state.comments);
      case 'admin_action_log': return json(state.log);
      case 'admin_delete_gallery': {
        const g = state.galleries.find((x) => x.id === args.p_gallery_id);
        state.galleries = state.galleries.filter((x) => x.id !== args.p_gallery_id);
        state.log.unshift({ id: `l${state.log.length}`, admin_email: USER.email, action: 'delete_gallery', target: `@${g.handle}`, detail: {}, created_at: '2026-11-18T06:00:00Z' });
        return json({ artworks: ['u2/a1/display.jpg', 'u2/a1/thumb.jpg'], originals: ['u2/a1/original'] });
      }
      case 'admin_delete_user': {
        const u = state.users.find((x) => x.id === args.p_user_id);
        state.users = state.users.filter((x) => x.id !== args.p_user_id);
        state.log.unshift({ id: `l${state.log.length}`, admin_email: USER.email, action: 'delete_user', target: u.email, detail: {}, created_at: '2026-11-18T06:01:00Z' });
        return json({ artworks: [], originals: [] });
      }
      case 'admin_users': {
        if (!state.admin) return denied();
        const q = (args.p_search ?? '').toLowerCase();
        return json(q ? state.users.filter((u) => [u.email, u.display_name, u.gallery_handle].some((v) => (v ?? '').toLowerCase().includes(q))) : state.users);
      }
      case 'admin_reports': return json(state.reports);
      case 'admin_set_comment_status':
        state.comments = state.comments.map((c) => (c.id === args.p_comment_id ? { ...c, status: args.p_status } : c));
        return json(null);
      case 'admin_resolve_report':
        state.reports = state.reports.filter((r) => r.id !== args.p_report_id);
        return json(null);
      case 'admin_set_gallery_visibility':
        state.galleries = state.galleries.map((g) => (g.id === args.p_gallery_id ? { ...g, visibility: args.p_visibility } : g));
        return json(null);
      default: return json([]);
    }
  });
}

async function signIn(page) {
  await page.goto(`${BASE}/ko/admin`);
  await page.getByLabel('이메일').fill(USER.email);
  await page.getByLabel('비밀번호').fill('correct-horse');
  await page.getByRole('button', { name: '로그인' }).first().click();
}

const failures = [];
const check = (ok, message) => {
  console.log(`${ok ? '✓' : '✗'} ${message}`);
  if (!ok) failures.push(message);
};
const visible = (locator) => locator.waitFor({ timeout: 8000 }).then(() => true, () => false);

const browser = await chromium.launch();
if (SHOTS) mkdirSync(SHOTS, { recursive: true });
try {
  // A signed-in user who is not an admin.
  {
    const page = await browser.newPage();
    const state = makeState(false);
    await mock(page, state);
    await signIn(page);
    check(await visible(page.getByText('관리자만 볼 수 있는 페이지예요.')), 'non-admins are refused');
    check(!state.calls.some(([fn]) => fn.startsWith('admin_')), 'no statistics are requested for non-admins');
  }

  // An admin.
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  page.on('pageerror', (e) => failures.push(`page error: ${e.message}`));
  const state = makeState(true);
  await mock(page, state);
  await signIn(page);
  check(await visible(page.getByText('오늘 (2026-11-18, 한국 시간)')), 'admin sees today\'s numbers');
  const tile = page.locator('.kpis div', { hasText: '새 갤러리' });
  check((await tile.locator('.kpi-today').innerText()) === '3' && (await tile.innerText()).includes('전체 310'), 'new galleries today and total');
  check((await page.locator('.kpis div', { hasText: '방문' }).locator('.kpi-today').innerText()) === '688', 'visits today');
  check((await page.locator('.kpis div', { hasText: '감상평' }).locator('.kpi-today').innerText()) === '12', 'comments today');
  check(await visible(page.getByRole('link', { name: '처리할 신고 1건' })), 'open reports are flagged');
  check((await page.locator('figure.chart').count()) === 3, 'three daily charts');
  check((await page.locator('figure.chart').first().locator('path.chart-bar').count()) === 30, '30 days of visits');

  await page.locator('figure.chart').first().locator('rect[fill=transparent]').last().hover();
  check(await visible(page.locator('.chart-tip')), 'hovering a day shows its value');
  const tip = await page.locator('.chart-tip').innerText();
  const lastViews = days.at(-1).views;
  check(/11월 18일/.test(tip) && tip.includes(lastViews), `tooltip names the day and value (${tip.replace(/\s+/g, ' ')}; expected ${lastViews})`);
  if (SHOTS) await page.screenshot({ path: `${SHOTS}/admin-desktop.png`, fullPage: true });

  await page.locator('figure.chart').first().getByText('표로 보기').click();
  check(await visible(page.locator('figure.chart').first().locator('table')), 'chart has a table view');

  // Users: the tile opens the list.
  await page.locator('.kpis').getByRole('link', { name: /가입자/ }).click();
  await page.waitForTimeout(800);
  check(page.url().endsWith('#users'), 'clicking the sign-ups tile goes to the user list');
  const usersTop = await page.locator('#users').evaluate((el) => el.getBoundingClientRect().top);
  check(usersTop >= 0 && usersTop < 200, `the user list scrolls into view (top ${Math.round(usersTop)}px)`);
  const users = page.locator('#users');
  check((await users.locator('tbody tr').count()) === 4, 'every user is listed');
  const jisu = users.locator('tr', { hasText: 'jisu@example.com' });
  check((await jisu.innerText()).includes('@jisu') && (await jisu.innerText()).includes('Plus') && (await jisu.innerText()).includes('24'), 'a user shows gallery, plan and works');
  check((await users.locator('tr', { hasText: 'minho@example.com' }).innerText()).includes('미인증'), 'unconfirmed emails are marked');
  check((await users.locator('tr', { hasText: 'befree@example.com' }).innerText()).includes('관리자'), 'admins are marked');
  await users.getByRole('searchbox').fill('민호');
  await page.waitForTimeout(600);
  check((await users.locator('tbody tr').count()) === 1 && state.calls.some(([fn, a]) => fn === 'admin_users' && a.p_search === '민호'), 'search asks the server and narrows the list');
  check((await users.getByRole('status').innerText()) === '1명', 'the count follows the search');
  await users.getByRole('searchbox').fill('');
  await page.waitForTimeout(400);
  check((await users.locator('tbody tr').count()) === 4, 'clearing the search shows everyone again');
  if (SHOTS) await page.screenshot({ path: `${SHOTS}/admin-users.png` });

  // Moderation.
  await page.locator('#reports').getByRole('button', { name: '숨기기' }).click();
  await page.getByText('처리할 신고가 없어요.').waitFor();
  check(state.calls.some(([fn, a]) => fn === 'admin_set_comment_status' && a.p_comment_id === 'c2' && a.p_status === 'hidden'), 'hiding from a report hides the comment');
  check(state.calls.some(([fn, a]) => fn === 'admin_resolve_report' && a.p_report_id === 'r1' && a.p_status === 'actioned'), '…and resolves the report');

  await page.locator('#comments tr', { hasText: '분홍빛이' }).getByRole('button', { name: '숨기기' }).click();
  await page.locator('#comments tr', { hasText: '분홍빛이' }).getByRole('button', { name: '공개하기' }).waitFor();
  check(true, 'admins hide and can restore comments');

  await page.locator('tr', { hasText: '지수의 작은 정원' }).getByRole('button', { name: '비공개로' }).click();
  await page.locator('tr', { hasText: '지수의 작은 정원' }).getByRole('button', { name: '공개로' }).waitFor();
  check(state.calls.some(([fn, a]) => fn === 'admin_set_gallery_visibility' && a.p_gallery_id === 'g1' && a.p_visibility === 'private'), 'admins can take a gallery down');

  // Deleting a gallery: the dialog only lets the exact address through.
  const callsBefore = state.calls.length;
  await page.getByRole('button', { name: '삭제 @jisu' }).click();
  const dialog = page.getByRole('dialog', { name: '갤러리 @jisu 삭제' });
  check(await dialog.isVisible(), 'deleting a gallery asks for confirmation');
  const confirmButton = dialog.getByRole('button', { name: '영구 삭제' });
  check(await confirmButton.isDisabled(), 'delete is blocked until the address is typed');
  await dialog.getByLabel('확인을 위해 jisu 를 입력하세요').fill('jis');
  check(await confirmButton.isDisabled(), 'a near miss is not enough');
  await dialog.getByRole('button', { name: '취소' }).click();
  check(!(await dialog.isVisible()) && !state.calls.slice(callsBefore).some(([fn]) => fn === 'admin_delete_gallery'), 'cancel deletes nothing');

  await page.getByRole('button', { name: '삭제 @jisu' }).click();
  await dialog.getByLabel('확인을 위해 jisu 를 입력하세요').fill('jisu');
  if (SHOTS) await page.screenshot({ path: `${SHOTS}/admin-delete-dialog.png` });
  await confirmButton.click();
  await page.getByText('삭제했어요').waitFor();
  check(state.calls.some(([fn, a]) => fn === 'admin_delete_gallery' && a.p_gallery_id === 'g1'), 'the gallery is deleted');
  check(['artworks/u2/a1/display.jpg', 'artworks/u2/a1/thumb.jpg', 'originals/u2/a1/original'].every((f) => state.removed.includes(f)), 'its image files are removed from storage');
  check(await page.locator('#galleries tr', { hasText: '지수의 작은 정원' }).waitFor({ state: 'detached', timeout: 5000 }).then(() => true, () => false), 'it leaves the gallery list');
  check(await page.locator('#log tr', { hasText: '갤러리 삭제' }).isVisible(), 'the admin log records it');

  // Deleting a user.
  const usersSection = page.locator('#users');
  check((await usersSection.locator('tr', { hasText: 'befree@example.com' }).innerText()).includes('나'), 'your own account is marked and cannot be deleted');
  check((await usersSection.getByRole('button', { name: '삭제 other-admin@example.com' }).count()) === 0, 'other admins cannot be deleted');
  await usersSection.getByRole('button', { name: '삭제 minho@example.com' }).click();
  const userDialog = page.getByRole('dialog', { name: '가입자 minho@example.com 삭제' });
  await userDialog.getByLabel('확인을 위해 minho@example.com 를 입력하세요').fill('minho@example.com');
  await userDialog.getByRole('button', { name: '영구 삭제' }).click();
  await usersSection.locator('tr', { hasText: 'minho@example.com' }).waitFor({ state: 'detached' });
  check(state.calls.some(([fn, a]) => fn === 'admin_delete_user' && a.p_user_id === 'u3'), 'the user is deleted');
  check(await page.locator('#log tr', { hasText: 'minho@example.com' }).isVisible(), 'the admin log names the deleted user');
  if (SHOTS) await page.locator('#log').screenshot({ path: `${SHOTS}/admin-log.png` });

  // Phone width.
  await page.setViewportSize({ width: 390, height: 844 });
  await page.reload();
  await page.getByText('오늘 (2026-11-18, 한국 시간)').waitFor();
  const tooWide = await page.evaluate(() =>
    [...document.querySelectorAll('body *')]
      .filter((el) => el.getBoundingClientRect().right > innerWidth + 1 && !el.closest('.table-wrap'))
      .slice(0, 5)
      .map((el) => `${el.tagName.toLowerCase()}.${el.className} (${Math.round(el.getBoundingClientRect().right)}px)`),
  );
  const pageScrolls = await page.evaluate(() => document.documentElement.scrollWidth > innerWidth);
  check(tooWide.length === 0 && !pageScrolls, `no sideways page scroll on a phone (tables scroll inside their box) ${tooWide.join(', ')}`);
  if (SHOTS) await page.screenshot({ path: `${SHOTS}/admin-phone.png`, fullPage: true });
} finally {
  await browser.close();
}

if (failures.length) {
  console.error(`\n${failures.length} check(s) failed:\n- ${failures.join('\n- ')}`);
  process.exit(1);
}
console.log('\nAll admin checks passed.');
