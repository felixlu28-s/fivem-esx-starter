import { isRecord } from "./nui";
import { isArtwork } from "../components/CatalogImage";
export type InventoryItem = {
  artwork?: string;
  clothing?: { category: string; label: string; image: string; color: string; sex: number; worn: boolean };
  attachments?: { name: string; label: string; component: string }[];
  slot: number;
  name: string;
  label: string;
  count: number;
  weight: number;
  maxStack: number;
  icon: string;
  description: string;
  usable: boolean;
  bonusSlots: number;
  bonusWeight: number;
};
export type InventorySide = "own" | "external";
export type InventoryStore = {
  side: InventorySide;
  label: string;
  revision: number;
  slots: number;
  capacity: number;
  weight: number;
  items: InventoryItem[];
  backpack?: InventoryItem;
};
export type InventoryPayload = {
  session: string;
  own: InventoryStore;
  external?: InventoryStore;
};
export type InventoryAction = {
  action: "move" | "use" | "drop" | "unequip" | "give" | "detach";
  attachment?: string;
  from?: InventorySide;
  to?: InventorySide;
  slot?: number;
  target?: number;
  count?: number;
  recipient?: string;
};
export type InventoryRecipient = {
  token: string;
  label: string;
  distance: number;
};
export function isInventoryRecipients(v: unknown): v is InventoryRecipient[] {
  return (
    Array.isArray(v) &&
    v.length <= 16 &&
    v.every(
      (r: unknown) =>
        isRecord(r) &&
        typeof r.token === "string" &&
        r.token.length > 0 &&
        r.token.length <= 80 &&
        typeof r.label === "string" &&
        r.label.length <= 160 &&
        typeof r.distance === "number" &&
        Number.isFinite(r.distance) &&
        r.distance >= 0 &&
        r.distance <= 3,
    )
  );
}
const integer = (v: unknown, min: number, max: number): v is number =>
  typeof v === "number" && Number.isSafeInteger(v) && v >= min && v <= max;
function isItem(v: unknown): v is InventoryItem {
  return (
    isRecord(v) && isArtwork(v.artwork) &&
    ["name", "label", "icon", "description"].every(
      (k) => typeof v[k] === "string" && String(v[k]).length <= 1000,
    ) &&
    integer(v.slot, 0, 216) &&
    integer(v.count, 1, 100000) &&
    integer(v.weight, 0, 10000000) &&
    integer(v.maxStack, 1, 100000) &&
    v.count <= v.maxStack &&
    typeof v.usable === "boolean" &&
    (v.clothing === undefined || (isRecord(v.clothing) &&
      ["category","label","image"].every(k => typeof v.clothing === 'object' && v.clothing !== null && typeof (v.clothing as Record<string,unknown>)[k] === 'string') &&
      typeof v.clothing.color === 'string' && /^#[a-fA-F0-9]{6}$/.test(v.clothing.color) &&
      integer(v.clothing.sex,0,1) && typeof v.clothing.worn === 'boolean')) &&
    (v.attachments === undefined || (Array.isArray(v.attachments) && v.attachments.length <= 32 &&
      v.attachments.every((a: unknown) => isRecord(a) && ["name", "label", "component"].every(
        (k) => typeof a[k] === "string" && String(a[k]).length > 0 && String(a[k]).length <= 120)))) &&
    integer(v.bonusSlots, 0, 16) &&
    integer(v.bonusWeight, 0, 10000000)
  );
}
function isStore(v: unknown, side: InventorySide): v is InventoryStore {
  return (
    isRecord(v) &&
    v.side === side &&
    typeof v.label === "string" &&
    integer(v.revision, 0, Number.MAX_SAFE_INTEGER) &&
    integer(v.slots, 1, 216) &&
    integer(v.capacity, 0, 10000000) &&
    integer(v.weight, 0, 10000000) &&
    Array.isArray(v.items) &&
    v.items.length <= v.slots &&
    v.items.every(isItem) &&
    v.items.every((e) => e.slot >= 1 && e.slot <= Number(v.slots)) &&
    new Set(v.items.map((e) => e.slot)).size === v.items.length &&
    (v.backpack === undefined || (isItem(v.backpack) && v.backpack.slot === 0))
  );
}
export function parseInventory(v: unknown): InventoryPayload | null {
  if (
    !isRecord(v) ||
    typeof v.session !== "string" ||
    v.session.length > 80 ||
    !isStore(v.own, "own") ||
    (v.external !== undefined && !isStore(v.external, "external"))
  )
    return null;
  return v as InventoryPayload;
}
export const inventoryErrors: Record<string, string> = {
  clothing_not_ready: "Die Einreisekleidung braucht zuerst freie Inventarplätze. Schaffe Platz und verbinde dich erneut.",
  invalid_garment: "Die Kleidungsdaten sind ungültig. Bitte die Administration kontaktieren.",
  clothing_wrong_model: "Dieses Kleidungsstück passt zum anderen Freemode-Modell.",
  clothing_interrupted: "Umziehen unterbrochen. Das Kleidungsstück wurde nicht weitergegeben.",
  component_missing: "Dieser Aufsatz ist nicht mehr an der Waffe montiert.",
  invalid_request: "Die Verschiebung enthält ungültige Angaben. Bitte das Inventar neu öffnen.",
  invalid_slot: "Dieser Slot ist kein gültiges Ablageziel.",
  session_expired: "Die Inventarsitzung ist abgelaufen. Bitte schließen und erneut öffnen.",
  invalid_state: "Diese Aktion ist hier gerade nicht möglich.",
  rate_limited: "Bitte einen Moment zwischen zwei Aktionen warten.",
  ground_full: "Hier können gerade keine weiteren Gegenstände abgelegt werden.",
  busy: "Dieser Vorgang wird gerade verarbeitet. Bitte kurz warten.",
  item_unavailable: "Dieser Gegenstand ist nicht mehr verfügbar.",
  recipient_unavailable:
    "Die Person ist nicht mehr erreichbar. Bitte erneut auswählen.",
  stale_inventory:
    "Der Bestand hat sich geändert. Die Ansicht wurde aktualisiert.",
  too_heavy: "Dafür reicht die Tragkraft nicht.",
  no_slots: "Kein freier Platz oder der Stapel ist voll.",
  backpack_full:
    "Leere zuerst die zusätzlichen Rucksackplätze und reduziere das Gewicht.",
  not_enough: "Diese Menge ist nicht mehr vorhanden.",
  out_of_range: "Der Behälter ist nicht mehr in deiner Nähe.",
  slot_occupied: "Für einen Tausch muss der ganze Stapel ausgewählt sein.",
  not_usable: "Dieser Gegenstand ist nicht benutzbar.",
  no_compatible_weapon: "Keine passende Waffe ohne dieses Zubehör im Inventar.",
  request_reused:
    "Diese Anfrage wurde bereits verarbeitet. Aktualisiere das Inventar.",
};
export const kg = (grams: number) =>
  (grams / 1000).toLocaleString("de-DE", { maximumFractionDigits: 2 });
