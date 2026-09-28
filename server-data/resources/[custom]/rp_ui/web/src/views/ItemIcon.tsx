import { CatalogImage } from '../components/CatalogImage';
export function ItemIcon({ name, artwork, label = "" }: { name: string; artwork?: string; label?: string }) {
  const paths: Record<string, React.ReactNode> = {
    fabric: (
      <>
        <path d="M9 10h29v29H9zM9 17h29M16 10v29M8 42h30M4 12v28M23 17v22M16 24h22M16 31h22" />
      </>
    ),
    thread: (
      <>
        <path d="M15 8h18M15 40h18M17 8v32M31 8v32M17 14l14 6-14 5 14 7M31 32c12 0 12-15 6-15M15 6v4M33 6v4M15 38v4M33 38v4" />
      </>
    ),
    water: (
      <>
        <path d="M19 5h10v5l3 5v23a3 3 0 0 1-3 3H19a3 3 0 0 1-3-3V15l3-5z" />
        <path d="M19 10h10M16 20h16v12H16M20 5h8" />
        <path d="M24 23s-3 4-3 5a3 3 0 0 0 6 0c0-1-3-5-3-5z" />
      </>
    ),
    food: (
      <>
        <path d="M7 34 24 11l17 23H7zM7 39h34M11 29h26" />
        <path d="m19 22 3 2m5-3 3 3m-14 7 3 2" />
      </>
    ),
    medical: (
      <>
        <rect x="9" y="7" width="30" height="34" rx="5" />
        <path d="M20 15h8v6h6v7h-6v6h-8v-6h-6v-7h6z" />
      </>
    ),
    bag: (
      <>
        <path d="M18 11V8a6 6 0 0 1 12 0v3M13 15l-4 6v20h30V21l-4-6M13 38V17a11 11 0 0 1 22 0v21" />
        <rect x="17" y="25" width="14" height="13" rx="2" />
        <path d="M17 30h14M20 18h8" />
      </>
    ),
    ammo: (
      <>
        <path d="M11 17 16 7l5 10v24H11zM27 17l5-10 5 10v24H27zM11 22h10M27 22h10M11 36h10M27 36h10" />
      </>
    ),
    weapon: (
      <>
        <path d="M5 13h36v9H26l-3 15H13l3-15H5zM26 22v7h-5M8 17h7M35 13v9" />
      </>
    ),
    rifle: (
      <>
        <path d="M3 21h8v-6h24v4h10v4H30l-3 14h-7l2-14h-5l-7 6H3zM13 15v-5h10M30 19h9M24 23l-1 8" />
      </>
    ),
    item: (
      <>
        <path d="m7 14 17-8 17 8v22l-17 8-17-8zM7 14l17 9 17-9M24 23v21M16 10l17 8v9" />
      </>
    ),
    hand: (
      <>
        <path d="M13 26V15a3 3 0 0 1 6 0v9-15a3 3 0 0 1 6 0v15-13a3 3 0 0 1 6 0v13-8a3 3 0 0 1 6 0v16c0 7-5 12-12 12-6 0-9-3-12-7l-7-9a3 3 0 0 1 5-4l8 8" />
      </>
    ),
    drop: (
      <>
        <path d="M24 6v24m-8-8 8 8 8-8M8 31v10h32V31" />
      </>
    ),
  };
  const fallback = (
    <svg
      viewBox="0 0 48 48"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.7"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {paths[name] ?? paths.item}
    </svg>
  );
  return <CatalogImage id={artwork} label={label} fallback={fallback}/>;
}
