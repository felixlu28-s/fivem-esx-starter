import { parseHud, type HudData } from "./hud";
import { parsePhone, type PhonePayload } from "./phone";
import { parsePhoneReply, parsePhoneEvent, type PhoneReply, type PhoneEvent } from "./phoneData";
import { parseOrganizations, type OrganizationPayload } from "./organizations";
import { parseCommerce, type CommercePayload } from "./commerce";
import { parseBanking, parseBankRecipient, type BankingPayload, type BankRecipient } from "./banking";
import { parseNativeMenu, type NativeMenuPayload } from "./nativeui";
import {
  parseInventory,
  isInventoryRecipients,
  type InventoryPayload,
  type InventoryRecipient,
} from "./inventory";
declare global {
  interface Window {
    GetParentResourceName?: () => string;
  }
}
export type Skin = Record<string, number>;
// Separate FiveM loadingScreen frame, delivered by SendLoadingScreenMessage.
// Kept out of the gameplay union: it cannot open/close an in-game menu.
export type LoadingScreenMessage = {
  action: "ui:loading";
  data: { phase: "session" | "scene" | "exiting" };
};
export type FieldGroup =
  | "heritage"
  | "face"
  | "hair"
  | "skin"
  | "clothes"
  | "accessories";
export type AppearanceField = {
  key: string;
  label: string;
  group: FieldGroup;
  min: number;
  max: number;
  color: boolean;
  section?: string;
  options?: { value: number; label: string }[];
};
export type Character = {
  slot: number;
  firstname: string;
  lastname: string;
  dateofbirth: string;
  gender: "m" | "f";
  height: number;
  job: string;
  skin: Skin;
};
export type CharacterPayload = {
  mode: "selection" | "creator" | "loading" | "error";
  slots: number;
  characters: Character[];
  skin: Skin;
  fields: AppearanceField[];
  minAge: number;
  maxAge: number;
  error?: string;
};
export type NuiOpenPayload = {
  toggleKey?: string;
  view: string;
  payload: Record<string, unknown>;
  locked: boolean;
};
export type NuiMessage =
  | { action: "ui:phoneApp"; data: PhoneEvent }
  | { action: "ui:phone"; data: PhonePayload | false }
  | { action: "ui:hud"; data: HudData | false }
  | { action: "ui:open"; data: NuiOpenPayload }
  | { action: "ui:interaction"; data: InteractionHint | false }
  | { action: "ui:close" };
export type InteractionHint = {
  label: string;
  verb: string;
  key: string;
  icon: "shop" | "craft" | "bag" | "bank";
};
export function parseInteraction(v: unknown): InteractionHint | null {
  if (!isRecord(v) || typeof v.label !== "string" || !v.label || v.label.length > 160
    || typeof v.verb !== "string" || !v.verb || v.verb.length > 80
    || typeof v.key !== "string" || v.key.length > 32
    || (v.icon !== "shop" && v.icon !== "craft" && v.icon !== "bag" && v.icon !== "bank")) return null;
  return { label: v.label, verb: v.verb, key: v.key, icon: v.icon };
}
export type ActionResult = {
  banking?: BankingPayload;
  bankRecipient?: BankRecipient;
  phone?: PhoneReply;
  ok: boolean;
  error?: string;
  skin?: Skin;
  fields?: AppearanceField[];
  bindings?: BindingPayload;
  profile?: ProfilePayload;
  organizations?: OrganizationPayload;
  inventory?: InventoryPayload;
  recipients?: InventoryRecipient[];
  commerce?: CommercePayload;
  nativeui?: NativeMenuPayload;
  closed?: boolean;
};
export type InputKey = {
  id: string;
  label: string;
  row: number;
  width: number;
  reserved: boolean;
};
export type InputAction = {
  id: string;
  label: string;
  category: string;
  description: string;
  defaultKey: string;
  key: string;
  context: string;
};
export type BindingPayload = {
  revision: number;
  keys: InputKey[];
  actions: InputAction[];
};
export type ProfilePayload = {
  name: string;
  firstname: string;
  lastname: string;
  birthdate: string;
  height: number;
  job: string;
  grade: string;
  cash: number;
  bank: number;
  level: number;
  runningMeters: number;
  trainingSeconds: number;
  metersPerLevel: number;
  maxLevel: number;
  stamina: number;
};
export const isBrowser = (): boolean =>
  typeof window.GetParentResourceName !== "function";
export const isRecord = (v: unknown): v is Record<string, unknown> =>
  !!v && typeof v === "object" && !Array.isArray(v);
const integer = (v: unknown): v is number =>
  typeof v === "number" && Number.isSafeInteger(v);
export function parseBindings(v: unknown): BindingPayload | null {
  if (
    !isRecord(v) ||
    !integer(v.revision) ||
    !Array.isArray(v.keys) ||
    !Array.isArray(v.actions) ||
    v.keys.length > 200 ||
    v.actions.length > 500 ||
    !v.keys.every(
      (k) =>
        isRecord(k) &&
        typeof k.id === "string" &&
        typeof k.label === "string" &&
        integer(k.row) &&
        k.row >= 0 &&
        k.row <= 8 &&
        typeof k.width === "number" &&
        k.width > 0 &&
        k.width <= 10 &&
        typeof k.reserved === "boolean",
    ) ||
    !v.actions.every(
      (a) =>
        isRecord(a) &&
        [
          "id",
          "label",
          "category",
          "description",
          "defaultKey",
          "key",
          "context",
        ].every((k) => typeof a[k] === "string"),
    )
  )
    return null;
  const parsed = v as BindingPayload;
  const ids = new Set(parsed.keys.map((k) => k.id));
  if (
    ids.size !== parsed.keys.length ||
    new Set(parsed.actions.map((a) => a.id)).size !== parsed.actions.length ||
    !parsed.actions.every(
      (a) => ids.has(a.defaultKey) && (a.key === "" || ids.has(a.key)),
    )
  )
    return null;
  return parsed;
}
export function parseProfile(v: unknown): ProfilePayload | null {
  if (
    !isRecord(v) ||
    !["name", "firstname", "lastname", "birthdate", "job", "grade"].every(
      (k) => typeof v[k] === "string",
    ) ||
    ![
      "height",
      "cash",
      "bank",
      "level",
      "runningMeters",
      "trainingSeconds",
      "metersPerLevel",
      "maxLevel",
      "stamina",
    ].every((k) => typeof v[k] === "number" && Number.isFinite(v[k])) ||
    Number(v.metersPerLevel) <= 0 ||
    Number(v.level) < 1 ||
    Number(v.maxLevel) < 1
  )
    return null;
  return v as ProfilePayload;
}
export const isSkin = (v: unknown): v is Skin =>
  isRecord(v) &&
  Object.keys(v).length <= 150 &&
  Object.entries(v).every(
    ([k, n]) =>
      /^[a-z][a-z0-9_]*$/.test(k) && integer(n) && n >= -10 && n <= 1000,
  );
const groups: string[] = [
  "heritage",
  "face",
  "hair",
  "skin",
  "clothes",
  "accessories",
];
export const isFields = (v: unknown): v is AppearanceField[] =>
  Array.isArray(v) &&
  v.length <= 150 &&
  v.every(
    (f) =>
      isRecord(f) &&
      typeof f.key === "string" &&
      typeof f.label === "string" &&
      typeof f.group === "string" &&
      groups.includes(f.group) &&
      integer(f.min) &&
      integer(f.max) &&
      f.max >= f.min &&
      typeof f.color === "boolean" &&
      (f.section === undefined || typeof f.section === "string") &&
      (f.options === undefined ||
        (Array.isArray(f.options) &&
          f.options.length <= 100 &&
          f.options.every(
            (o) =>
              isRecord(o) &&
              integer(o.value) &&
              o.value >= Number(f.min) &&
              o.value <= Number(f.max) &&
              typeof o.label === "string",
          ))),
  );
const isCharacter = (v: unknown): v is Character =>
  isRecord(v) &&
  integer(v.slot) &&
  v.slot >= 1 &&
  v.slot <= 8 &&
  typeof v.firstname === "string" &&
  typeof v.lastname === "string" &&
  typeof v.dateofbirth === "string" &&
  (v.gender === "m" || v.gender === "f") &&
  integer(v.height) &&
  typeof v.job === "string" &&
  isSkin(v.skin);
export const parseCharacters = (v: unknown): CharacterPayload | null => {
  if (
    !isRecord(v) ||
    !["selection", "creator", "loading", "error"].includes(String(v.mode)) ||
    !integer(v.slots) ||
    v.slots < 1 ||
    v.slots > 8 ||
    !Array.isArray(v.characters) ||
    !v.characters.every(isCharacter) ||
    !isSkin(v.skin) ||
    !isFields(v.fields) ||
    !integer(v.minAge) ||
    !integer(v.maxAge) ||
    (v.error !== undefined && typeof v.error !== "string")
  )
    return null;
  return v as CharacterPayload;
};
export const isNuiMessage = (v: unknown): v is NuiMessage => {
  if (!isRecord(v)) return false;
  if (v.action === "ui:phoneApp") return parsePhoneEvent(v.data) !== null;
  if (v.action === "ui:close") return true;
  if (v.action === "ui:phone") return v.data === false || parsePhone(v.data) !== null;
  if (v.action === "ui:hud") return v.data === false || parseHud(v.data) !== null;
  if (v.action === "ui:interaction") return v.data === false || parseInteraction(v.data) !== null;
  return (
    v.action === "ui:open" &&
    isRecord(v.data) &&
    typeof v.data.view === "string" &&
    isRecord(v.data.payload) &&
    typeof v.data.locked === "boolean" &&
    (v.data.toggleKey === undefined || (typeof v.data.toggleKey === "string" && v.data.toggleKey.length <= 32)) &&
    (v.data.view !== "nativeui" || parseNativeMenu(v.data.payload) !== null)
  );
};
export async function fetchNui(
  event: string,
  data: Record<string, unknown> = {},
): Promise<ActionResult> {
  if (isBrowser()) return { ok: true };
  const controller = new AbortController();
  const timeout = window.setTimeout(() => controller.abort(), 22000);
  try {
    const response = await fetch(
      `https://${window.GetParentResourceName?.()}/${event}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        body: JSON.stringify(data),
        signal: controller.signal,
      },
    );
    if (!response.ok)
      throw new Error("Verbindung zur Spieloberfläche unterbrochen.");
    const result: unknown = await response.json();
    if (
      !isRecord(result) ||
      typeof result.ok !== "boolean" ||
      (result.phone !== undefined && !parsePhoneReply(result.phone)) ||
      (result.error !== undefined && typeof result.error !== "string") ||
      (result.skin !== undefined && !isSkin(result.skin)) ||
      (result.fields !== undefined && !isFields(result.fields)) ||
      (result.bindings !== undefined && !parseBindings(result.bindings)) ||
      (result.profile !== undefined && !parseProfile(result.profile)) ||
      (result.inventory !== undefined && !parseInventory(result.inventory)) ||
      (result.commerce !== undefined && !parseCommerce(result.commerce)) ||
      (result.banking !== undefined && !parseBanking(result.banking)) ||
      (result.bankRecipient !== undefined && !parseBankRecipient(result.bankRecipient)) ||
      (result.nativeui !== undefined && !parseNativeMenu(result.nativeui)) ||
      (result.closed !== undefined && typeof result.closed !== "boolean") ||
      (result.recipients !== undefined &&
        !isInventoryRecipients(result.recipients)) ||
      (result.organizations !== undefined &&
        !parseOrganizations(result.organizations))
    )
      throw new Error("Ungültige Antwort vom Spiel.");
    return result as ActionResult;
  } finally {
    window.clearTimeout(timeout);
  }
}
const errorLabels: Record<string, string> = {
  stale_bindings:
    "Die Belegung wurde zwischenzeitlich geändert. Bitte wähle erneut.",
  binding_conflict: "Diese Taste ist inzwischen belegt. Bitte wähle erneut.",
  invalid_binding: "Diese Taste kann nicht belegt werden.",
  player_unavailable:
    "Dein Charakter ist gerade nicht verfügbar. Versuche es gleich erneut.",
  invalid_fields:
    "Bitte prüfe Namen, ein gültiges Geburtsdatum und deine Größe.",
  character_limit: "Alle erlaubten Charakterplätze sind bereits belegt.",
  server_starting:
    "Der Server bereitet deine Einreise vor. Versuche es gleich erneut.",
  database_error:
    "Deine Daten konnten gerade nicht gespeichert werden. Bitte erneut versuchen.",
  account_in_use: "Dieser Account ist bereits verbunden.",
  appearance_failed:
    "Das Aussehen konnte nicht geladen werden. Bitte erneut versuchen.",
  preview_unavailable:
    "Die Vorschauumgebung konnte nicht geladen werden. Bitte erneut versuchen.",
  configuration_error:
    "Die Charakterverwaltung benötigt einen vollständigen Serverneustart.",
  login_failed:
    "Dein Charakter konnte nicht geladen werden. Bitte neu verbinden.",
  invalid_state: "Dieser Schritt ist gerade nicht verfügbar.",
  session_expired: "Deine Sitzung ist abgelaufen. Bitte neu verbinden.",
  not_found: "Dieser Charakter ist nicht verfügbar.",
  busy: "Deine letzte Aktion wird noch verarbeitet.",
  rate_limited: "Einen Moment bitte, versuche es gleich erneut.",
  timeout:
    "Die Antwort dauert zu lange. Bitte prüfe vor einem neuen Versuch die Charakterliste.",
};
export const errorLabel = (code?: string): string =>
  code
    ? (errorLabels[code] ??
      "Die Aktion ist fehlgeschlagen. Bitte erneut versuchen.")
    : "Die Aktion ist fehlgeschlagen.";
