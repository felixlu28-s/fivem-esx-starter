import { useCallback, useEffect, useRef, useState } from "react";
import { fetchNui, isBrowser } from "../lib/nui";
import { CreatorIcon } from "./CreatorIcon";

export type CameraView = "body" | "face" | "upper" | "lower" | "shoes";
const presets: { id: CameraView; label: string; zoom: number }[] = [
  { id: "body", label: "Ganzkörper", zoom: 1 / 2.2 },
  { id: "face", label: "Gesicht", zoom: 0.35 / 0.9 },
  { id: "upper", label: "Oberkörper", zoom: 0.7 / 1.8 },
  { id: "lower", label: "Unterkörper", zoom: 0.8 / 1.7 },
  { id: "shoes", label: "Schuhe", zoom: 0.45 / 1.25 },
];
type CameraState = {
  view: CameraView;
  rotation: number;
  pitch: number;
  zoom: number;
};
const clamp = (v: number, min: number, max: number) =>
  Math.max(min, Math.min(max, v));

export function CreatorCamera({
  focus,
  onError,
  action = "rp_characters:camera",
}: {
  focus: CameraView;
  onError: (message: string) => void;
  action?: string;
}) {
  const [state, setState] = useState<CameraState>({
    view: focus,
    rotation: 0,
    pitch: 0,
    zoom: presets.find((p) => p.id === focus)!.zoom,
  });
  const current = useRef(state);
  const area = useRef<HTMLDivElement>(null);
  const drag = useRef<{ id: number; x: number; y: number } | null>(null);
  const [dragging, setDragging] = useState(false);
  const pending = useRef<CameraState | null>(null);
  const alive = useRef(false);
  const error = useRef(onError);
  error.current = onError;
  const update = useCallback((patch: Partial<CameraState>) => {
    const next = { ...current.current, ...patch };
    current.current = next;
    pending.current = next;
    setState(next);
  }, []);
  const preset = useCallback(
    (view: CameraView) => {
      update({
        view,
        pitch: 0,
        zoom: presets.find((p) => p.id === view)!.zoom,
      });
    },
    [update],
  );
  useEffect(() => {
    preset(focus);
  }, [focus, preset]);
  useEffect(() => {
    alive.current = true;
    // At most one callback in flight. Fast mouse input replaces the pending
    // absolute state instead of producing a growing queue of camera deltas.
    let inFlight = false;
    const timer = window.setInterval(() => {
      if (!pending.current || inFlight) return;
      const next = pending.current;
      pending.current = null;
      inFlight = true;
      void fetchNui(action, next)
        .then((result) => {
          if (!result.ok) throw new Error();
        })
        .catch(() => {
          if (alive.current) error.current("Kamera nicht verfügbar.");
        })
        .finally(() => {
          inFlight = false;
        });
    }, 33);
    return () => {
      alive.current = false;
      pending.current = null;
      window.clearInterval(timer);
    };
  }, [action]);
  useEffect(() => {
    const node = area.current;
    if (!node) return;
    const wheel = (event: WheelEvent) => {
      event.preventDefault();
      const delta =
        event.deltaY *
        (event.deltaMode === 1 ? 16 : event.deltaMode === 2 ? 400 : 1);
      update({
        zoom: clamp(
          current.current.zoom + clamp(delta, -160, 160) * 0.0015,
          0,
          1,
        ),
      });
    };
    node.addEventListener("wheel", wheel, { passive: false });
    const cancel = () => {
      drag.current = null;
      setDragging(false);
    };
    window.addEventListener("blur", cancel);
    return () => {
      node.removeEventListener("wheel", wheel);
      window.removeEventListener("blur", cancel);
    };
  }, [update]);
  return (
    <>
      <div
        ref={area}
        className={`camera-drag-area ${dragging ? "dragging" : ""}`}
        role="region"
        aria-label="Charaktervorschau: ziehen zum Drehen, Mausrad zum Zoomen"
        onPointerDown={(event) => {
          if (event.button !== 0) return;
          event.currentTarget.setPointerCapture(event.pointerId);
          drag.current = {
            id: event.pointerId,
            x: event.clientX,
            y: event.clientY,
          };
          setDragging(true);
        }}
        onPointerMove={(event) => {
          const previous = drag.current;
          if (!previous || previous.id !== event.pointerId) return;
          const scale = Math.max(
            1,
            Math.min(window.innerWidth / 1920, window.innerHeight / 1080),
          );
          update({
            rotation:
              ((current.current.rotation +
                ((event.clientX - previous.x) * 0.28) / scale +
                540) %
                360) -
              180,
            pitch: clamp(
              current.current.pitch +
                ((event.clientY - previous.y) * 0.18) / scale,
              -25,
              35,
            ),
          });
          drag.current = {
            id: event.pointerId,
            x: event.clientX,
            y: event.clientY,
          };
        }}
        onPointerUp={(event) => {
          if (drag.current?.id !== event.pointerId) return;
          event.currentTarget.releasePointerCapture(event.pointerId);
          drag.current = null;
          setDragging(false);
        }}
        onLostPointerCapture={() => {
          drag.current = null;
          setDragging(false);
        }}
        onPointerCancel={() => {
          drag.current = null;
          setDragging(false);
        }}
      >
        {isBrowser() && (
          <span className="camera-browser-note">
            3D-Vorschau im Spiel · Kamerasteuerung hier testbar
          </span>
        )}
      </div>
      <div className="camera-controls" aria-label="Kamerasteuerung">
        <div className="camera-presets">
          {presets.map((item) => (
            <button
              key={item.id}
              aria-label={item.label}
              data-tip={item.label}
              aria-pressed={state.view === item.id}
              onClick={() => preset(item.id)}
            >
              <CreatorIcon name={item.id} />
            </button>
          ))}
        </div>
        <div className="camera-tools">
          <button
            aria-label="Herauszoomen"
            data-tip="Herauszoomen"
            disabled={state.zoom >= 1}
            onClick={() => update({ zoom: clamp(state.zoom + 0.1, 0, 1) })}
          >
            <CreatorIcon name="minus" />
          </button>
          <button
            aria-label="Heranzoomen"
            data-tip="Heranzoomen"
            disabled={state.zoom <= 0}
            onClick={() => update({ zoom: clamp(state.zoom - 0.1, 0, 1) })}
          >
            <CreatorIcon name="plus" />
          </button>
          <button
            aria-label="Zentrieren"
            data-tip="Zentrieren"
            onClick={() => {
              preset(state.view);
              update({ rotation: 0 });
            }}
          >
            <CreatorIcon name="reset" />
          </button>
        </div>
        <p className="camera-help">
          <CreatorIcon name="mouse" /> Ziehen zum Drehen <span>·</span> Scrollen
          zum Zoomen
        </p>
        {isBrowser() && (
          <output className="camera-readout">
            {Math.round(state.rotation)}° · Neigung {Math.round(state.pitch)}° ·
            Zoom {Math.round((1 - state.zoom) * 100)} %
          </output>
        )}
      </div>
    </>
  );
}
