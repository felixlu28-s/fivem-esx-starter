export type NativeValue = string | number | boolean;
type BaseItem = {
  id: string;
  label: string;
  description: string;
  rightLabel: string;
  disabled: boolean;
  hint?: { keys: string[]; label: string; detail: string };
};
export type NativeItem = BaseItem &
  (
    | { type: "action" }
    | { type: "submenu"; menu: string }
    | { type: "checkbox"; checked: boolean }
    | {
        type: "list";
        options: { label: string; value: NativeValue }[];
        index: number;
      }
  );
export type NativeMenuPayload = {
  title: string;
  subtitle: string;
  description: string;
  theme: "mint";
  visibleRows: number;
  items: NativeItem[];
  selected: number;
  depth: number;
  session: string;
  revision: number;
};
export type NativeKey = "up" | "down" | "left" | "right" | "enter" | "back";
const record = (v: unknown): v is Record<string, unknown> =>
  !!v && typeof v === "object" && !Array.isArray(v);
const text = (v: unknown, max: number): v is string =>
  typeof v === "string" && v.length <= max;
const integer = (v: unknown, min: number, max: number): v is number =>
  typeof v === "number" && Number.isSafeInteger(v) && v >= min && v <= max;
export function parseNativeMenu(v: unknown): NativeMenuPayload | null {
  if (
    !record(v) ||
    !text(v.title, 100) ||
    !text(v.subtitle, 120) ||
    !text(v.description, 600) ||
    v.theme !== "mint" ||
    !integer(v.visibleRows, 3, 12) ||
    !text(v.session, 80) ||
    !v.session ||
    !integer(v.revision, 0, Number.MAX_SAFE_INTEGER) ||
    !integer(v.depth, 1, 12) ||
    !Array.isArray(v.items) ||
    v.items.length > 200 ||
    !integer(v.selected, v.items.length ? 1 : 0, v.items.length)
  )
    return null;
  const seen = new Set<string>();
  for (const row of v.items) {
    if (
      !record(row) ||
      !text(row.id, 80) ||
      !/^[\w-]+$/.test(row.id) ||
      seen.has(row.id) ||
      !text(row.label, 180) ||
      !text(row.description, 600) ||
      !text(row.rightLabel, 100) ||
      typeof row.disabled !== "boolean"
    )
      return null;
    seen.add(row.id);
    if (row.hint !== undefined && (!record(row.hint) || !text(row.hint.label, 100) || !row.hint.label
      || !text(row.hint.detail, 120) || !Array.isArray(row.hint.keys) || row.hint.keys.length < 1 || row.hint.keys.length > 4
      || !row.hint.keys.every((key) => text(key, 8) && key.length > 0))) return null;
    if (row.type === "checkbox") {
      if (typeof row.checked !== "boolean") return null;
    } else if (row.type === "submenu") {
      if (!text(row.menu, 200) || !row.menu) return null;
    } else if (row.type === "list") {
      if (
        !Array.isArray(row.options) ||
        row.options.length < 1 ||
        row.options.length > 100 ||
        !integer(row.index, 1, row.options.length) ||
        !row.options.every(
          (o) =>
            record(o) &&
            text(o.label, 120) &&
            (text(o.value, 180) ||
              integer(o.value, -1e9, 1e9) ||
              typeof o.value === "boolean"),
        )
      )
        return null;
    } else if (row.type !== "action") return null;
  }
  return v as NativeMenuPayload;
}
export const nativeKeys: Readonly<Record<string, NativeKey>> = {
  ArrowUp: "up",
  ArrowDown: "down",
  ArrowLeft: "left",
  ArrowRight: "right",
  Enter: "enter",
  Backspace: "back",
  Escape: "back",
};
