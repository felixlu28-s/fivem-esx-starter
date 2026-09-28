import type { LoadingScreenMessage } from "../lib/nui";

export type LoadingState = {
  fraction: number | null;
  phase: "assets" | LoadingScreenMessage["data"]["phase"];
};
export const initialLoading: LoadingState = { fraction: null, phase: "assets" };
const phases: LoadingState["phase"][] = ["assets", "session", "scene", "exiting"];
const record = (value: unknown): value is Record<string, unknown> =>
  value !== null && typeof value === "object" && !Array.isArray(value);

// FiveM's documented engine protocol is separate from our typed NUI envelope.
// No log lines, filenames, addresses or arbitrary HTML are rendered.
export function reduceLoading(state: LoadingState, value: unknown): LoadingState {
  if (!record(value)) return state;
  if (value.eventName === "loadProgress" && typeof value.loadFraction === "number"
    && Number.isFinite(value.loadFraction)) {
    const fraction = Math.max(state.fraction ?? 0, Math.min(1, Math.max(0, value.loadFraction)));
    return fraction === state.fraction ? state : { ...state, fraction };
  }
  if (value.action !== "ui:loading" || !record(value.data)) return state;
  const phase = value.data.phase;
  if (phase !== "session" && phase !== "scene" && phase !== "exiting") return state;
  return phases.indexOf(phase) > phases.indexOf(state.phase) ? { ...state, phase } : state;
}

export function loadingLabel(state: LoadingState): string {
  if (state.phase === "exiting") return "Willkommen in Los Santos";
  if (state.phase === "scene") return "Deine Ankunft wird vorbereitet";
  if (state.phase === "session" || state.fraction === 1) return "Einreise wird vorbereitet";
  return state.fraction === null ? "Verbindung wird vorbereitet" : "Los Santos wird geladen";
}
