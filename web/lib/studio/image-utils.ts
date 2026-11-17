// Pure helpers for the upload pipeline (no DOM), shared by image.ts and tests.

export const MAX_UPLOAD_BYTES = 50 * 1024 * 1024;
export const DISPLAY_LONG_EDGE = 2048;
export const THUMB_LONG_EDGE = 480;

/** Scales (width, height) so the long edge is at most `longEdge`; never enlarges. */
export function fitSize(width: number, height: number, longEdge: number): { width: number; height: number } {
  const scale = Math.min(1, longEdge / Math.max(width, height));
  return { width: Math.max(1, Math.round(width * scale)), height: Math.max(1, Math.round(height * scale)) };
}

/** A file name as a starting title; camera names (IMG_1234, DSC01234, PXL_…) give none. */
export function titleFromFileName(name: string): string {
  const stem = name.includes('.') ? name.slice(0, name.lastIndexOf('.')) : name;
  return /^(img|dsc|pxl|dscf|p\d|photo|image)[_-]?\d/i.test(stem) ? '' : stem.trim();
}

export interface RawExif {
  Make?: string;
  Model?: string;
  LensModel?: string;
  ISO?: number;
  ExposureTime?: number;
  FNumber?: number;
  FocalLength?: number;
}

/** Shooting details worth showing visitors. Same keys and formats as the app. Never location. */
export function formatExif(raw: RawExif | null | undefined): Record<string, string> {
  const out: Record<string, string> = {};
  if (!raw) return out;
  const make = (raw.Make ?? '').trim();
  const model = (raw.Model ?? '').trim();
  const camera = model.toLowerCase().startsWith(make.toLowerCase()) ? model : `${make} ${model}`.trim();
  if (camera) out.camera = camera;
  if (raw.LensModel?.trim()) out.lens = raw.LensModel.trim();
  if (raw.ISO) out.iso = String(Math.round(raw.ISO));
  if (raw.ExposureTime && raw.ExposureTime > 0) {
    const s = raw.ExposureTime;
    out.shutter = s >= 1 ? `${Number.isInteger(s) ? s : s.toFixed(1)}s` : `1/${Math.round(1 / s)}s`;
  }
  if (raw.FNumber && raw.FNumber > 0) out.aperture = `f/${raw.FNumber.toFixed(1)}`;
  if (raw.FocalLength && raw.FocalLength > 0) out.focal = `${Math.round(raw.FocalLength)}mm`;
  return out;
}

/** Moves item `from` to index `to`, returning a new array. */
export function moveItem<T>(list: T[], from: number, to: number): T[] {
  if (from === to || from < 0 || to < 0 || from >= list.length || to >= list.length) return list;
  const next = [...list];
  const [item] = next.splice(from, 1);
  next.splice(to, 0, item);
  return next;
}

export function isValidHandle(handle: string): boolean {
  return /^[a-z0-9_]{3,30}$/.test(handle);
}

/** "@Jisu ", "site.app/@jisu" → "jisu". */
export function normalizeHandle(input: string): string {
  let s = input.trim().toLowerCase();
  s = s.slice(s.lastIndexOf('@') + 1);
  return s.slice(s.lastIndexOf('/') + 1);
}
