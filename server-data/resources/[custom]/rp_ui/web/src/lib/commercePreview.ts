import type { CommercePayload, CommerceOffer } from "./commerce";
import type { ActionResult } from "./nui";
const catalog: Record<string, { label: string; icon: string; weight: number }> =
  {
    rp_water: { label: "Mineralwasser", icon: "water", weight: 500 },
    rp_sandwich: { label: "Sandwich", icon: "food", weight: 250 },
    rp_bandage: { label: "Verband", icon: "medical", weight: 100 },
    rp_backpack_small: { label: "Tagesrucksack", icon: "bag", weight: 1200 },
    rp_backpack_large: { label: "Reiserucksack", icon: "bag", weight: 2500 },
    rp_fabric: { label: "Stoff", icon: "fabric", weight: 150 },
    rp_thread: { label: "Nähgarn", icon: "thread", weight: 50 },
    rp_plastic: { label: "Kunststoff", icon: "item", weight: 100 },
  };
let stock: Record<string, number> = {
  rp_water: 4,
  rp_fabric: 12,
  rp_thread: 6,
  rp_plastic: 4,
};
let cash = 1250,
  bank = 8750;
let job:
  | { offer: string; quantity: number; deadline: number; token: string }
  | undefined;
const items: Record<string, string> = {
  water: "rp_water",
  sandwich: "rp_sandwich",
  bandage: "rp_bandage",
  backpack: "rp_backpack_small",
  fabric: "rp_fabric",
  thread: "rp_thread",
  plastic: "rp_plastic",
  daypack: "rp_backpack_small",
  travelpack: "rp_backpack_large",
};
const recipes: Record<string, [string, number][]> = {
  bandage: [
    ["rp_fabric", 2],
    ["rp_water", 1],
  ],
  daypack: [
    ["rp_fabric", 6],
    ["rp_thread", 2],
    ["rp_plastic", 2],
  ],
  travelpack: [
    ["rp_backpack_small", 1],
    ["rp_fabric", 8],
    ["rp_thread", 4],
  ],
};
const prices: Record<string, number> = {
  water: 12,
  sandwich: 25,
  bandage: 45,
  backpack: 350,
  fabric: 8,
  thread: 5,
  plastic: 6,
};
const seconds: Record<string, number> = {
  bandage: 3,
  daypack: 6,
  travelpack: 10,
};
export function commercePreview(kind: "shop" | "crafting"): CommercePayload {
  const offers: CommerceOffer[] = Object.keys(
    kind === "shop" ? prices : recipes,
  ).map((id) => {
    const item = items[id];
    return {
      id,
      ...catalog[item],
      description:
        kind === "shop"
          ? "Für deinen Alltag in Los Santos."
          : "An dieser Werkbank herstellbar.",
      category:
        kind === "crafting"
          ? id === "bandage"
            ? "Versorgung"
            : "Taschen"
          : ["fabric", "thread", "plastic"].includes(id)
            ? "Material"
            : ["water", "sandwich"].includes(id)
              ? "Verpflegung"
              : "Ausrüstung",
      count: 1,
      price: kind === "shop" ? prices[id] : 0,
      seconds: kind === "crafting" ? seconds[id] : 0,
      owned: stock[item] ?? 0,
      ingredients:
        kind === "crafting"
          ? recipes[id].map(([name, count]) => ({
              name,
              ...catalog[name],
              count,
              owned: stock[name] ?? 0,
            }))
          : [],
    };
  });
  return {
    session: "browser-commerce",
    kind,
    label: kind === "shop" ? "24/7 · Strawberry" : "Werkbank · Strawberry",
    subtitle:
      kind === "shop"
        ? "Alles für deinen nächsten Schritt."
        : "Aus Materialien wird etwas Eigenes.",
    cash,
    bank,
    maxQuantity: kind === "shop" ? 20 : 5,
    offers,
    pending: "none",
    job:
      kind === "crafting" && job
        ? {
            token: job.token,
            offer: job.offer,
            quantity: job.quantity,
            duration: seconds[job.offer] * job.quantity * 1000,
            remaining: Math.max(0, job.deadline - Date.now()),
          }
        : undefined,
  };
}
export function demoCommerce(
  kind: "shop" | "crafting",
  p: Record<string, unknown>,
): ActionResult {
  let error: string | undefined;
  const id = String(p.offer),
    quantity = Number(p.quantity);
  if (
    p.action === "buy" &&
    kind === "shop" &&
    prices[id] &&
    Number.isInteger(quantity) &&
    quantity >= 1 &&
    quantity <= 20
  ) {
    const total = prices[id] * quantity;
    if ((p.account === "money" ? cash : bank) < total)
      error = "not_enough_money";
    else {
      if (p.account === "money") cash -= total;
      else bank -= total;
      stock[items[id]] = (stock[items[id]] ?? 0) + quantity;
    }
  } else if (
    p.action === "craft" &&
    recipes[id] &&
    quantity >= 1 &&
    quantity <= 5
  ) {
    if (
      recipes[id].some(([name, count]) => (stock[name] ?? 0) < count * quantity)
    )
      error = "not_enough";
    else
      job = {
        offer: id,
        quantity,
        deadline: Date.now() + seconds[id] * quantity * 1000,
        token: crypto.randomUUID(),
      };
  } else if (p.action === "finish" && job && p.token === job.token) {
    if (Date.now() < job.deadline) error = "craft_not_ready";
    else {
      for (const [name, count] of recipes[job.offer])
        stock[name] -= count * job.quantity;
      stock[items[job.offer]] = (stock[items[job.offer]] ?? 0) + job.quantity;
      job = undefined;
    }
  } else if (p.action === "cancel") job = undefined;
  return { ok: !error, error, commerce: commercePreview(kind) };
}
