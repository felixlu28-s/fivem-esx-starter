import { isArtwork } from "../components/CatalogImage";
export type Ingredient = {
  artwork?: string;
  name: string;
  label: string;
  icon: string;
  count: number;
  owned: number;
};
export type CommerceOffer = {
  artwork?: string;
  garment?: { category: string; image: string; color: string; view: "body" | "face" | "upper" | "lower" | "shoes" };
  id: string;
  label: string;
  icon: string;
  description: string;
  category: string;
  weight: number;
  price: number;
  count: number;
  seconds: number;
  owned: number;
  ingredients: Ingredient[];
};
export type CommercePayload = {
  clothing?: boolean;
  currentClothing?: { artwork?: string; category: string; label: string; image: string; color: string }[];
  session: string;
  kind: "shop" | "crafting";
  label: string;
  subtitle: string;
  cash: number;
  bank: number;
  maxQuantity: number;
  offers: CommerceOffer[];
  pending: "none" | "intent" | "paid";
  job?: {
    token: string;
    offer: string;
    quantity: number;
    duration: number;
    remaining: number;
  };
};
const record = (v: unknown): v is Record<string, unknown> =>
  !!v && typeof v === "object" && !Array.isArray(v);
const str = (v: unknown): v is string =>
  typeof v === "string" && v.length <= 250;
const num = (v: unknown, max = 1e12): v is number =>
  typeof v === "number" && Number.isSafeInteger(v) && v >= 0 && v <= max;
export function parseCommerce(v: unknown): CommercePayload | null {
  if (
    !record(v) ||
    (v.clothing !== undefined && typeof v.clothing !== 'boolean') ||
    (v.currentClothing !== undefined && (!Array.isArray(v.currentClothing) || v.currentClothing.length > 12 ||
      !v.currentClothing.every(c => record(c) && isArtwork(c.artwork) && str(c.category) && str(c.label) && str(c.image) &&
        typeof c.color === 'string' && /^#[a-fA-F0-9]{6}$/.test(c.color)))) ||
    !str(v.session) ||
    !str(v.label) ||
    !str(v.subtitle) ||
    !["shop", "crafting"].includes(String(v.kind)) ||
    !num(v.cash) ||
    !num(v.bank) ||
    !num(v.maxQuantity, 100) ||
    v.maxQuantity < 1 ||
    !["none", "intent", "paid"].includes(String(v.pending)) ||
    !Array.isArray(v.offers) ||
    v.offers.length > 100 ||
    !v.offers.every(
      (o) =>
        record(o) && isArtwork(o.artwork) &&
        (o.garment === undefined || (record(o.garment) && str(o.garment.category) && str(o.garment.image) &&
          typeof o.garment.color === 'string' && /^#[a-fA-F0-9]{6}$/.test(o.garment.color) &&
          ['body','face','upper','lower','shoes'].includes(String(o.garment.view)))) &&
        ["id", "label", "icon", "description", "category"].every((k) =>
          str(o[k]),
        ) &&
        ["weight", "price", "count", "seconds", "owned"].every((k) =>
          num(o[k]),
        ) &&
        Number(o.count) > 0 &&
        Array.isArray(o.ingredients) &&
        o.ingredients.length <= 30 &&
        o.ingredients.every(
          (i) =>
            record(i) && isArtwork(i.artwork) &&
            ["name", "label", "icon"].every((k) => str(i[k])) &&
            num(i.count, 10000) &&
            i.count > 0 &&
            num(i.owned),
        ),
    ) ||
    new Set(v.offers.map((o) => (o as CommerceOffer).id)).size !==
      v.offers.length
  )
    return null;
  if (
    v.job !== undefined &&
    (!record(v.job) ||
      !str(v.job.token) ||
      !str(v.job.offer) ||
      !num(v.job.quantity, 100) ||
      v.job.quantity < 1 ||
      !num(v.job.duration, 300000) ||
      v.job.duration < 1 ||
      !num(v.job.remaining, v.job.duration) ||
      !v.offers.some(
        (o) =>
          (o as CommerceOffer).id === (v.job as Record<string, unknown>).offer,
      ))
  )
    return null;
  return v as CommercePayload;
}
export const commerceErrors: Record<string, string> = {
  clothing_wrong_model: 'Diese Kleidung passt nicht zu deinem Charaktermodell.',
  clothing_not_ready: 'Deine Kleidung wird noch geladen. Öffne den Laden gleich erneut.',
  no_slots: 'In deinen Taschen fehlen freie Plätze.',
  not_enough_money: "Dafür reicht dein Guthaben nicht.",
  not_enough: "Dir fehlen Materialien für dieses Rezept.",
  balance_changed:
    "Dein Kontostand hat sich geändert. Bitte aktualisieren und erneut kaufen.",
  too_heavy: "Deine Taschen wären zu schwer.",
  no_space: "In deinen Taschen fehlen freie Plätze.",
  inventory_full: "Dein Inventar ist voll.",
  busy: "Deine letzte Aktion wird noch verarbeitet.",
  out_of_range: "Du bist zu weit entfernt.",
  session_expired: "Bitte öffne den Laden oder die Werkbank erneut.",
  craft_not_ready: "Die Herstellung ist noch nicht abgeschlossen.",
  rate_limited: "Einen Moment bitte.",
  payment_review:
    "Diese Zahlung muss geprüft werden. Es wird nichts erneut abgebucht.",
  pending_purchase:
    "Ein früherer Einkauf ist noch offen. Bitte schließe ihn zuerst ab.",
  original_shop_required:
    "Hole die offene Bestellung beim ursprünglichen Laden ab.",
  nothing_pending: "Es ist keine Bestellung mehr offen.",
  database_error:
    "Verbindung unterbrochen. Aktualisiere den Status vor einem neuen Versuch.",
  request_reused:
    "Diese Anfrage gehört zu einem anderen Einkauf. Bitte aktualisieren.",
};
