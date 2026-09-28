import type { NativeItem, NativeKey, NativeMenuPayload } from "./nativeui";
const inspectHint = { keys: ["W", "A", "S", "D"], label: "Waffe begutachten", detail: "Halten zum Drehen · Loslassen zum Zurückfedern" };
const row = (
  id: string,
  label: string,
  detail: Partial<NativeItem> = {},
): NativeItem =>
  ({
    id,
    label,
    description: "",
    rightLabel: "",
    disabled: false,
    type: "action",
    ...detail,
  }) as NativeItem;
const menu = (
  subtitle: string,
  items: NativeItem[],
  theme: "mint" = "mint",
): NativeMenuPayload => ({
  title: "Los Santos",
  subtitle,
  items,
  theme,
  description: "",
  visibleRows: 7,
  selected: items.length ? 1 : 0,
  depth: 1,
  session: "preview",
  revision: 1,
});
export function nativePreview(): NativeMenuPayload {
  const view = new URLSearchParams(location.search).get("view");
  if (view === "garage") return menu("La Mesa · Parkservice", [
    row("asea", "Asea · RP520367", {rightLabel:"Ausparken",description:"Der Mitarbeiter fährt dein Fahrzeug zum Übergabeplatz. Blip bis zum Einsteigen."}),
    row("sultan", "Sultan · LS204811", {rightLabel:"Einparken",description:"Fahrzeug abstellen, aussteigen und dem Mitarbeiter übergeben."}),
  ]);
  if (view === "garage-dev") return garagePreview("root");
  if (new URLSearchParams(location.search).get("view") === "admin") {
    return { ...menu("LOS SANTOS · ADMIN", [
      row("money", "Geld vergeben", {type:"submenu",menu:"admin_money"}),
      row("items", "Items vergeben", {description:"Im Spiel öffnet sich die vorhandene Itemverwaltung."}),
      row("noclip", "Noclip umschalten", {rightLabel:"An / Aus",description:"Verwendet im Spiel den bestehenden ESX-Noclip."}),
      row("waypoint", "Zum Wegpunkt teleportieren", {description:"Zuerst einen Wegpunkt auf der Karte setzen."}),
      row("godmode", "Godmode", {type:"checkbox",checked:false}),
    ]), title:"Administration" };
  }
  if (new URLSearchParams(location.search).get("view") === "weaponshop") {
    return { ...menu("Ammu-Nation · Pillbox", [
      row("pistol", "Pistole", { hint: inspectHint, type: "submenu", menu: "ammu_pistol", rightLabel: "$2500", description: "W / A / S / D: begutachten · Enter: näher ansehen." }),
      row("rifle", "Karabiner", { hint: inspectHint, type: "submenu", menu: "ammu_rifle", rightLabel: "$12500", description: "W / A / S / D: begutachten · Enter: näher ansehen." }),
      row("payment", "Bezahlen mit", { type: "list", index: 1, options: [{ label: "Bargeld", value: "money" }, { label: "Bank", value: "bank" }] }),
      row("recover", "Offene Bestellung fortsetzen"),
    ]), title: "AMMU-NATION" };
  }
  return menu("INTERAKTIONSMENÜ", [
    row("action", "Aktion ausführen", {
      rightLabel: "0",
      description:
        "Enter löst einen Callback aus und aktualisiert diese Zeile.",
    }),
    row("gps", "Schnellnavigation", {
      type: "list",
      index: 1,
      options: [
        { label: "Keine", value: "none" },
        { label: "Flughafen", value: "airport" },
        { label: "Shop", value: "shop" },
      ],
      description: "Mit ← und → auswählen, mit Enter bestätigen.",
    }),
    row("notifications", "Benachrichtigungen", {
      type: "checkbox",
      checked: true,
      description: "Enter schaltet die Checkbox um.",
    }),
    row("settings", "Einstellungen", {
      type: "submenu",
      menu: "settings",
      description: "Untermenü mit Mint-Banner und weiterer Ebene.",
    }),
    row("dynamic", "Dynamische Liste", {
      type: "submenu",
      menu: "dynamic",
      description: "Einträge werden vor jedem Öffnen neu erzeugt.",
    }),
    row("locked", "Nicht verfügbar", {
      disabled: true,
      description: "Gesperrte Zeilen können nicht aktiviert werden.",
    }),
    row("reject", "Abgelehnte Änderung", {
      type: "checkbox",
      checked: false,
      description: "Der Callback lehnt ab. Der Wert bleibt unverändert.",
    }),
    row("replace", "Neues Hauptmenü öffnen", {
      description: "Ersetzt den bisherigen Menüstapel.",
    }),
    row("empty", "Leeres Menü", { type: "submenu", menu: "empty" }),
    row("close", "Schließen"),
  ]);
}
function garagePreview(section: string): NativeMenuPayload {
  const sub = (id: string, label: string) => row(id,label,{type:"submenu",menu:`garage_${id}`});
  const coords = () => ["X","Y","Z","Blickrichtung"].map((label,index)=>row(`axis_${index}`,label,{type:"list",index:2,options:[{label:"− 0,05",value:-1},{label:index===3?"90,000":"715,000",value:0},{label:"+ 0,05",value:1}],description:"Im Spiel: Pfeile für Feinschritte, Enter für exakte Eingabe."}));
  const rows = section === "root" ? [sub("edit","Garage hier erstellen"),sub("edit_existing","La Mesa · Parkservice")]
    : section === "edit" || section === "edit_existing" ? [row("name","Name",{rightLabel:"La Mesa · Parkservice"}),sub("npc","NPCs & Personaleingang"),sub("point","Interaktionspunkt"),sub("gate","Tor auswählen / testen"),sub("point","Verdeckter Fahrzeugplatz"),sub("parking","Übergabe-Parkplatz"),sub("outward","Fahrweg: Ausparken"),sub("inward","Fahrweg: Einparken"),row("save","Garage speichern",{description:"Vorschau. Dauerhaftes Speichern erfolgt im Spiel mit Adminrechten."})]
    : section === "npc" ? [row("model","Empfangsmodell",{type:"list",index:1,options:[{label:"s_m_y_valet_01",value:1},{label:"s_m_m_autoshop_01",value:2}]}),sub("point","Empfang: Position / Blickrichtung"),sub("staff","Verdeckter Personaleingang"),sub("staffPath","Laufweg bearbeiten"),row("greet","Begrüßung testen",{description:"Im Spiel: gemeinsames NPC-System mit Blickkontakt, Geste und Sprache."})]
    : section === "gate" ? [row("pick","Vorhandenes Tor anvisieren"),row("model","Modell / Hash",{rightLabel:"prop_id2_11_gdoor"}),sub("point","Torposition fein justieren"),row("open","Tor öffnen / schließen",{type:"checkbox",checked:false}),row("test","Torstatus prüfen",{description:"Im Spiel werden Objekt, geladene Physik und tatsächliche Torstellung geprüft."})]
    : ["outward","inward","staffPath"].includes(section) ? [row("add","Wegpunkt hier hinzufügen"),sub("point","Punkt 1"),sub("point_second","Punkt 2")]
    : [row("here","An meine Position setzen"),row("surface","Boden anvisieren"),...coords()];
  // Unique row IDs even when several coordinate editors share the preview page.
  return {...menu(section==="root"?"DEV · GARAGENVERWALTUNG":"DEV · LA MESA",rows.map((item,index)=>({...item,id:`${item.id}_${index}`}))),title:"GARAGEN"};
}
export function createNativePreviewController() {
  let stack = [nativePreview()];
  let revision = 1;
  return (key: NativeKey): NativeMenuPayload | null => {
    let current = stack[stack.length - 1];
    if (!current) return null;
    current = structuredClone(current);
    stack[stack.length - 1] = current;
    const item = current.items[current.selected - 1];
    if (key === "back") stack.pop();
    else if (key === "up" || key === "down") {
      if (current.items.length)
        current.selected =
          ((current.selected -
            1 +
            (key === "up" ? -1 : 1) +
            current.items.length) %
            current.items.length) +
          1;
    } else if (item && !item.disabled) {
      if (item.type === "list" && (key === "left" || key === "right"))
        item.index =
          ((item.index - 1 + (key === "left" ? -1 : 1) + item.options.length) %
            item.options.length) +
          1;
      else if (key === "enter") {
        if (item.type === "checkbox" && item.id !== "reject")
          item.checked = !item.checked;
        else if (item.type === "submenu") {
          if (item.menu.startsWith("garage_")) {
            stack.push(garagePreview(item.menu.slice(7)));
            return {...stack[stack.length-1],depth:stack.length,revision:++revision};
          }
          if (item.menu === "admin_money") {
            stack.push({ ...menu("GELDVERGABE", [
              row("target", "Empfänger", {rightLabel:"Mich · ID 1"}),
              row("account", "Konto", {type:"list",index:1,options:[{label:"Bargeld",value:"money"},{label:"Bankkonto",value:"bank"}]}),
              row("amount", "Betrag", {rightLabel:"$ 1000"}),
              row("give", "Geld vergeben", {description:"Nur Browservorschau; echte Geldvergabe wird ausschließlich serverseitig geprüft."}),
            ]), title:"Administration" });
            return { ...stack[stack.length - 1], depth:stack.length, revision:++revision };
          }
          if (item.menu === "ammu_pistol" || item.menu === "ammu_rifle") {
            const rifle = item.menu === "ammu_rifle";
            stack.push({ ...menu(rifle ? "Karabiner" : "Pistole", [
              row("buy", "Waffe kaufen", { rightLabel: rifle ? "$12500" : "$2500", description: "Browservorschau: keine echten Käufe oder 3D-Kameras." }),
              row("ammo", rifle ? "Gewehrmunition" : "Pistolenmunition", { description: `${rifle ? 30 : 12} Patronen pro Magazin / Stapel. Preis pro Magazin.`, type: "list", index: 1, options: Array.from({ length: 20 }, (_, i) => ({ label: `${i + 1} Mag. · $${(i + 1) * (rifle ? 450 : 96)}`, value: i + 1 })) }),
              row("light", rifle ? "Gewehrlampe" : "Pistolenlampe", { rightLabel: rifle ? "$400" : "$300", description: "Im Spiel an der Preview-Waffe sichtbar. Nach Kauf im Inventar montieren." }),
              row("attachment", rifle ? "Karabiner-Zielfernrohr" : "Pistolen-Schalldämpfer", { rightLabel: rifle ? "$1200" : "$900" }),
            ].map((item) => ({ ...item, hint: inspectHint }))), title: "AMMU-NATION" });
            return { ...stack[stack.length - 1], depth: stack.length, revision: ++revision };
          }
          const next =
            item.menu === "settings"
              ? menu(
                  "EINSTELLUNGEN",
                  [
                    row("volume", "Lautstärke", {
                      type: "list",
                      index: 2,
                      options: [
                        { label: "Leise", value: 25 },
                        { label: "Normal", value: 50 },
                        { label: "Laut", value: 100 },
                      ],
                    }),
                    row("nested", "Weitere Optionen", {
                      type: "submenu",
                      menu: "nested",
                    }),
                  ],
                  "mint",
                )
              : item.menu === "nested"
                ? menu("WEITERE OPTIONEN", [
                    row("info", "Verschachteltes Untermenü"),
                    row("empty", "Leeres Menü testen", {
                      type: "submenu",
                      menu: "empty",
                    }),
                  ])
                : item.menu === "dynamic"
                  ? menu(
                      "DYNAMISCHE DATEN",
                      Array.from({ length: 4 }, (_, i) =>
                        row(`entry_${i + 1}`, `Eintrag ${i + 1}`, {
                          rightLabel: new Date().toLocaleTimeString("de-DE", {
                            hour: "2-digit",
                            minute: "2-digit",
                          }),
                        }),
                      ),
                    )
                  : {
                      ...menu("LEERES MENÜ", []),
                      description:
                        "Noch keine Einträge. Mit Zurück kommst du wieder ins Hauptmenü.",
                    };
          stack.push(next);
        } else if (item.id === "action") {
          item.rightLabel = String(Number(item.rightLabel) + 1);
          item.description = `Callback ausgeführt: ${item.rightLabel} Mal.`;
        } else if (item.id === "replace")
          stack = [
            {
              ...menu("NEUES HAUPTMENÜ", [row("restart", "Zum Testmenü")]),
              description: "Zurück schließt dieses neue Hauptmenü.",
            },
          ];
        else if (item.id === "restart") stack = [nativePreview()];
        else if (item.id === "close") stack = [];
      }
    }
    const result = stack[stack.length - 1];
    if (!result) return null;
    return { ...result, depth: stack.length, revision: ++revision };
  };
}
