import { useState, type ReactNode } from 'react';
import artwork from '../data/item-artwork.json';

type Art = { src: string; width: number; height: number; bounds: number[] };
const catalog: Readonly<Record<string, Art>> = artwork;
export const isArtwork = (value: unknown): boolean => value === undefined ||
  (typeof value === 'string' && value.length <= 160 && /^(weapons\/WEAPON_[A-Z0-9_]+|clothing\/[01]\/[a-z]+\/\d+_\d+)$/.test(value));

// The SVG viewport fits the original transparent image bounds without changing
// the downloaded bitmap. Only locally bundled, catalogued paths are permitted.
export function CatalogImage({ id, label = '', fallback, className = '' }: {
  id?: string; label?: string; fallback: ReactNode; className?: string;
}) {
  const [failed, setFailed] = useState<string>();
  const art = id && Object.hasOwn(catalog, id) ? catalog[id] : undefined;
  if (!art || failed === id) return <>{fallback}</>;
  const [x, y, w, h] = art.bounds;
  const padding = Math.max(w, h) * 0.06;
  return <svg className={`catalog-image ${className}`} viewBox={`${x-padding} ${y-padding} ${w+padding*2} ${h+padding*2}`}
    role="img" aria-label={label || undefined} aria-hidden={label ? undefined : true} focusable="false">
    <image href={art.src} width={art.width} height={art.height}
      onError={() => setFailed(id)} />
  </svg>;
}
