export type HudData = {
  cash: number | false;
  id: number;
  players: number | false;
  connected: boolean;
  talking: boolean;
  range: number | false;
  inset: number;
};
const bounded = (v: unknown, max: number): v is number =>
  typeof v === "number" && Number.isFinite(v) && v >= 0 && v <= max;
const count = (v: unknown, max: number): boolean => bounded(v, max) && Number.isInteger(v);
export function parseHud(value: unknown): HudData | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const v = value as Record<string, unknown>;
  if ((v.cash !== false && !count(v.cash, Number.MAX_SAFE_INTEGER))
    || !count(v.id, 2147483647) || v.id === 0
    || (v.players !== false && !count(v.players, 100000))
    || typeof v.connected !== "boolean" || typeof v.talking !== "boolean"
    || (!v.connected && (v.talking || v.range !== false))
    || (v.range !== false && (!bounded(v.range, 10000) || v.range === 0))
    || !bounded(v.inset, 0.1)) return null;
  return v as HudData;
}
export const hudPreview: HudData = {
  cash: 2450, id: 12, players: 24, connected: true, talking: false, range: 3, inset: 0.025,
};
