import { DISPLAY_LONG_EDGE, fitSize, formatExif, MAX_UPLOAD_BYTES, THUMB_LONG_EDGE, type RawExif } from './image-utils';

export class ImageError extends Error {
  constructor(public code: 'file_too_large' | 'unsupported_image') {
    super(code);
  }
}

export interface ProcessedImage {
  display: Blob;
  thumbnail: Blob;
  width: number;
  height: number;
  exif: Record<string, string>;
}

/**
 * Makes the display image (2048px) and thumbnail (480px) in the browser.
 * Re-drawing through a canvas writes plain JPEGs with no EXIF, so GPS and
 * every other tag stay on the artist's computer. The camera's rotation is
 * applied first (imageOrientation: 'from-image').
 */
export async function processImage(file: File, watermark?: string): Promise<ProcessedImage> {
  if (file.size > MAX_UPLOAD_BYTES) throw new ImageError('file_too_large');

  let bitmap: ImageBitmap;
  try {
    bitmap = await createImageBitmap(file, { imageOrientation: 'from-image' });
  } catch {
    throw new ImageError('unsupported_image');
  }

  try {
    const exif = formatExif(await readExif(file));
    const display = await draw(bitmap, DISPLAY_LONG_EDGE, 0.88, watermark);
    const thumbnail = await draw(bitmap, THUMB_LONG_EDGE, 0.8);
    return { display: display.blob, thumbnail: thumbnail.blob, width: display.width, height: display.height, exif };
  } finally {
    bitmap.close();
  }
}

async function readExif(file: File): Promise<RawExif | null> {
  try {
    const exifr = (await import('exifr')).default;
    return (await exifr.parse(file, {
      pick: ['Make', 'Model', 'LensModel', 'ISO', 'ExposureTime', 'FNumber', 'FocalLength'],
      gps: false,
    })) as RawExif | null;
  } catch {
    return null;
  }
}

async function draw(bitmap: ImageBitmap, longEdge: number, quality: number, watermark?: string) {
  const { width, height } = fitSize(bitmap.width, bitmap.height, longEdge);
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext('2d');
  if (!ctx) throw new ImageError('unsupported_image');
  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = 'high';
  ctx.drawImage(bitmap, 0, 0, width, height);

  if (watermark) {
    const size = Math.max(14, Math.round(width / 60));
    ctx.font = `500 ${size}px system-ui, sans-serif`;
    ctx.textAlign = 'right';
    ctx.textBaseline = 'bottom';
    ctx.fillStyle = 'rgba(0, 0, 0, 0.35)';
    ctx.fillText(`© ${watermark}`, width - 23, height - 19);
    ctx.fillStyle = 'rgba(255, 255, 255, 0.7)';
    ctx.fillText(`© ${watermark}`, width - 24, height - 20);
  }

  const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, 'image/jpeg', quality));
  if (!blob) throw new ImageError('unsupported_image');
  return { blob, width, height };
}
