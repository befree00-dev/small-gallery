import { describe, expect, it } from 'vitest';

import { effectiveVisibility, fitSize, formatExif, isValidHandle, moveItem, normalizeHandle, titleFromFileName } from '../lib/studio/image-utils';
import { studioMessages } from '../lib/studio/messages';

describe('fitSize', () => {
  it('shrinks the long edge and keeps the proportions', () => {
    expect(fitSize(3000, 2000, 2048)).toEqual({ width: 2048, height: 1365 });
    expect(fitSize(2000, 3000, 480)).toEqual({ width: 320, height: 480 });
  });

  it('never enlarges small images', () => {
    expect(fitSize(800, 600, 2048)).toEqual({ width: 800, height: 600 });
  });
});

describe('titleFromFileName', () => {
  it('keeps meaningful names and drops camera names', () => {
    expect(titleFromFileName('봄 개천.jpg')).toBe('봄 개천');
    expect(titleFromFileName('IMG_2041.HEIC')).toBe('');
    expect(titleFromFileName('DSC01234.jpg')).toBe('');
    expect(titleFromFileName('PXL_20250412.jpg')).toBe('');
  });
});

describe('formatExif', () => {
  it('formats like the app and never includes location', () => {
    expect(formatExif({ Make: 'FUJIFILM', Model: 'X-T30', ISO: 400, ExposureTime: 0.004, FNumber: 2.8, FocalLength: 35.2, LensModel: ' XF35mm ' })).toEqual({
      camera: 'FUJIFILM X-T30',
      lens: 'XF35mm',
      iso: '400',
      shutter: '1/250s',
      aperture: 'f/2.8',
      focal: '35mm',
    });
    expect(formatExif({ Make: 'Apple', Model: 'Apple iPhone 15' }).camera).toBe('Apple iPhone 15');
    expect(formatExif({ ExposureTime: 2 }).shutter).toBe('2s');
    expect(formatExif(null)).toEqual({});
  });
});

describe('moveItem', () => {
  it('moves one item and leaves the rest in order', () => {
    expect(moveItem(['a', 'b', 'c', 'd'], 0, 2)).toEqual(['b', 'c', 'a', 'd']);
    expect(moveItem(['a', 'b', 'c'], 2, 0)).toEqual(['c', 'a', 'b']);
  });

  it('ignores moves out of range', () => {
    const list = ['a', 'b'];
    expect(moveItem(list, 0, 5)).toBe(list);
  });
});

describe('handles', () => {
  it('normalizes and validates like the database', () => {
    expect(normalizeHandle(' @Minho_Photo ')).toBe('minho_photo');
    expect(normalizeHandle('small-gallery-vert.vercel.app/@jisu')).toBe('jisu');
    expect(isValidHandle('minho_photo')).toBe(true);
    expect(isValidHandle('ab')).toBe(false);
    expect(isValidHandle('ji-su')).toBe(false);
  });
});

describe('studio messages', () => {
  it('has every Korean string in English too', () => {
    const ko = studioMessages('ko');
    const en = studioMessages('en');
    expect(Object.keys(en).sort()).toEqual(Object.keys(ko).sort());
    expect(Object.keys(en.visibilities)).toEqual(Object.keys(ko.visibilities));
    expect(en.media).toHaveLength(ko.media.length);
  });
});

describe('effectiveVisibility', () => {
  it('applies the narrowest setting', () => {
    expect(effectiveVisibility('unlisted', 'public')).toBe('unlisted');
    expect(effectiveVisibility('public', 'public', 'private')).toBe('private');
    expect(effectiveVisibility('public', 'public')).toBe('public');
    expect(effectiveVisibility('private', 'unlisted', 'public')).toBe('private');
  });
});
