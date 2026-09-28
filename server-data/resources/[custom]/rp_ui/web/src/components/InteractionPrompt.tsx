import { useEffect, useState } from "react";
import { UiIcon } from "./UiIcon";
import type { InteractionHint } from "../lib/nui";
import "../interaction.css";

export function InteractionPrompt({ data }: { data: InteractionHint | null }) {
  const [displayed, setDisplayed] = useState(data);
  const [visible, setVisible] = useState(false);
  useEffect(() => {
    let frame = 0;
    let timer = 0;
    if (data) {
      setDisplayed(data);
      // Allow the initial hidden position to paint before transitioning in.
      frame = requestAnimationFrame(() => {
        frame = requestAnimationFrame(() => setVisible(true));
      });
    } else {
      setVisible(false);
      // Retain the last content during the exit. A new hint cancels this timer
      // and reverses the transition, avoiding flicker at interaction boundaries.
      timer = window.setTimeout(() => setDisplayed(null), 180);
    }
    return () => {
      cancelAnimationFrame(frame);
      window.clearTimeout(timer);
    };
  }, [data]);
  if (!displayed) return null;
  const hint = data ?? displayed;
  return (
    <aside className={`interaction-prompt${visible ? " is-visible" : ""}`} role="status" aria-label="Interaktion" aria-hidden={!data}>
      <kbd className={`interaction-key${hint.key ? "" : " is-unbound"}`} aria-label={hint.key ? `Taste ${hint.key}` : "Keine Taste belegt"}>
        {hint.key || "—"}
      </kbd>
      <div className="interaction-copy">
        <span><UiIcon name={hint.icon} />{hint.label}</span>
        <strong>{hint.key ? hint.verb : "Taste in den Einstellungen belegen"}</strong>
      </div>
    </aside>
  );
}
