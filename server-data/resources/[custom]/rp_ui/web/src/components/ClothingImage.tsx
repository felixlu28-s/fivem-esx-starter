import { useId, type ReactNode } from 'react';
import { CatalogImage } from './CatalogImage';

// Category illustrations remain the explicit fallback when GTA has no visible garment.
export function ClothingImage({ category, color = '#8b9c91', label, artwork }: { category: string; color?: string; label: string; artwork?: string }) {
  const id = useId();
  const shapes: Record<string, ReactNode> = {
    jacket: <><path d="m43 19-18 7-15 65 15 5 12-40-3 47h52l-3-47 12 40 15-5-15-65-18-7-17 8Z"/><path d="M60 27v75M43 19l-5 17 16 6M77 19l5 17-16 6M38 75h14M68 75h14M11 83l15 5M94 88l15-5" fill="none"/></>,
    blazer: <><path d="m44 19-20 9-13 66 16 3 10-45-4 49h54l-4-49 10 45 16-3-13-66-20-9-16 8Z"/><path d="m44 19 16 58 16-58-16 8ZM43 38l-8 10 25 29 25-29-8-10M60 77v24M38 75h13M70 75h13" fill="none"/><circle cx="63" cy="83" r="1.5"/></>,
    shirt: <><path d="m44 19-20 9-13 66 16 3 10-45-4 49q27 10 54 0l-4-49 10 45 16-3-13-66-20-9-16 8Z"/><path d="m44 19 4 21 12-13 12 13 4-21M60 27v75M71 49h10v13H71ZM11 84l17 4M92 88l17-4" fill="none"/>{[47,61,75,89].map(y=><circle key={y} cx="62" cy={y} r="1.3" fill="#e5e5da"/>)}</>,
    sweater: <><path d="m43 19-18 7-15 65 15 5 12-40-3 47h52l-3-47 12 40 15-5-15-65-18-7c-8 14-26 14-34 0Z"/><path d="M43 19c2 23 32 23 34 0M35 93h51M35 97h51M12 84l14 4M94 88l14-4" fill="none"/></>,
    top: <><path d="M35 23 22 28 7 49l19 12 9-13-3 54h56l-3-54 9 13 19-12-15-21-13-5c-8 12-42 12-50 0Z"/><path d="M45 26q15 15 30 0M34 89h54M26 50l8-12M86 38l8 12" fill="none"/></>,
    undershirt: <><path d="m37 20 12 5q11 17 22 0l12-5 5 78H32Z"/><path d="M49 25q11 33 22 0M35 87h50" fill="none"/></>,
    pants: <><path d="M34 15h52l5 91H66l-6-58-6 58H29Z"/><path d="M35 24h50M60 24v24M37 26l-2 12 13-4M83 26l2 12-13-4M31 96h23M66 96h24" fill="none"/></>,
    shoes: <><path d="m18 45 24 5 9 19 45 12q10 5 10 15H11l-1-18Z"/><path d="m41 58 19 9M48 67l20 7M56 75l19 5M12 87h91M20 52l-4 30" fill="none"/><path d="m57 24 16 2 7 16 29 10v13H74l-6-11-13-4Z" opacity=".65"/></>,
    hat: <><path d="M27 64V46a32 29 0 0 1 64 0v26Z"/><path d="M27 64q-30 4-18 18c22 20 74 14 94-2L91 67Z"/><path d="M58 18v42M30 44q28-10 59 2" fill="none"/></>,
    glasses: <><path d="m10 54 7-20h84l9 20M49 59q11-9 22 0" fill="none"/><path d="M9 54h40v18q-20 21-36 0ZM71 54h40l-4 18q-16 21-36 0Z"/><path d="M17 60h23M79 60h23" fill="none" strokeOpacity=".6"/></>,
    ears: <><circle cx="34" cy="36" r="5"/><circle cx="86" cy="36" r="5"/><path d="M34 41c-43 65 44 65 0 0ZM86 41c-43 65 44 65 0 0Z" fill="none" strokeWidth="6"/></>,
    chain: <><path d="M28 20c-9 53 14 64 32 70 18-6 41-17 32-70M34 22c-7 48 10 57 26 62 16-5 33-14 26-62" fill="none"/><path d="m60 85 9 11-9 13-9-13Z"/></>,
    watch: <><path d="M46 9h28l5 31v40l-5 31H46l-5-31V40Z"/><circle cx="60" cy="60" r="28"/><circle cx="60" cy="60" r="21" fill="#29312d"/><path d="M60 43v17l12 6M86 55h7v10h-7M49 18h22M49 102h22" fill="none"/></>,
    bracelet: <><ellipse cx="60" cy="63" rx="34" ry="29" fill="none" strokeWidth="12"/><ellipse cx="60" cy="58" rx="34" ry="29" fill="none" strokeWidth="6"/><path d="M30 74h12M78 74h12"/></>,
    mask: <><path d="M29 39q31-18 62 0v40Q60 105 29 79Z"/><path d="M29 43C-1 30 1 91 29 78M91 43c30-13 28 48 0 35M39 52h42M39 63h42M39 74h42" fill="none"/></>,
    bag: <><path d="M35 37h50l10 67H25ZM45 37V24q15-19 30 0v13"/><path d="M26 61h68M36 69h48v23H36ZM50 39v24M70 39v24" fill="none"/></>,
  };
  const fallback = <svg className="clothing-image" viewBox="0 0 120 120" role="img" aria-label={label}>
    <defs><linearGradient id={id} x1="0" y1="0" x2="1" y2="1"><stop stopColor={color}/><stop offset="1" stopColor="#252d29"/></linearGradient></defs>
    <ellipse cx="60" cy="112" rx="35" ry="3" fill="black" opacity=".15"/>
    <g fill={`url(#${id})`} stroke="#d8dfd4" strokeOpacity=".75" strokeWidth="1.6" strokeLinejoin="round">{shapes[category] ?? shapes.top}</g>
  </svg>;
  return <CatalogImage id={artwork} label={label} className="clothing-image" fallback={fallback}/>;
}
