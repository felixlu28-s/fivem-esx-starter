// Project branding and editorial content. No external downloads during joining.
export const loadingConfig = {
  brand: "LOS SANTOS",
  subtitle: "ROLEPLAY",
  headline: ["Deine Stadt.", "Deine Geschichte."],
  introduction: "Ein neuer Anfang. Und eine Stadt voller Möglichkeiten.",
  artwork: "./loading/los-santos-arrival.png",
  tipIntervalMs: 10000,
  tips: [
    { title: "Alles beginnt mit dir.", text: "Erstelle deinen Charakter und mach Los Santos zu deiner Geschichte." },
    { title: "Dein Alltag. Deine Regeln.", text: "Kleidung, Einkäufe und persönliche Gegenstände begleiten dich durch die Stadt." },
    { title: "Bleib in Verbindung.", text: "Kontakte, Nachrichten und gemeinsame Momente – dein iFruit ist immer dabei." },
    { title: "Mach es dir passend.", text: "Deine eigenen Tastenbelegungen kannst du in den Einstellungen anpassen." },
  ],
} as const;
