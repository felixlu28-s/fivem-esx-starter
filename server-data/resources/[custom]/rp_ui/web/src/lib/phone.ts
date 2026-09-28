export type PhonePayload = { available: boolean; open: boolean; session: string; toggleKey: string };
export function parsePhone(value: unknown): PhonePayload | null {
  if (!value || typeof value !== "object") return null;
  const v = value as Record<string, unknown>;
  return typeof v.available === "boolean" && typeof v.open === "boolean"
    && typeof v.session === "string" && v.session.length <= 100
    && typeof v.toggleKey === "string" && v.toggleKey.length <= 32 ? v as PhonePayload : null;
}
export const phoneApps = [
  { id: "calls", label: "Anrufe", x: 262, y: 390 },
  { id: "messages", label: "Messages", x: 470, y: 390 },
  { id: "contacts", label: "Contacts", x: 681, y: 390 },
  { id: "calendar", label: "Calendar", x: 262, y: 640 },
  { id: "camera", label: "Camera", x: 470, y: 640 },
  { id: "gallery", label: "Galerie", x: 681, y: 640 },
  { id: "tasks", label: "Tasks", x: 262, y: 882 },
  { id: "settings", label: "Settings", x: 470, y: 882 },
  { id: "ifruit", label: "iFruit", x: 681, y: 882 },
] as const;
export type PhoneApp = (typeof phoneApps)[number]["id"];
export type PhoneState = {
  page: "home" | "app" | "recent"; selected: number; app: PhoneApp;
  recent: PhoneApp[]; row: number; nav: number | null; backPage: "home" | "app";
  settings: { sound: boolean; brightness: number }; month: number;
};
export const initialPhone = (): PhoneState => ({ page: "home", selected: 2, app: "contacts", recent: [], row: 0,
  nav: null, backPage: "home", settings: { sound: true, brightness: 100 }, month: 0 });
export type PhoneKey = "up" | "down" | "left" | "right" | "enter" | "back";
export const appLabel = (id: PhoneApp) => phoneApps.find((a) => a.id === id)!.label;
export function phoneRows(s: PhoneState): number {
  if (s.page === "recent") return Math.max(1, s.recent.length * 2);
  return s.app === "settings" ? 2 : 1;
}
function launch(s: PhoneState, app: PhoneApp): PhoneState {
  return { ...s, app, selected: phoneApps.findIndex((a) => a.id === app), page: "app", row: 0, nav: null, recent: [app, ...s.recent.filter((a) => a !== app)].slice(0, 9) };
}
export function phoneStep(s: PhoneState, key: PhoneKey): { state: PhoneState; close?: boolean } {
  const next = (state: PhoneState) => ({ state });
  if (key === "back") {
    if (s.page === "home") return { state: s, close: true };
    return next({ ...s, page: s.page === "recent" ? s.backPage : "home", nav: null, row: 0 });
  }
  if (s.nav !== null) {
    if (key === "left" || key === "right") return next({ ...s, nav: (s.nav + (key === "left" ? 2 : 1)) % 3 });
    if (key === "up") return next({ ...s, nav: null, selected: 6 + s.nav, row: phoneRows(s) - 1 });
    if (key === "enter") {
      if (s.nav === 1) return next({ ...s, page: "home", nav: null });
      if (s.nav === 2) return phoneStep({ ...s, nav: null }, "back");
      return next({ ...s, page: "recent", backPage: s.page === "app" ? "app" : "home", row: 0, nav: null });
    }
    return next(s);
  }
  if (s.page === "home") {
    if (key === "enter") return next(launch(s, phoneApps[s.selected].id));
    if (key === "down" && s.selected >= 6) return next({ ...s, nav: s.selected % 3 });
    const delta = { up: -3, down: 3, left: -1, right: 1 }[key];
    return next({ ...s, selected: Math.max(0, Math.min(8, s.selected + (delta ?? 0))) });
  }
  if (key === "down") return next(s.row + 1 >= phoneRows(s) ? { ...s, nav: 1 } : { ...s, row: s.row + 1 });
  if (key === "up") return next({ ...s, row: Math.max(0, s.row - 1) });
  if (s.page === "recent" && key === "enter" && s.recent.length) {
    const index = Math.floor(s.row / 2), app = s.recent[index];
    if (s.row % 2 === 0) return next(launch(s, app));
    const recent = s.recent.filter((a) => a !== app);
    return next({ ...s, recent, month: app === "calendar" ? 0 : s.month, backPage: app === s.app ? "home" : s.backPage, row: Math.min(s.row, Math.max(0, recent.length * 2 - 1)) });
  }
  if (s.page === "app" && s.app === "settings") {
    if (s.row === 0 && (key === "enter" || key === "left" || key === "right")) return next({ ...s, settings: { ...s.settings, sound: !s.settings.sound } });
    if (s.row === 1 && (key === "left" || key === "right")) return next({ ...s, settings: { ...s.settings,
      brightness: Math.max(55, Math.min(100, s.settings.brightness + (key === "left" ? -5 : 5))) } });
  }
  if (s.page === "app" && s.app === "calendar" && (key === "left" || key === "right")) return next({ ...s, month: Math.max(-120, Math.min(120, s.month + (key === "left" ? -1 : 1))) });
  return next(s);
}
