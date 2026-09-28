import { PhoneCapture } from "./phoneCapture";

// Browser/CEF storage only. No network writes, file picker, drop/paste import,
// NUI "save blob" callback or externally supplied URL enters this module.
// AES-GCM detects modified records; it cannot attest an unmodified game client.
export const galleryLimits = { entries: 200, bytes: 256 * 1024 * 1024, videoBytes: 16 * 1024 * 1024, seconds: 45 } as const;
export type GalleryInfo = { id: string; scope: string; created: number; kind: "photo" | "video"; width: number; height: number; duration: number; mime: string; bytes: number };
type Entry = GalleryInfo & { iv: Uint8Array<ArrayBuffer>; thumb: ArrayBuffer };
type Media = { id: string; iv: Uint8Array<ArrayBuffer>; data: ArrayBuffer };
export type GalleryItem = GalleryInfo & { thumbnail: Blob };
export type LocalRecording = { finished: Promise<GalleryInfo>; stop: () => void; cancel: () => void };
let database: Promise<IDBDatabase> | undefined;
const keys = new Map<string, Promise<CryptoKey>>();
const safeScope = (scope: string) => /^[a-zA-Z0-9:_-]{1,100}$/.test(scope);
const request = <T>(value: IDBRequest<T>) => new Promise<T>((resolve, reject) => { value.onsuccess = () => resolve(value.result); value.onerror = () => reject(value.error); });
const complete = (tx: IDBTransaction) => new Promise<void>((resolve, reject) => { tx.oncomplete = () => resolve(); tx.onabort = tx.onerror = () => reject(tx.error ?? new Error("Lokaler Speicher nicht verfügbar.")); });
function db() {
  return database ??= new Promise<IDBDatabase>((resolve, reject) => {
    if (!globalThis.indexedDB || !crypto.subtle) { reject(new Error("Der lokale Fotospeicher ist nicht verfügbar.")); return; }
    const opening = indexedDB.open("rp-phone-gallery-v1", 1);
    opening.onupgradeneeded = () => {
      opening.result.createObjectStore("keys");
      const entries = opening.result.createObjectStore("entries", { keyPath: "id" });
      entries.createIndex("scope", "scope", { unique: false });
      opening.result.createObjectStore("media", { keyPath: "id" });
    };
    opening.onsuccess = () => { const result = opening.result; result.onversionchange = () => { result.close(); database = undefined; keys.clear(); }; resolve(result); };
    opening.onerror = () => { database = undefined; reject(opening.error); };
    opening.onblocked = () => reject(new Error("Fotospeicher wird in einem anderen Fenster verwendet."));
  });
}
async function key(scope: string) {
  if (!safeScope(scope)) throw new Error("Galerie gehört zu keiner aktiven Telefonsitzung.");
  let pending = keys.get(scope);
  if (!pending) {
    pending = (async () => {
      const store = await db();
      const existing = await request(store.transaction("keys").objectStore("keys").get(scope)) as CryptoKey | undefined;
      if (existing) return existing;
      const generated = await crypto.subtle.generateKey({ name: "AES-GCM", length: 256 }, false, ["encrypt", "decrypt"]);
      // Recheck atomically: two Studio tabs must never overwrite each other's key.
      const tx = store.transaction("keys", "readwrite"), done = complete(tx), table = tx.objectStore("keys");
      const current = table.get(scope);
      let chosen = generated;
      current.onsuccess = () => { if (current.result) chosen = current.result as CryptoKey; else table.put(generated, scope); };
      await done; return chosen;
    })();
    keys.set(scope, pending);
    void pending.catch(() => keys.delete(scope));
  }
  return pending;
}
const info = (entry: GalleryInfo): GalleryInfo => ({ id: entry.id, scope: entry.scope, created: entry.created, kind: entry.kind,
  width: entry.width, height: entry.height, duration: entry.duration, mime: entry.mime, bytes: entry.bytes });
const aad = (entry: GalleryInfo, part: "thumb" | "media") => new TextEncoder().encode(JSON.stringify({ version: 1, part, ...info(entry) }));
function valid(entry: Entry, scope: string) {
  return entry && entry.scope === scope && typeof entry.id === "string" && /^[a-f0-9-]{36}$/.test(entry.id)
    && Number.isFinite(entry.created) && entry.created > 0 && entry.width === 720 && entry.height === 960
    && Number.isFinite(entry.duration) && entry.duration >= 0 && entry.duration <= galleryLimits.seconds + 3
    && Number.isSafeInteger(entry.bytes) && entry.bytes > 0 && entry.bytes <= galleryLimits.videoBytes
    && (entry.kind === "photo" && entry.mime === "image/jpeg" && entry.duration === 0 || entry.kind === "video" && /^video\/webm(?:;codecs=vp[89])?$/.test(entry.mime))
    && entry.iv instanceof Uint8Array && entry.iv.length === 12 && entry.thumb instanceof ArrayBuffer && entry.thumb.byteLength <= 100000;
}
async function thumbnail(entry: Entry, scope: string): Promise<Blob> {
  if (!valid(entry, scope)) throw new Error("Ungültige lokale Aufnahme.");
  const plain = await crypto.subtle.decrypt({ name: "AES-GCM", iv: entry.iv, additionalData: aad(entry, "thumb") }, await key(scope), entry.thumb);
  return new Blob([plain], { type: "image/jpeg" });
}
export async function listLocalMedia(scope: string): Promise<{ items: GalleryItem[]; damaged: number }> {
  if (!safeScope(scope)) throw new Error("Galerie nicht verfügbar.");
  const store = await db();
  const rows = await request(store.transaction("entries").objectStore("entries").index("scope").getAll(scope)) as Entry[];
  const items: GalleryItem[] = []; let damaged = 0;
  // Only tiny thumbnails are read here. Video bytes are fetched on explicit open.
  for (const row of rows.slice(0, galleryLimits.entries)) {
    try { items.push({ ...info(row), thumbnail: await thumbnail(row, scope) }); } catch { damaged++; }
  }
  return { items: items.sort((a, b) => b.created - a.created), damaged };
}
export async function loadLocalMedia(scope: string, id: string): Promise<{ info: GalleryInfo; blob: Blob }> {
  const store = await db();
  const tx = store.transaction(["entries", "media"]);
  const [entry, media] = await Promise.all([request(tx.objectStore("entries").get(id)) as Promise<Entry | undefined>, request(tx.objectStore("media").get(id)) as Promise<Media | undefined>]);
  if (!entry || !media) throw new Error("Diese Aufnahme ist nicht mehr vorhanden.");
  await thumbnail(entry, scope);
  if (!(media.iv instanceof Uint8Array) || media.iv.length !== 12 || !(media.data instanceof ArrayBuffer) || media.data.byteLength !== entry.bytes + 16) throw new Error("Die Aufnahme wurde verändert.");
  try {
    const plain = await crypto.subtle.decrypt({ name: "AES-GCM", iv: media.iv, additionalData: aad(entry, "media") }, await key(scope), media.data);
    return { info: info(entry), blob: new Blob([plain], { type: entry.mime }) };
  } catch { throw new Error("Die Aufnahme ist beschädigt oder wurde verändert."); }
}
export async function removeLocalMedia(scope: string, id: string) {
  const store = await db(), tx = store.transaction(["entries", "media"], "readwrite"), done = complete(tx);
  const entry = tx.objectStore("entries").get(id);
  entry.onsuccess = () => { if (entry.result?.scope === scope) { tx.objectStore("entries").delete(id); tx.objectStore("media").delete(id); } };
  await done; // No trash, retained blob or server copy in the private gallery.
}
async function save(scope: string, blob: Blob, thumb: Blob, kind: GalleryInfo["kind"], duration: number): Promise<GalleryInfo> {
  if (!blob.size || blob.size > galleryLimits.videoBytes) throw new Error("Diese Aufnahme überschreitet das lokale Größenlimit.");
  const entry: GalleryInfo = { id: crypto.randomUUID(), scope, created: Date.now(), kind, width: 720, height: 960, duration, mime: blob.type, bytes: blob.size };
  const secret = await key(scope), iv = crypto.getRandomValues(new Uint8Array(12)), thumbnailIv = crypto.getRandomValues(new Uint8Array(12));
  const [data, thumbnailData] = await Promise.all([
    crypto.subtle.encrypt({ name: "AES-GCM", iv, additionalData: aad(entry, "media") }, secret, await blob.arrayBuffer()),
    crypto.subtle.encrypt({ name: "AES-GCM", iv: thumbnailIv, additionalData: aad(entry, "thumb") }, secret, await thumb.arrayBuffer()),
  ]);
  const store = await db(), tx = store.transaction(["entries", "media"], "readwrite"), done = complete(tx);
  const entries = tx.objectStore("entries"), rows = entries.getAll();
  let full = false;
  rows.onsuccess = () => {
    const stored = rows.result as Entry[];
    if (stored.length >= galleryLimits.entries || stored.reduce((total, item) => total + (Number.isFinite(item.bytes) ? item.bytes : galleryLimits.videoBytes), 0) + blob.size > galleryLimits.bytes) { full = true; tx.abort(); return; }
    entries.add({ ...entry, iv: thumbnailIv, thumb: thumbnailData } satisfies Entry);
    tx.objectStore("media").add({ id: entry.id, iv, data } satisfies Media);
  };
  try { await done; } catch (error) {
    if (full || error instanceof DOMException && error.name === "QuotaExceededError") throw new Error("Deine lokale Galerie ist voll. Lösche zuerst einige Aufnahmen.");
    throw error;
  }
  // No storage/permission probe here: FiveM's CEF 103 can crash natively in
  // Chrome's bookmark preference loading after storage.persist(). A JS catch
  // cannot contain it. IndexedDB commits already survive normal restarts;
  // clearing the local cache or browser storage pressure can still remove them.
  return entry;
}
export async function takeLocalPhoto(scope: string, capture: PhoneCapture) {
  if (!(capture instanceof PhoneCapture) || !capture.ready || capture.width !== 720) throw new Error("Warte, bis die Kamera bereit ist.");
  return save(scope, await capture.snapshot(), await capture.thumbnail(), "photo", 0);
}
export function recordLocalVideo(scope: string, capture: PhoneCapture): LocalRecording {
  if (!(capture instanceof PhoneCapture) || !capture.ready || capture.width !== 720 || !safeScope(scope)) throw new Error("Die Kamera ist noch nicht bereit.");
  const mime = ["video/webm;codecs=vp9", "video/webm;codecs=vp8", "video/webm"].find((type) => typeof MediaRecorder !== "undefined" && MediaRecorder.isTypeSupported(type));
  if (!mime) throw new Error("Dieser FiveM-Browser unterstützt keine Videoaufnahme.");
  const recorder = new MediaRecorder(capture.video(), { mimeType: mime, videoBitsPerSecond: 2200000 });
  const chunks: Blob[] = []; let size = 0, cancelled = false, failed = false, end = 0;
  const started = performance.now(), thumb = capture.thumbnail();
  const stop = () => { if (recorder.state !== "inactive") { end = performance.now(); recorder.stop(); } };
  const finished = new Promise<GalleryInfo>((resolve, reject) => {
    const timer = window.setTimeout(stop, galleryLimits.seconds * 1000);
    recorder.ondataavailable = (event) => {
      size += event.data.size;
      if (size > galleryLimits.videoBytes) { failed = true; stop(); return; }
      if (event.data.size) chunks.push(event.data);
    };
    recorder.onerror = () => { failed = true; stop(); window.clearTimeout(timer); reject(new Error("Videoaufnahme fehlgeschlagen.")); };
    recorder.onstop = () => {
      window.clearTimeout(timer);
      if (failed || cancelled) { chunks.length = 0; reject(new Error(cancelled ? "Aufnahme verworfen." : "Videoaufnahme zu groß oder fehlgeschlagen.")); return; }
      const duration = Math.min(galleryLimits.seconds, ((end || performance.now()) - started) / 1000);
      const blob = new Blob(chunks, { type: mime }); chunks.length = 0;
      void thumb.then((image) => save(scope, blob, image, "video", duration)).then(resolve, reject);
    };
    try { recorder.start(500); } catch (error) { window.clearTimeout(timer); reject(error); }
  });
  return { finished, stop, cancel: () => { cancelled = true; stop(); } };
}
