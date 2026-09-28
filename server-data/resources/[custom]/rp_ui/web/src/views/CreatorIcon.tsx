import type { ReactNode } from "react";

const shapes = {
  body: (
    <>
      <circle cx="12" cy="4" r="2" />
      <path d="M9 8h6l3 7m-9-7-3 7m4-3v9m4-9v9M9 8v6h6V8" />
    </>
  ),
  face: (
    <>
      <path d="M6 8a6 6 0 0 1 12 0v5c0 4-4 8-6 8s-6-4-6-8V8Z" />
      <path d="M8 10h1m6 0h1m-4 1-1 4h2m-3 3h4" />
    </>
  ),
  upper: <path d="m8 3-6 4 3 5 3-2v11h8V10l3 2 3-5-6-4c-1 4-7 4-8 0Z" />,
  lower: <path d="M6 3h12l1 18h-6l-1-11-1 11H5L6 3Zm0 4h12" />,
  shoes: (
    <>
      <path d="m5 5 5 1 2 6 8 3c2 1 2 5-1 5H3V9l2-4Z" />
      <path d="M3 16h7l3 2h8m-11-8 3-1m-2 4 3-1" />
    </>
  ),
  identity: (
    <>
      <rect x="3" y="4" width="18" height="16" rx="1" />
      <circle cx="9" cy="10" r="2" />
      <path d="M5 16c0-4 8-4 8 0m2-7h3m-3 4h3m-3 4h3" />
    </>
  ),
  heritage: (
    <>
      <circle cx="6" cy="6" r="3" />
      <circle cx="18" cy="6" r="3" />
      <circle cx="12" cy="19" r="3" />
      <path d="M6 9v3h12V9m-6 3v4" />
    </>
  ),
  hair: (
    <>
      <path d="M5 20V9a7 7 0 0 1 14 0v11m-14-7c8 0 8-9 8-9 0 6 3 8 6 9M8 15v2a4 4 0 0 0 8 0v-2" />
    </>
  ),
  details: (
    <>
      <path d="m12 2 2.5 6.5L21 11l-6.5 2.5L12 20l-2.5-6.5L3 11l6.5-2.5L12 2Zm8 14v6m-3-3h6" />
    </>
  ),
  accessories: (
    <>
      <path d="M3 12h6l1 6H4l-1-6Zm12 0h6l-1 6h-6l1-6Zm-5 2h4M3 12l2-6m16 6-2-6" />
    </>
  ),
  reset: (
    <>
      <path d="M3 10a9 9 0 1 1 2 9M3 3v7h7" />
      <path d="M12 7v5l3 2" />
    </>
  ),
  plus: <path d="M12 5v14M5 12h14" />,
  minus: <path d="M5 12h14" />,
  eye: (
    <>
      <path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12Z" />
      <circle cx="12" cy="12" r="3" />
    </>
  ),
  mouse: (
    <>
      <rect x="6" y="2" width="12" height="20" rx="6" />
      <path d="M12 3v7M6 10h12" />
    </>
  ),
  search: (
    <>
      <circle cx="10" cy="10" r="6" />
      <path d="m15 15 6 6" />
    </>
  ),
  arrow: <path d="M4 12h16m-6-6 6 6-6 6" />,
  back: <path d="M20 12H4m6-6-6 6 6 6" />,
  male: (
    <>
      <circle cx="9" cy="15" r="6" />
      <path d="m13 11 8-8m-7 0h7v7" />
    </>
  ),
  female: (
    <>
      <circle cx="12" cy="8" r="6" />
      <path d="M12 14v9m-4-4h8" />
    </>
  ),
} satisfies Record<string, ReactNode>;

export type CreatorIconName = keyof typeof shapes;
export function CreatorIcon({ name }: { name: CreatorIconName }) {
  return (
    <svg
      className="creator-icon"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.7"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      {shapes[name]}
    </svg>
  );
}
