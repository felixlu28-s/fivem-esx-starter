import type { OrganizationPayload, OrganizationGrade } from "./organizations";
const grades: OrganizationGrade[] = [
  { grade: 0, name: "member", label: "Mitglied", salary: 300 },
  { grade: 1, name: "officer", label: "Stellvertretung", salary: 600 },
  { grade: 2, name: "boss", label: "Leitung", salary: 1000 },
];
export const organizationPreview: OrganizationPayload = {
  admin: true,
  character: "Alex Morgan",
  selected: "job:police",
  memberLimit: 200,
  list: [
    {
      kind: "job",
      name: "police",
      label: "Los Santos Police Department",
      grades,
      manage: true,
      own: true,
      duty: true,
      balance: 48500,
      finance: true,
    },
    {
      kind: "job",
      name: "mechanic",
      label: "Los Santos Customs",
      grades,
      manage: true,
      own: false,
      duty: false,
      balance: 16800,
      finance: false,
    },
    {
      kind: "faction",
      name: "lost",
      label: "The Lost MC",
      grades: grades.map((g) => ({ ...g, salary: 0 })),
      manage: true,
      own: false,
      duty: false,
      finance: false,
    },
  ],
  members: [
    { token: "demo1", name: "Alex Morgan", grade: 2, online: true, self: true },
    {
      token: "demo2",
      name: "Jamie Parker",
      grade: 0,
      online: true,
      self: false,
    },
    {
      token: "demo3",
      name: "Sam Rivera",
      grade: 1,
      online: false,
      self: false,
    },
  ],
  candidates: [
    { id: 12, name: "Taylor Brooks" },
    { id: 27, name: "Robin Hayes" },
  ],
};
export function organizationDemo(
  current: OrganizationPayload,
  input: Record<string, unknown>,
): OrganizationPayload {
  const next = structuredClone(current);
  const name = String(input.name),
    kind = input.kind === "faction" ? "faction" : "job";
  const key = `${kind}:${name}`;
  let org = next.list.find((o) => o.kind === kind && o.name === name);
  if (input.action === "create") {
    org = {
      kind,
      name,
      label: String(input.label),
      grades: structuredClone(grades),
      manage: true,
      own: false,
      duty: false,
      finance: false,
    };
    next.list.push(org);
    next.members = [];
  }
  if (!org) return next;
  if (next.selected !== key) next.members = [];
  next.selected = key;
  if (input.action === "duty") org.duty = input.duty === true;
  if (input.action === "rename") org.label = String(input.label);
  if (input.action === "deposit")
    org.balance = (org.balance ?? 0) + Number(input.amount);
  if (input.action === "withdraw")
    org.balance = Math.max(0, (org.balance ?? 0) - Number(input.amount));
  if (input.action === "fire")
    next.members = next.members.filter((m) => m.token !== input.member);
  if (input.action === "promote")
    next.members = next.members.map((m) =>
      m.token === input.member ? { ...m, grade: Number(input.grade) } : m,
    );
  if (input.action === "hire")
    next.members.push({
      token: `demo${Date.now()}`,
      name:
        next.candidates.find((c) => c.id === input.target)?.name ??
        "Neues Mitglied",
      grade: Number(input.grade),
      online: true,
      self: false,
    });
  if (input.action === "grade")
    org.grades = org.grades.map((g) =>
      g.grade === input.grade
        ? { ...g, label: String(input.label), salary: Number(input.salary) }
        : g,
    );
  if (input.action === "addGrade")
    org.grades.push({
      grade: Number(input.grade),
      name: String(input.rankName),
      label: String(input.label),
      salary: Number(input.salary),
    });
  return next;
}
