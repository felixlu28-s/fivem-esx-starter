import { isFields, type ActionResult, type CharacterPayload, type Skin } from "./nui";
import catalogs from "./appearance-preview.json";

function catalog(sex: number) {
  const entry = catalogs[sex === 1 ? 1 : 0];
  if (!isFields(entry.fields)) throw new Error("Invalid appearance preview");
  return { ...entry, fields: entry.fields };
}
let skin: Skin = { ...catalog(0).skin };
export function previewChange(data: Record<string, unknown>): ActionResult {
  if (typeof data.key !== "string" || typeof data.value !== "number") return { ok: false, error: "invalid_fields" };
  if (data.key === "sex") skin = { ...catalog(data.value).skin };
  else {
    skin = { ...skin, [data.key]: data.value };
    if (data.key.endsWith("_1")) skin[data.key.replace(/_1$/, "_2")] = 0;
    if (data.key === "torso_1") {
      const top = Object.values(catalog(skin.sex).tops).find(item => item.value === data.value);
      if (top) Object.assign(skin, top.skin);
    }
  }
  return { ok: true, skin: { ...skin }, fields: catalog(skin.sex).fields };
}
export const preview: CharacterPayload = {
  mode: "selection",
  slots: 2,
  fields: catalog(0).fields,
  skin: { ...skin },
  minAge: 18,
  maxAge: 100,
  characters: [
    {
      slot: 1, firstname: "Alex", lastname: "Morgan", dateofbirth: "1998-06-14",
      gender: "m", height: 182, job: "Bürger", skin: { ...skin },
    },
  ],
};
