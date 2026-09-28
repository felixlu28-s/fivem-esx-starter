import type { ActionResult } from "./nui";
import type { PhoneComment, PhonePost, SocialIdentity, SocialProfile } from "./phoneData";

const demo = new URLSearchParams(location.search).get("phoneDemo") !== "0";
const identities: (SocialIdentity & { mine: boolean })[] = demo ? [
  { id: 1, slot: 1, name: "Test Joost", handle: "test_joost", bio: "Los Santos. Ein neuer Anfang.\nSonne, gute Freunde & die Straße vor uns.", mine: true },
  { id: 2, slot: 1, name: "Lena Fischer", handle: "lena.fischer", bio: "Golden hour enthusiast ☀", mine: false },
  { id: 3, slot: 1, name: "Marc Weber", handle: "marc.weber", bio: "Schrauben. Fahren. Wiederholen.", mine: false },
  { id: 4, slot: 1, name: "Sofia Costa", handle: "sofia.costa", bio: "Postkarten aus Los Santos.", mine: false },
  { id: 5, slot: 2, name: "Joost Motors", handle: "joost.motors", bio: "Dein nächster Wagen wartet hier.\nLa Mesa · Los Santos", mine: true },
] : [];
let active = demo ? 1 : 0, next = 50;
const slots = demo ? 2 : 1, now = Math.floor(Date.now() / 1000);
const posts: PhonePost[] = demo ? [
  { id: 9, author: 2, photo: 101, caption: "Manchmal braucht es nur einen Sonnenuntergang und die richtigen Leute. 🌴", created: now - 1800, name: "Lena Fischer", handle: "lena.fischer", likes: 24, comments: 2, liked: false, following: true },
  { id: 8, author: 3, photo: 102, caption: "Feierabend. Noch eine Runde durch die Stadt?", created: now - 3600, name: "Marc Weber", handle: "marc.weber", likes: 12, comments: 0, liked: false, following: false },
  { id: 7, author: 1, photo: 103, caption: "Endlich angekommen. Hallo Los Santos!", created: now - 86400, name: "Test Joost", handle: "test_joost", likes: 8, comments: 0, liked: false, following: false },
  { id: 6, author: 4, photo: 104, caption: "Die Stadt schläft noch. Mein Lieblingsmoment.", created: now - 92000, name: "Sofia Costa", handle: "sofia.costa", likes: 31, comments: 0, liked: false, following: false },
  { id: 5, author: 1, photo: 105, caption: "Unterwegs mit Freunden.", created: now - 172800, name: "Test Joost", handle: "test_joost", likes: 6, comments: 0, liked: false, following: false },
  { id: 4, author: 5, photo: 106, caption: "Willkommen bei Joost Motors.", created: now - 200000, name: "Joost Motors", handle: "joost.motors", likes: 3, comments: 0, liked: false, following: false },
] : [];
const comments: (PhoneComment & { post: number })[] = demo ? [
  { id: 2, post: 9, author: 4, name: "Sofia Costa", handle: "sofia.costa", body: "Das Licht ist unglaublich!", created: now - 900 },
  { id: 1, post: 9, author: 3, name: "Marc Weber", handle: "marc.weber", body: "Nächstes Mal bin ich dabei.", created: now - 1200 },
] : [];
const follows = new Set(demo ? ["1:2", "2:1", "4:1"] : []), likes = new Set<string>();
const images = new Map<number, string>(), nonces = new Map<string, string>();
const actor = () => identities.find((p) => p.mine && p.id === active);
const info = (p: SocialIdentity): SocialProfile => ({ id: p.id, name: p.name, handle: p.handle, bio: p.bio,
  posts: posts.filter((v) => v.author === p.id).length, followers: [...follows].filter((v) => v.endsWith(`:${p.id}`)).length,
  follows: [...follows].filter((v) => v.startsWith(`${p.id}:`)).length, following: follows.has(`${active}:${p.id}`) });
const view = (p: PhonePost): PhonePost => ({ ...p, name: identities.find((a) => a.id === p.author)?.name ?? p.name,
  handle: identities.find((a) => a.id === p.author)?.handle ?? p.handle, likes: p.likes + [...likes].filter((v) => v.endsWith(`:${p.id}`)).length,
  liked: likes.has(`${active}:${p.id}`), following: follows.has(`${active}:${p.author}`), comments: comments.filter((c) => c.post === p.id).length });
const home = (): ActionResult => ({ ok: true, phone: { kind: "social_home", profiles: identities.filter((p) => p.mine).map(({ mine: _mine, ...p }) => p), slots, active } });
async function fixture(id: number) {
  const bitmap = await createImageBitmap(await (await fetch("./phone/wallpaper.png")).blob());
  try {
    const canvas = document.createElement("canvas"); canvas.width = 512; canvas.height = 512;
    const ctx = canvas.getContext("2d")!;
    ctx.filter = id % 3 === 0 ? "saturate(.7) brightness(1.25)" : id % 3 === 1 ? "saturate(1.2)" : "hue-rotate(12deg)";
    const size = Math.min(bitmap.width, bitmap.height);
    ctx.drawImage(bitmap, 0, (bitmap.height - size) * ((id % 3) / 2), size, size, 0, 0, 512, 512);
    return canvas.toDataURL("image/jpeg", .7);
  } finally { bitmap.close(); }
}
export async function phoneSocialPreview(action: string, d: Record<string, unknown>): Promise<ActionResult> {
  const id = Number(d.id), str = (key: string) => String(d[key] ?? ""), before = Number(d.before) || Number.MAX_SAFE_INTEGER;
  if (action === "social_home") return home();
  if (action === "social_create") {
    const existing = identities.find((p) => p.handle === d.handle);
    if (existing) return existing.mine ? home() : { ok: false, error: "handle_taken" };
    const own = identities.filter((p) => p.mine);
    if (own.length >= slots) return { ok: false, error: "social_limit" };
    if (!/^[a-z][a-z0-9_.]{2,23}$/.test(str("handle")) || !str("name").trim()) return { ok: false, error: "invalid_fields" };
    active = next++; identities.push({ id: active, slot: own.length + 1, mine: true, name: str("name"), handle: str("handle"), bio: str("bio") }); return home();
  }
  if (action === "social_switch") {
    if (!identities.some((p) => p.mine && p.id === id)) return { ok: false, error: "not_found" };
    active = id; return home();
  }
  if (action === "image") {
    if (!images.has(id) && posts.some((p) => p.photo === id)) images.set(id, await fixture(id));
    return images.has(id) ? { ok: true, phone: { kind: "image", id, image: images.get(id)! } } : { ok: false, error: "not_found" };
  }
  const me = actor();
  if (!me) return { ok: false, error: "social_register" };
  if (d.actor !== undefined && d.actor !== active) return { ok: false, error: "social_changed" };
  switch (action) {
    case "profile":
      if (identities.some((p) => p.id !== active && p.handle === d.handle)) return { ok: false, error: "handle_taken" };
      if (!/^[a-z][a-z0-9_.]{2,23}$/.test(str("handle"))) return { ok: false, error: "invalid_fields" };
      me.name = str("name"); me.handle = str("handle"); me.bio = str("bio"); return home();
    case "social_profile": { const p = identities.find((p) => p.id === id); return p ? { ok: true, phone: { kind: "social_profile", profile: info(p) } } : { ok: false, error: "not_found" }; }
    case "social_search":
    case "social_people": {
      const rows = identities.filter((p) => p.id < before && (action === "social_search" ? p.id !== active && p.handle.startsWith(str("query").toLowerCase())
        : follows.has(d.mode === "followers" ? `${p.id}:${id}` : `${id}:${p.id}`))).sort((a, b) => b.id - a.id).map(info);
      return { ok: true, phone: { kind: "social_people", rows: rows.slice(0, 20), more: rows.length > 20 } };
    }
    case "feed": { const rows = posts.filter((p) => p.id < before && (!d.id || p.id === id) && (!d.author || p.author === d.author) && (!d.following || follows.has(`${active}:${p.author}`))).map(view); return { ok: true, phone: { kind: "feed", rows: rows.slice(0, 15), more: rows.length > 15 } }; }
    case "publish_local": {
      const nonce = `${active}:${str("nonce")}`, canonical = `${str("image")}:${str("caption")}`;
      if (nonces.has(nonce)) return { ok: nonces.get(nonce) === canonical };
      if (posts.filter((p) => p.author === active).length >= 40) return { ok: false, error: "limit" };
      nonces.set(nonce, canonical); const photo = next++; images.set(photo, str("image"));
      posts.unshift({ id: next++, author: active, name: me.name, handle: me.handle, photo, caption: str("caption"), created: Math.floor(Date.now() / 1000), likes: 0, liked: false, comments: 0, following: false }); return { ok: true };
    }
    case "post_delete": { const index = posts.findIndex((p) => p.id === id && p.author === active); if (index >= 0) { images.delete(posts[index].photo); posts.splice(index, 1); } return { ok: true }; }
    case "like": { const key = `${active}:${id}`; if (d.enabled) likes.add(key); else likes.delete(key); return { ok: true }; }
    case "follow": { const key = `${active}:${id}`; if (d.enabled) follows.add(key); else follows.delete(key); return { ok: true }; }
    case "comments": { const rows = comments.filter((c) => c.post === id && c.id < before); return { ok: true, phone: { kind: "comments", rows: rows.slice(0, 30), more: rows.length > 30 } }; }
    case "comment": {
      const key = `comment:${active}:${str("nonce")}`, canonical = `${id}:${str("body")}`;
      if (nonces.has(key)) return { ok: nonces.get(key) === canonical };
      if (!str("body").trim()) return { ok: false, error: "invalid_fields" };
      nonces.set(key, canonical); comments.unshift({ id: next++, post: id, author: active, name: me.name, handle: me.handle, body: str("body"), created: Math.floor(Date.now() / 1000) }); return { ok: true };
    }
    default: return { ok: false, error: "unavailable" };
  }
}
