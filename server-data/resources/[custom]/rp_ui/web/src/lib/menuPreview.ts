import catalog from "./input-preview.json";
import { parseBindings, type BindingPayload, type ProfilePayload } from "./nui";

// Browser fixture mirrors rp_core/shared/input.lua; never used in FiveM.
export const bindingPreview: BindingPayload = {
  ...catalog,
  actions: [
    ...catalog.actions,
    { id:'rp_banking:interact',label:'Geldautomat benutzen',category:'Interaktionen',description:'Den angezeigten Geldautomaten öffnen / schließen.',defaultKey:'E',key:'E',context:'all' },
    { id: "rp_phone:open", label: "Handy herausholen", category: "Menüs", description: "iFruit mit Pfeiltasten, Enter und Zurück bedienen.", defaultKey: "UP", key: "UP", context: "all" },
    { id: "rp_admin:open", label: "Administration", category: "Menüs", description: "Adminmenü öffnen / schließen.", defaultKey: "F10", key: "F10", context: "all" },
    {
      id: "rp_inventory:pickup",
      label: "Gegenstand aufheben",
      category: "Interaktionen",
      description: "Den angezeigten Gegenstand vom Boden aufheben.",
      defaultKey: "E",
      key: "E",
      context: "all",
    },
    {
      id: "rp_commerce:interact",
      label: "Shop / Werkbank öffnen",
      category: "Interaktionen",
      description: "Einen Laden oder eine Werkbank in deiner Nähe öffnen.",
      defaultKey: "E",
      key: "E",
      context: "all",
    },
  ],
};
export function loadBindingPreview(): BindingPayload {
  let saved: BindingPayload | null = null;
  try {
    saved = parseBindings(
      JSON.parse(localStorage.getItem("rp-input-preview") ?? "null"),
    );
  } catch {
    /* Invalid/old demo data falls back to the current catalog. */
  }
  return {
    ...bindingPreview,
    actions: bindingPreview.actions.map((action) => {
      const key = saved?.actions.find(
        (previous) => previous.id === action.id,
      )?.key;
      const valid =
        key === "" ||
        bindingPreview.keys.some(
          (candidate) => candidate.id === key && !candidate.reserved,
        );
      return {
        ...action,
        key: valid && key !== undefined ? key : action.defaultKey,
      };
    }),
  };
}
export const profilePreview: ProfilePayload = {
  name: "Alex Morgan",
  firstname: "Alex",
  lastname: "Morgan",
  birthdate: "14.06.1998",
  height: 182,
  job: "Arbeitslos",
  grade: "Bürger",
  cash: 1250,
  bank: 18750,
  level: 8,
  runningMeters: 7420,
  trainingSeconds: 2140,
  metersPerLevel: 1000,
  maxLevel: 100,
  stamina: 86,
};
