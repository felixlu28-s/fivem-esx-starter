import type { HudData } from "../lib/hud";
import { UiIcon } from "./UiIcon";
import "../hud.css";

const digits = new Intl.NumberFormat("de-DE", { maximumFractionDigits: 1 });
export function GameHud({ data }: { data: HudData }) {
  const status = !data.connected ? "Offline" : data.talking ? "Spricht" : "Bereit";
  return (
    <aside className="game-hud" aria-label="Spielstatus" style={{
      top: `calc(${data.inset * 100}vh + 1rem)`, right: `calc(${data.inset * 100}vw + 1rem)`,
    }}>
      <div className="hud-cash" aria-label={`Bargeld: ${data.cash === false ? "unbekannt" : digits.format(data.cash) + " Dollar"}`}>
        <span className="hud-caption"><UiIcon name="wallet" />Bargeld</span>
        <strong>{data.cash === false ? "—" : <><small>$</small> {digits.format(data.cash)}</>}</strong>
      </div>
      <div className="hud-details">
      <div className="hud-meta">
        <span aria-label={`Spieler online: ${data.players === false ? "unbekannt" : data.players}`}>
          <UiIcon name="team" /><b>{data.players === false ? "—" : digits.format(data.players)}</b> online
        </span>
        <span className="hud-id" aria-label={`Deine Server-ID: ${data.id}`}>ID <b>{data.id}</b></span>
      </div>
      <div className={`hud-voice${data.talking ? " is-talking" : ""}${!data.connected ? " is-offline" : ""}`}>
        <UiIcon name={data.connected ? "microphone" : "micOff"} />
        <span className="hud-range" aria-label={`Sprachreichweite: ${data.range === false ? "unbekannt" : digits.format(data.range) + " Meter"}`}>
          {data.range === false ? "—" : digits.format(data.range)} <small>m</small>
        </span>
        <span className="hud-voice-status" aria-label={!data.connected ? "Sprachchat nicht verbunden" : data.talking ? "Du sprichst gerade" : "Du sprichst nicht"}>
          <i aria-hidden="true" />{status}
        </span>
      </div>
      </div>
    </aside>
  );
}
