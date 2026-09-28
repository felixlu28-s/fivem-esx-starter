import { useEffect, useRef, useState } from "react";
import { useMenuToggle } from "./lib/menuToggle";
import { UiIcon } from "./components/UiIcon";
import {
  fetchNui,
  isBrowser,
  isNuiMessage,
  parseCharacters,
  parseBindings,
  parseProfile,
  parseInteraction,
  type InteractionHint,
  type NuiOpenPayload,
} from "./lib/nui";
import { preview } from "./lib/preview";
import { Characters } from "./views/Characters";
import { Settings } from "./views/Settings";
import { Me } from "./views/Me";
import { Organizations } from "./views/Organizations";
import { organizationPreview } from "./lib/organizationPreview";
import { parseOrganizations } from "./lib/organizations";
import { loadBindingPreview, profilePreview } from "./lib/menuPreview";
import { Inventory } from "./views/Inventory";
import { inventoryPreview } from "./lib/inventoryPreview";
import { parseInventory } from "./lib/inventory";
import { parseCommerce } from "./lib/commerce";
import { commercePreview } from "./lib/commercePreview";
import { CommerceView } from "./views/Commerce";
import { ClothingView } from "./views/Clothing";
import { clothingPreview } from "./lib/clothingPreview";
import { BankingView } from "./views/Banking";
import { bankPreview, parseBanking } from "./lib/banking";
import { NativeMenu } from "./views/NativeMenu";
import { parseNativeMenu } from "./lib/nativeui";
import { nativePreview } from "./lib/nativePreview";
import { InteractionPrompt } from "./components/InteractionPrompt";
import { GameHud } from "./components/GameHud";
import { Phone } from "./views/Phone";
import { hudPreview, parseHud, type HudData } from "./lib/hud";

function browserScreen(): NuiOpenPayload {
  const view = new URLSearchParams(location.search).get("view");
  if (view === 'banking' || view === 'atm-maze' || view === 'atm-liberty') return {view:'banking',locked:false,payload:{...bankPreview(view==='atm-maze'?'maze':view==='atm-liberty'?'liberty':'fleeca')}};
  if (view === "clothing") return { view, locked: false, payload: { ...clothingPreview() } };
  if (view === "phone") return { view, locked: true, payload: {} };
  const keyFor = (action: string) => loadBindingPreview().actions.find((a) => a.id === action)?.key;
  if (view === "hud") return { view, locked: false, payload: { ...hudPreview } };
  if (view === "interaction") return { view, locked: false, payload: {
    label: "24/7 · Strawberry", verb: "Einkaufen", key: "E", icon: "shop",
  } };
  if (view === "nativeui" || view === "weaponshop" || view === "admin" || view === "garage" || view === "garage-dev")
    return { view: "nativeui", payload: { ...nativePreview() }, locked: true, toggleKey: view === "admin" ? keyFor("rp_admin:open") : undefined };
  if (view === "shop" || view === "crafting")
    return {
      view: "commerce",
      toggleKey: keyFor("rp_commerce:interact"),
      payload: { ...commercePreview(view) },
      locked: false,
    };
  if (view === "inventory")
    return { view, payload: { ...inventoryPreview() }, locked: false, toggleKey: keyFor("rp_inventory:open") };
  if (view === "organizations")
    return { view, payload: { ...organizationPreview }, locked: false };
  if (view === "settings") {
    return { view, payload: { ...loadBindingPreview() }, locked: true };
  }
  if (view === "me")
    return { view, payload: { ...profilePreview }, locked: false, toggleKey: keyFor("rp_player:me") };
  if (view === "welcome")
    return {
      view,
      payload: {
        title: "Willkommen in Los Santos",
        message: "Eine gemeinsame Oberfläche für dein Rollenspiel.",
      },
      locked: false,
    };
  if (view === "creator" || view === "loading" || view === "error")
    return {
      view: "characters",
      locked: true,
      payload: {
        ...preview,
        mode: view,
        ...(view === "error" ? { error: "login_failed" } : {}),
      },
    };
  return { view: "characters", payload: { ...preview }, locked: true };
}

export function App() {
  return <><GameApp /><Phone /></>;
}
function GameApp() {
  const closing = useRef(false);
  const [hud, setHud] = useState<HudData | null>(null);
  const [interaction, setInteraction] = useState<InteractionHint | null>(null);
  const [screen, setScreen] = useState<NuiOpenPayload | null>(
    isBrowser() ? browserScreen() : null,
  );
  useEffect(() => {
    if (isBrowser() && window.parent !== window) {
      window.parent.postMessage(
        { action: "studio:visibility", visible: screen !== null },
        window.location.origin,
      );
    }
  }, [screen]);
  useEffect(() => {
    const listener = (event: MessageEvent<unknown>) => {
      if (!isNuiMessage(event.data)) return;
      if (event.data.action === "ui:phone" || event.data.action === "ui:phoneApp") return;
      if (event.data.action === "ui:hud") {
        setHud(event.data.data || null);
        return;
      }
      if (event.data.action === "ui:interaction") {
        setInteraction(event.data.data || null);
        return;
      }
      setScreen(event.data.action === "ui:close" ? null : event.data.data);
    };
    window.addEventListener("message", listener);
    void fetchNui("ui:ready").catch(() => undefined);
    return () => window.removeEventListener("message", listener);
  }, []);
  useEffect(() => {
    const listener = (event: KeyboardEvent) => {
      if (
        event.key === "Escape" &&
        !event.repeat &&
        !event.defaultPrevented &&
        screen &&
        !screen.locked
      )
        void close();
    };
    window.addEventListener("keydown", listener);
    return () => window.removeEventListener("keydown", listener);
  }, [screen]);
  const close = async () => {
    if (closing.current) return;
    closing.current = true;
    try {
      if ((await fetchNui("ui:close")).ok) setScreen(null);
    } catch {
      /* Keep focus until game acknowledges. */
    } finally {
      closing.current = false;
    }
  };
  useMenuToggle(screen?.toggleKey, () => void close(), !screen || screen.locked);
  if (!screen) return <>{hud && <GameHud data={hud} />}<InteractionPrompt data={interaction} /></>;
  if (screen.view === "phone") return <>{hud && <GameHud data={hud} />}</>;
  if (screen.view === "hud") {
    const data = parseHud(screen.payload);
    return data ? <GameHud data={data} /> : null;
  }
  if (screen.view === "interaction") {
    const data = parseInteraction(screen.payload);
    return data ? <InteractionPrompt data={data} /> : null;
  }
  if (screen.view === "nativeui") {
    const data = parseNativeMenu(screen.payload);
    if (data)
      return <>{hud && <GameHud data={hud} />}<NativeMenu data={data} toggleKey={screen.toggleKey} onClosed={() => setScreen(null)} /></>;
  }
  if (screen.view === "commerce") {
    const data = parseCommerce(screen.payload);
    if (data) return <CommerceView data={data} onClose={() => void close()} />;
  }
  if (screen.view === "clothing") {
    const data = parseCommerce(screen.payload);
    if (data?.clothing && data.offers.every(offer => offer.garment)) return <ClothingView key={data.session} data={data} onClose={() => void close()} />;
  }
  if (screen.view === 'banking') {
    const data = parseBanking(screen.payload);
    if (data) return <BankingView key={data.session} data={data} onClose={() => void close()} />;
  }
  if (screen.view === "inventory") {
    const data = parseInventory(screen.payload);
    if (data) return <Inventory key={data.session} data={data} onClose={() => void close()} />;
  }
  if (screen.view === "organizations") {
    const data = parseOrganizations(screen.payload);
    if (data) return <Organizations data={data} onClose={() => void close()} />;
  }
  if (screen.view === "settings") {
    const data = parseBindings(screen.payload);
    if (data) return <Settings data={data} onClosed={() => setScreen(null)} />;
  }
  if (screen.view === "me") {
    const data = parseProfile(screen.payload);
    if (data)
      return (
        <Me
          data={data}
          onClose={() => void close()}
          onOrganizations={() =>
            setScreen({
              view: "organizations",
              payload: { ...organizationPreview },
              locked: false,
            })
          }
        />
      );
  }
  if (screen.view === "characters") {
    const data = parseCharacters(screen.payload);
    if (!data)
      return (
        <main className="fallback">
          <section>
            <div className="ui-title">
              <UiIcon name="warning" />
              <h1>Einreise unterbrochen</h1>
            </div>
            <p>
              Die Charakterdaten konnten nicht gelesen werden. Bitte neu
              verbinden.
            </p>
          </section>
        </main>
      );
    return <Characters data={data} />;
  }
  return (
    <main className="fallback">
      <section>
        <p className="eyebrow">LOS SANTOS</p>
        <div className="ui-title">
          <UiIcon name="message" />
          <h1>{String(screen.payload.title ?? screen.view)}</h1>
        </div>
        <p>{String(screen.payload.message ?? "")}</p>
        <button className="ui-inline" onClick={() => void close()}>
          Schließen <UiIcon name="close" />
        </button>
      </section>
    </main>
  );
}
