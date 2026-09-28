import { isRecord } from "./nui";
export type OrganizationKind = "job" | "faction";
export type OrganizationGrade = {
  grade: number;
  name: string;
  label: string;
  salary: number;
};
export type Organization = {
  kind: OrganizationKind;
  name: string;
  label: string;
  grades: OrganizationGrade[];
  manage: boolean;
  own: boolean;
  duty: boolean;
  finance: boolean;
  balance?: number;
};
export type OrganizationMember = {
  token: string;
  name: string;
  grade: number;
  online: boolean;
  self: boolean;
};
export type OrganizationPayload = {
  admin: boolean;
  character: string;
  list: Organization[];
  selected: string;
  members: OrganizationMember[];
  candidates: { id: number; name: string }[];
  memberLimit: number;
};
const num = (v: unknown): v is number =>
  typeof v === "number" && Number.isSafeInteger(v) && v >= 0;
export function parseOrganizations(value: unknown): OrganizationPayload | null {
  if (
    !isRecord(value) ||
    typeof value.admin !== "boolean" ||
    typeof value.character !== "string" ||
    typeof value.selected !== "string" ||
    !num(value.memberLimit) ||
    !Array.isArray(value.list) ||
    value.list.length > 1000 ||
    !value.list.every(
      (org) =>
        isRecord(org) &&
        ["job", "faction"].includes(String(org.kind)) &&
        typeof org.name === "string" &&
        typeof org.label === "string" &&
        ["manage", "own", "duty", "finance"].every(
          (key) => typeof org[key] === "boolean",
        ) &&
        (org.balance === undefined || num(org.balance)) &&
        Array.isArray(org.grades) &&
        org.grades.every(
          (g) =>
            isRecord(g) &&
            num(g.grade) &&
            num(g.salary) &&
            typeof g.name === "string" &&
            typeof g.label === "string",
        ),
    ) ||
    !Array.isArray(value.members) ||
    value.members.length > 2000 ||
    !value.members.every(
      (m) =>
        isRecord(m) &&
        typeof m.token === "string" &&
        typeof m.name === "string" &&
        num(m.grade) &&
        typeof m.online === "boolean" &&
        typeof m.self === "boolean",
    ) ||
    !Array.isArray(value.candidates) ||
    value.candidates.length > 2000 ||
    !value.candidates.every(
      (c) => isRecord(c) && num(c.id) && typeof c.name === "string",
    )
  )
    return null;
  return value as OrganizationPayload;
}
export const organizationErrors: Record<string, string> = {
  forbidden: "Dafür fehlen dir die Rechte oder der nötige Rang.",
  target_unavailable:
    "Dieser Charakter ist nicht mehr verfügbar oder zu weit entfernt.",
  target_employed:
    "Der Charakter muss zuerst seinen bisherigen Beruf verlassen.",
  member_offline:
    "Jobänderungen sind hier nur bei verbundenen Charakteren möglich.",
  stale_members: "Die Mitgliederliste hat sich geändert. Bitte aktualisieren.",
  already_member: "Dieser Charakter ist bereits Mitglied.",
  already_exists: "Diese interne Kennung wird bereits verwendet.",
  membership_conflict:
    "Mitgliedschaft geändert oder Fraktionslimit erreicht. Bitte aktualisieren.",
  society_pending:
    "Das Gemeinschaftskonto wird beim nächsten Serverstart geladen.",
  insufficient_money: "Der verfügbare Betrag reicht nicht aus.",
  invalid_fields: "Bitte prüfe Kennung, Rang, Betrag und Bezeichnung.",
};
