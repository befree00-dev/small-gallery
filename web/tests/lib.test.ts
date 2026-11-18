import { describe, expect, it } from 'vitest';

import { average, groupByRoom } from '../lib/data';
import { detectLocale, messages, parseHandle, pick } from '../lib/i18n';
import { localeRedirect } from '../lib/locale-routing';
import type { Artwork, Room } from '../lib/types';

describe('detectLocale', () => {
  it('defaults to Korean', () => {
    expect(detectLocale(null)).toBe('ko');
    expect(detectLocale('fr-FR,fr;q=0.9')).toBe('ko');
  });

  it('honours the browser preference order and weights', () => {
    expect(detectLocale('en-US,en;q=0.9,ko;q=0.8')).toBe('en');
    expect(detectLocale('ko-KR,ko;q=0.9,en-US;q=0.8')).toBe('ko');
    expect(detectLocale('fr;q=0.9,en;q=0.5,ko;q=0.7')).toBe('ko');
    expect(detectLocale('ja,en-GB;q=0.8')).toBe('en');
  });
});

describe('parseHandle', () => {
  it('accepts the shared address forms', () => {
    expect(parseHandle('@jisu')).toBe('jisu');
    expect(parseHandle('%40Jisu')).toBe('jisu');
    expect(parseHandle('jisu_2025')).toBe('jisu_2025');
  });

  it('rejects anything that cannot be a gallery address', () => {
    expect(parseHandle('@ab')).toBeNull();
    expect(parseHandle('@ji-su')).toBeNull();
    expect(parseHandle('%E0%A4%A')).toBeNull();
  });
});

describe('localeRedirect', () => {
  it('sends shared links to the visitor language', () => {
    expect(localeRedirect('/@jisu', 'en-US,en;q=0.9', undefined)).toBe('/en/@jisu');
    expect(localeRedirect('/@jisu', 'ko-KR', undefined)).toBe('/ko/@jisu');
    expect(localeRedirect('/', null, undefined)).toBe('/ko');
  });

  it('prefers the language the visitor chose before', () => {
    expect(localeRedirect('/@jisu', 'en-US', 'ko')).toBe('/ko/@jisu');
  });

  it('leaves localized paths alone', () => {
    expect(localeRedirect('/en/@jisu/a/123', 'ko', undefined)).toBeNull();
  });
});

describe('pick', () => {
  it('uses English only when the artist wrote it', () => {
    expect(pick('봄', 'Spring', 'en')).toBe('Spring');
    expect(pick('봄', ' ', 'en')).toBe('봄');
    expect(pick('봄', 'Spring', 'ko')).toBe('봄');
  });
});

describe('messages', () => {
  it('has every Korean string in English too', () => {
    const ko = messages('ko');
    const en = messages('en');
    expect(Object.keys(en).sort()).toEqual(Object.keys(ko).sort());
    expect(en.works(1)).toBe('1 work');
    expect(ko.works(3)).toBe('작품 3');
  });
});

describe('groupByRoom', () => {
  const room = (id: string, sort_order: number): Room => ({ id, title: id, title_en: null, statement: '', statement_en: null, sort_order });
  const work = (id: string, room_id: string, sort_order = 0) => ({ id, room_id, sort_order }) as Artwork;

  it('orders works by their hanging order even if they arrive unsorted', () => {
    const groups = groupByRoom([room('b', 1), room('a', 0)], [work('x2', 'a', 2), work('y', 'b', 0), work('x1', 'a', 1)]);
    expect(groups.flatMap((g) => g.artworks.map((w) => w.id))).toEqual(['x1', 'x2', 'y']);
  });

  it('keeps room order and drops empty rooms', () => {
    const groups = groupByRoom([room('spring', 0), room('empty', 1), room('still', 2)], [work('a', 'still'), work('b', 'spring', 0), work('c', 'spring', 1)]);
    expect(groups.map((g) => [g.room.id, g.artworks.map((a) => a.id)])).toEqual([
      ['spring', ['b', 'c']],
      ['still', ['a']],
    ]);
  });
});

describe('average', () => {
  it('reads Postgres numerics sent as strings', () => {
    expect(average('3.40')).toBe(3.4);
    expect(average(4)).toBe(4);
    expect(average(null)).toBe(0);
  });
});

describe('API embeds', () => {
  it('name the foreign key for every profiles embed', async () => {
    const { readFileSync } = await import('node:fs');
    const source = readFileSync(new URL('../lib/data.ts', import.meta.url), 'utf8');
    expect(source).not.toMatch(/profiles\(/);
  });
});

describe('originFrom', () => {
  it('uses the address the visitor requested', async () => {
    const { originFrom } = await import('../lib/site');
    expect(originFrom('small-gallery-vert.vercel.app', 'https', 'https://fallback.example')).toBe('https://small-gallery-vert.vercel.app');
    expect(originFrom('a.example, proxy.internal', 'https, http', 'https://fallback.example')).toBe('https://a.example');
    expect(originFrom('localhost:3000', null, 'https://fallback.example')).toBe('http://localhost:3000');
    expect(originFrom(null, null, 'https://fallback.example')).toBe('https://fallback.example');
  });
});

describe('neighbors', () => {
  it('finds the works on either side', async () => {
    const { neighbors } = await import('../lib/data');
    const list = [{ id: 'a' }, { id: 'b' }, { id: 'c' }];
    expect(neighbors(list, 'b')).toEqual({ index: 1, prev: { id: 'a' }, next: { id: 'c' } });
    expect(neighbors(list, 'a')).toEqual({ index: 0, prev: null, next: { id: 'b' } });
    expect(neighbors(list, 'c')).toEqual({ index: 2, prev: { id: 'b' }, next: null });
    expect(neighbors(list, 'x')).toEqual({ index: -1, prev: null, next: null });
  });
});

describe('niceMax', () => {
  it('rounds the axis up to an even step', async () => {
    const { niceMax } = await import('../components/admin/daily-bars');
    expect(niceMax(123)).toEqual({ top: 150, step: 50 });
    expect(niceMax(2)).toEqual({ top: 2, step: 1 });
    expect(niceMax(0)).toEqual({ top: 4, step: 2 });
  });
});
