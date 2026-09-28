import type {
  InventoryAction,
  InventoryItem,
  InventoryPayload,
  InventoryStore,
  InventoryRecipient,
} from "./inventory";
export const previewRecipients: InventoryRecipient[] = [
  { token: "demo-jamie", label: "Jamie Parker (#12)", distance: 1.2 },
  { token: "demo-sam", label: "Sam Rivera (#18)", distance: 2.4 },
];
export const previewRecipientStores = (): Record<string, InventoryStore> =>
  Object.fromEntries(
    previewRecipients.map((r) => [
      r.token,
      {
        side: "external",
        label: r.label,
        revision: 1,
        slots: 24,
        capacity: 25000,
        weight: 0,
        items: [],
      },
    ]),
  );
const item = (
  slot: number,
  name: string,
  label: string,
  count: number,
  weight: number,
  maxStack: number,
  icon: string,
  usable = false,
  bonusSlots = 0,
  bonusWeight = 0,
): InventoryItem => ({
  slot,
  name,
  label,
  count,
  weight,
  maxStack,
  icon,
  usable,
  bonusSlots,
  bonusWeight,
  description: label,
  ...(name.startsWith("WEAPON_") ? { artwork: `weapons/${name}` } : {}),
});
const weigh = (s: InventoryStore) =>
  s.items.reduce((n, e) => n + e.count * (e.weight + (e.attachments ?? []).reduce((w, a) => w + (attachmentCatalog[a.name]?.weight ?? 0), 0)), s.backpack?.weight ?? 0);
const attachmentCatalog: Record<string, { label: string; component: string; weapon: string; weight: number }> = {
  rp_pistol_light: { label: "Pistolenlampe", component: "COMPONENT_AT_PI_FLSH", weapon: "WEAPON_PISTOL", weight: 100 },
  rp_pistol_suppressor: { label: "Pistolen-Schalldämpfer", component: "COMPONENT_AT_PI_SUPP_02", weapon: "WEAPON_PISTOL", weight: 200 },
  rp_rifle_light: { label: "Gewehrlampe", component: "COMPONENT_AT_AR_FLSH", weapon: "WEAPON_CARBINERIFLE", weight: 150 },
  rp_rifle_scope: { label: "Karabiner-Zielfernrohr", component: "COMPONENT_AT_SCOPE_MEDIUM", weapon: "WEAPON_CARBINERIFLE", weight: 350 },
};
const same = (a: InventoryItem, b: InventoryItem) => a.name === b.name && JSON.stringify(a.attachments ?? []) === JSON.stringify(b.attachments ?? []);
export function inventoryPreview(): InventoryPayload {
  const own: InventoryStore = {
    side: "own",
    label: "Deine Taschen",
    revision: 1,
    slots: 24,
    capacity: 25000,
    weight: 0,
    items: [
      item(1, "rp_water", "Mineralwasser", 4, 500, 6, "water", true),
      item(2, "rp_sandwich", "Sandwich", 3, 250, 8, "food", true),
      item(3, "rp_bandage", "Verband", 3, 100, 10, "medical", true),
      { ...item(7, "WEAPON_PISTOL", "Pistole", 1, 1000, 1, "weapon", true), attachments: [
        { name: "rp_pistol_light", ...attachmentCatalog.rp_pistol_light },
        { name: "rp_pistol_suppressor", ...attachmentCatalog.rp_pistol_suppressor },
      ] },
      item(8, "ammo_pistol", "Pistolenmunition", 12, 12, 12, "ammo"),
      item(9, "WEAPON_CARBINERIFLE", "Karabiner", 1, 3500, 1, "rifle", true),
      item(10, "ammo_rifle", "Gewehrmunition", 30, 20, 30, "ammo"),
      item(
        13,
        "rp_backpack_small",
        "Tagesrucksack",
        1,
        1200,
        1,
        "bag",
        true,
        8,
        10000,
      ),
      item(
        14,
        "rp_backpack_large",
        "Reiserucksack",
        1,
        2500,
        1,
        "bag",
        true,
        16,
        25000,
      ),
      { ...item(17, "clothing_top", "Crew-T-Shirt", 1, 500, 1, "clothes", true), artwork: "clothing/0/top/0_0", clothing: {
        category: "top", image: "top", label: "Crew-T-Shirt", color: "#8b9c91", sex: 0, worn: true,
      } },
      { ...item(18, "clothing_glasses", "Goldene Pilotenbrille", 1, 40, 1, "clothes", true), artwork: "clothing/0/glasses/5_0", clothing: {
        category: "glasses", image: "glasses", label: "Goldene Pilotenbrille", color: "#404850", sex: 0, worn: false,
      } },
    ],
  };
  own.weight = weigh(own);
  return {
    session: "browser-inventory",
    own,
    external: {
      side: "external",
      label: "Testkiste",
      revision: 1,
      slots: 16,
      capacity: 100000,
      weight: 500,
      items: [item(1, "rp_water", "Mineralwasser", 1, 500, 6, "water", true)],
    },
  };
}
// Deliberately local demo state. FiveM never imports this state into the server.
export function previewInventoryAction(
  current: InventoryPayload,
  action: InventoryAction,
  recipients: Record<string, InventoryStore> = {},
): {
  inventory: InventoryPayload;
  recipients?: Record<string, InventoryStore>;
  error?: string;
} {
  const next = structuredClone(current);
  const fail = (error: string) => ({ inventory: current, error });
  const own = next.own;
  const check = (store: InventoryStore) =>
    store.items.every((e) => e.slot <= store.slots && e.count <= e.maxStack) &&
    weigh(store) <= store.capacity;
  if (action.action === "unequip") {
    const bag = own.backpack;
    if (!bag) return fail("invalid_item");
    own.slots -= bag.bonusSlots;
    own.capacity -= bag.bonusWeight;
    delete own.backpack;
    const free = Array.from({ length: own.slots }, (_, i) => i + 1).find(
      (slot) => !own.items.some((e) => e.slot === slot),
    );
    if (!free) return fail("backpack_full");
    own.items.push({ ...bag, slot: free });
    if (!check(own)) return fail("backpack_full");
  } else {
    const from = action.from === "external" ? next.external : own;
    const e = from?.items.find((e) => e.slot === action.slot);
    const count = action.count ?? 1;
    if (
      !from ||
      !e ||
      !Number.isSafeInteger(count) ||
      count < 1 ||
      count > e.count
    )
      return fail("not_enough");
    if (action.action === "detach") {
      const attachment = e.attachments?.find((a) => a.name === action.attachment);
      const def = attachment && attachmentCatalog[attachment.name];
      if (from !== own || !def || !attachment || def.weapon !== e.name) return fail("component_missing");
      const existing = own.items.find((i) => i.name === attachment.name && i.count < i.maxStack);
      const free = Array.from({ length: own.slots }, (_, i) => i + 1).find((s) => !own.items.some((i) => i.slot === s));
      if (!existing && !free) return fail("no_slots");
      e.attachments = e.attachments!.filter((a) => a !== attachment);
      if (existing) existing.count++;
      else own.items.push(item(free!, attachment.name, def.label, 1, def.weight, 5, "item", true));
    } else if (action.action === "use") {
      if (from !== own || !e.usable) return fail("not_usable");
      if (e.clothing) {
        const wear = !e.clothing.worn;
        for (const candidate of own.items) if (candidate.clothing?.category === e.clothing.category) candidate.clothing.worn = false;
        e.clothing.worn = wear;
      } else if (e.bonusSlots) {
        const old = own.backpack;
        own.slots += e.bonusSlots - (old?.bonusSlots ?? 0);
        own.capacity += e.bonusWeight - (old?.bonusWeight ?? 0);
        own.backpack = { ...e, slot: 0 };
        own.items = own.items.filter((i) => i !== e);
        if (old) own.items.push({ ...old, slot: e.slot });
        if (!check(own)) return fail("backpack_full");
      } else if (attachmentCatalog[e.name]) {
        const def = attachmentCatalog[e.name];
        const weapon = own.items.find((w) => w.name === def.weapon && !w.attachments?.some((a) => a.name === e.name));
        if (!weapon) return fail("no_compatible_weapon");
        weapon.attachments = [...(weapon.attachments ?? []), { name: e.name, label: def.label, component: def.component }];
        e.count--;
      } else if (!e.name.startsWith("WEAPON_")) e.count -= 1;
    } else if (action.action === "give") {
      const receiver = recipients[action.recipient ?? ""];
      if (from !== own || !receiver) return fail("recipient_unavailable");
      const target = structuredClone(receiver);
      if (e.clothing) e.clothing.worn = false;
      let remaining = count;
      for (const stack of target.items) {
        if (!same(stack, e)) continue;
        const added = Math.min(remaining, stack.maxStack - stack.count);
        stack.count += added;
        remaining -= added;
      }
      for (let slot = 1; slot <= target.slots && remaining > 0; slot++) {
        if (target.items.some((i) => i.slot === slot)) continue;
        const added = Math.min(remaining, e.maxStack);
        target.items.push({ ...e, slot, count: added });
        remaining -= added;
      }
      if (remaining > 0) return fail("no_slots");
      if (!check(target)) return fail("too_heavy");
      e.count -= count;
      own.items = own.items.filter((i) => i.count > 0);
      own.weight = weigh(own);
      own.revision++;
      target.weight = weigh(target);
      target.revision++;
      return {
        inventory: next,
        recipients: { ...recipients, [action.recipient!]: target },
      };
    } else if (action.action === "drop") {
      if (from !== own) return fail("invalid_state");
      e.count -= count; // World prop + E pickup are FiveM-only; never create a container.
    } else {
      const to = action.to === "external" ? next.external : own;
      if (!to) return fail("no_slots");
      const target = action.target;
      if (!target || (from === to && target === e.slot))
        return fail("invalid_slot");
      const other = to.items.find((i) => i.slot === target);
      if (from !== to) {
        if (e.clothing) e.clothing.worn = false;
        if (other?.clothing) other.clothing.worn = false;
      }
      if (other && !same(other, e)) {
        if (count !== e.count) return fail("slot_occupied");
        const original = e.slot;
        from.items = from.items.filter((i) => i !== e);
        to.items = to.items.filter((i) => i !== other);
        from.items.push({ ...other, slot: original });
        to.items.push({ ...e, slot: target });
      } else {
        if ((other?.count ?? 0) + count > e.maxStack) return fail("no_slots");
        if (other) other.count += count;
        else to.items.push({ ...e, slot: target, count });
        e.count -= count;
      }
    }
  }
  for (const store of [own, next.external])
    if (store) {
      store.items = store.items.filter((e) => e.count > 0);
      store.weight = weigh(store);
      if (!check(store)) return fail("too_heavy");
      store.revision += 1;
    }
  return { inventory: next };
}
