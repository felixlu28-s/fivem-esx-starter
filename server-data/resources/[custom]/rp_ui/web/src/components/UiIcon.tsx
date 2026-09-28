import type { ReactNode } from "react";

const icons = {
  heart: (<path d="M20.8 4.6a5.6 5.6 0 0 0-8 .2L12 6l-.8-1.2a5.6 5.6 0 0 0-8-.2C.7 7.2 1.8 11 4 13.3L12 21l8-7.7c2.2-2.3 3.3-6.1.8-8.7Z" />),
  comment: (<path d="M21 11.5a9.5 9.5 0 0 1-14 8.3L2 22l1.9-5A9.5 9.5 0 1 1 21 11.5Z" />),
  home: (<><path d="m2 11 10-9 10 9M4 9v13h6v-8h4v8h6V9" /></>),
  grid: (<><path d="M3 3h18v18H3ZM3 9h18M3 15h18M9 3v18M15 3v18"/></>),
  camera: (<><path d="M3 7h4l2-3h6l2 3h4v14H3Z" /><circle cx="12" cy="13" r="4" /></>),
  trash: (<><path d="M3 6h18M9 6V3h6v3M5 6l1 15h12l1-15M10 10v7M14 10v7" /></>),
  gallery: (<><rect x="3" y="3" width="18" height="18" rx="2" /><circle cx="8" cy="8" r="2" /><path d="m3 18 6-6 4 4 3-5 5 6" /></>),
  play: (<path d="m8 4 12 8-12 8Z" />),
  pause: (<><path d="M8 4v16M16 4v16" strokeWidth="4" /></>),
  video: (<><rect x="2" y="5" width="13" height="14" rx="2" /><path d="m15 9 7-4v14l-7-4" /></>),
  dialpad: (<>{[4,12,20].flatMap((x) => [4,12,20].map((y) => <circle key={`${x}-${y}`} cx={x} cy={y} r="1.4" fill="currentColor" />))}</>),
  erase: (<><path d="M9 5h13v14H9l-7-7Z" /><path d="m12 9 6 6m0-6-6 6" /></>),
  compose: (<><path d="M12 4H4v17h17v-8M10 15l1-5L20 1l3 3-9 9Z" /></>),
  call: (<path d="M7 3 3 5c-1 6 10 17 16 16l2-4-5-3-2 2c-3-1-5-3-6-6l2-2z" />),
  phone: (<><rect x="6" y="2" width="12" height="20" rx="2" /><path d="M10 5h4M11 19h2" /></>),
  box: (<><path d="m3 7 9-4 9 4v10l-9 4-9-4zM3 7l9 4 9-4M12 11v10M7.5 5l9 4v4" /></>),
  microphone: (<><rect x="9" y="2" width="6" height="12" rx="3" /><path d="M5 10v1a7 7 0 0 0 14 0v-1M12 18v4M8 22h8" /></>),
  micOff: (<><path d="M9 5V4a3 3 0 0 1 6 0v7M9 9v2a3 3 0 0 0 4 3M5 10v1a7 7 0 0 0 12 5M19 10v1M12 18v4M8 22h8M2 2l20 20" /></>),
  search: (
    <>
      <circle cx="10" cy="10" r="6" />
      <path d="m15 15 6 6" />
    </>
  ),
  shop: (
    <>
      <path d="M3 9h18l-2-6H5zM4 9v12h16V9M8 21v-7h5v7M3 9a3 3 0 0 0 6 0 3 3 0 0 0 6 0 3 3 0 0 0 6 0" />
    </>
  ),
  craft: (
    <>
      <path d="m14 3 7 7-4 4-3-3-9 10-3-3 10-9-2-2zM16 15l5 5-2 2-5-5" />
    </>
  ),
  person: (
    <>
      <circle cx="12" cy="7" r="3.5" />
      <path d="M5 21v-3a7 7 0 0 1 14 0v3M9 14l3 3 3-3" />
    </>
  ),
  keyboard: (
    <>
      <rect x="2" y="5" width="20" height="14" rx="1" />
      <path d="M5 9h1m3 0h1m3 0h1m3 0h2M5 12h1m3 0h1m3 0h1m3 0h2M6 16h12" />
    </>
  ),
  settings: (
    <>
      <path d="M4 7h16M4 17h16" />
      <rect x="8" y="4" width="4" height="6" rx="1" />
      <rect x="14" y="14" width="4" height="6" rx="1" />
    </>
  ),
  bag: (
    <>
      <path d="M8 6V4a4 4 0 0 1 8 0v2M5 21V9a7 7 0 0 1 14 0v12z" />
      <rect x="8" y="12" width="8" height="6" rx="1" />
      <path d="M8 15h8M9 8h6" />
    </>
  ),
  organization: (
    <>
      <path d="M4 22V4h10v18M14 9h6v13M2 22h20M7 7h4M7 11h4M7 15h4M8 22v-3h3v3M17 12v1m0 3v1" />
    </>
  ),
  team: (
    <>
      <circle cx="9" cy="7" r="3" />
      <path d="M3 21v-3a6 6 0 0 1 12 0v3M16 4a3 3 0 0 1 0 6m2 4a5 5 0 0 1 3 4v3" />
    </>
  ),
  rank: (
    <>
      <path d="m4 7 8-4 8 4-8 4zM4 12l8 4 8-4M4 17l8 4 8-4" />
    </>
  ),
  wallet: (
    <>
      <path d="M20 7V4H5a3 3 0 0 0 0 6h16v11H5a3 3 0 0 1-3-3V7" />
      <path d="M21 13h-7v5h7M17 15.5h.01" />
    </>
  ),
  bank: (
    <>
      <path d="m2 7 10-5 10 5H2zM3 22h18M5 10v9m7-9v9m7-9v9M2 19h20" />
    </>
  ),
  fitness: (
    <>
      <circle cx="15" cy="4" r="2" />
      <path d="m6 11 5-4 5 3 4 1M12 8l-3 7 5 2 1 5M9 15l-3 6H2" />
    </>
  ),
  clock: (
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="M12 6v6l4 2" />
    </>
  ),
  calendar: (
    <>
      <rect x="3" y="5" width="18" height="16" rx="1" />
      <path d="M7 2v6m10-6v6M3 10h18M7 14h3m4 0h3M7 17h3" />
    </>
  ),
  ruler: (
    <>
      <path d="M8 2h8v20H8zM8 6h4m-4 4h3m-3 4h4m-4 4h3" />
    </>
  ),
  arrow: (
    <>
      <path d="M5 19 19 5M6 5h13v13" />
    </>
  ),
  back: (
    <>
      <path d="m10 5-7 7 7 7M3 12h18" />
    </>
  ),
  close: (
    <>
      <path d="m5 5 14 14M5 19 19 5" />
    </>
  ),
  refresh: (
    <>
      <path d="M20 10a8 8 0 1 0-1 7M20 3v7h-7" />
    </>
  ),
  check: (
    <>
      <path d="m4 12 5 5L20 6" />
    </>
  ),
  plus: (
    <>
      <path d="M12 4v16M4 12h16" />
    </>
  ),
  warning: (
    <>
      <path d="m12 3 10 18H2zM12 9v5m0 3v.1" />
    </>
  ),
  plane: (
    <>
      <path d="m3 12 7-2 1-7h2l1 7 7 2v2l-7-1v6l3 2H7l3-2v-6l-7 1z" />
    </>
  ),
  message: (
    <>
      <path d="M3 3h18v14H9l-6 4zM7 8h10M7 12h7" />
    </>
  ),
  eye: (
    <>
      <path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z" />
      <circle cx="12" cy="12" r="3" />
    </>
  ),
} satisfies Record<string, ReactNode>;
export type UiIconName = keyof typeof icons;
export function UiIcon({
  name,
  className = "",
}: {
  name: UiIconName;
  className?: string;
}) {
  return (
    <svg
      className={`ui-icon ${className}`}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      {icons[name]}
    </svg>
  );
}
