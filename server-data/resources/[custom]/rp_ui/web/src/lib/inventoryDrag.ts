import { useEffect, useRef, useState, type PointerEvent } from "react";
import type { InventoryItem, InventorySide } from "./inventory";

type Slot = { side: InventorySide; slot: number };
type Drag = Slot & {
  item: InventoryItem; count: number; x: number; y: number; target: Slot | null;
  width: number; height: number; offsetX: number; offsetY: number;
  settling?: boolean;
};
type Press = Drag & { id: number; originX: number; originY: number; started: boolean; element: HTMLElement };

// Pointer capture works inside FiveM's CEF without the OS HTML drag/drop bridge.
export function useInventoryDrag(onDrop: (drag: Drag, target: Slot | "ground") => Promise<void>) {
  const [drag, setDrag] = useState<Drag | null>(null);
  const press = useRef<Press | null>(null);
  const suppressClick = useRef(false);
  const settlement = useRef<object | null>(null);
  const callback = useRef(onDrop);
  callback.current = onDrop;
  const cancel = () => {
    // After release the server owns the outcome. Pointer-capture loss, blur and
    // intermediate snapshots must not expose the old source slot again.
    if (settlement.current) return;
    const p = press.current;
    press.current = null;
    if (p?.element.hasPointerCapture(p.id)) p.element.releasePointerCapture(p.id);
    setDrag(null);
  };
  const locate = (x: number, y: number): Slot | null => {
    const slot = document.elementFromPoint(x, y)?.closest<HTMLElement>(".inventory-slot");
    const side = slot?.dataset.side;
    const index = Number(slot?.dataset.slot);
    return (side === "own" || side === "external") && Number.isInteger(index) && index > 0
      ? { side, slot: index } : null;
  };
  useEffect(() => {
    const escape = (e: KeyboardEvent) => {
      if (e.key === "Escape" && press.current?.started) {
        e.preventDefault(); e.stopImmediatePropagation(); cancel();
      }
    };
    window.addEventListener("keydown", escape, true);
    window.addEventListener("blur", cancel);
    return () => { settlement.current = null; window.removeEventListener("keydown", escape, true); window.removeEventListener("blur", cancel); };
  }, []);
  useEffect(() => {
    if (!drag) return;
    let frame = 0, previous = performance.now();
    const scroll = (now: number) => {
      const p = press.current;
      if (!p?.started) return;
      const grid = document.elementFromPoint(p.x, p.y)?.closest<HTMLElement>(".inventory-grid");
      if (grid) {
        const rect = grid.getBoundingClientRect();
        const edge = Math.min(48, rect.height / 4);
        const direction = p.y < rect.top + edge ? -1 : p.y > rect.bottom - edge ? 1 : 0;
        const before = grid.scrollTop;
        grid.scrollTop += direction * Math.min(32, now - previous) * 0.65;
        if (before !== grid.scrollTop) { p.target = locate(p.x, p.y); setDrag({ ...p }); }
      }
      previous = now;
      frame = requestAnimationFrame(scroll);
    };
    frame = requestAnimationFrame(scroll);
    return () => cancelAnimationFrame(frame);
  }, [!!drag]);
  return {
    drag, cancel,
    consumeClick: () => {
      const value = suppressClick.current;
      suppressClick.current = false;
      return value;
    },
    start: (e: PointerEvent<HTMLElement>, side: InventorySide, item: InventoryItem, count: number) => {
      if (settlement.current || e.button !== 0 || !e.isPrimary) return;
      suppressClick.current = false;
      const rect = e.currentTarget.getBoundingClientRect();
      press.current = { side, slot: item.slot, item, count, x: e.clientX, y: e.clientY,
        width: rect.width, height: rect.height, offsetX: e.clientX - rect.left, offsetY: e.clientY - rect.top,
        originX: e.clientX, originY: e.clientY, id: e.pointerId, started: false, target: null, element: e.currentTarget };
      e.currentTarget.setPointerCapture(e.pointerId);
    },
    move: (e: PointerEvent<HTMLElement>) => {
      const p = press.current;
      if (!p || p.id !== e.pointerId) return;
      p.x = e.clientX; p.y = e.clientY;
      if (!p.started && Math.hypot(p.x - p.originX, p.y - p.originY) < 6) return;
      e.preventDefault(); p.started = true;
      p.target = locate(p.x, p.y);
      setDrag({ ...p });
    },
    end: (e: PointerEvent<HTMLElement>) => {
      const p = press.current;
      if (!p || p.id !== e.pointerId) return;
      if (p.started) {
        e.preventDefault(); suppressClick.current = true;
        const target = locate(e.clientX, e.clientY);
        const element = document.elementFromPoint(e.clientX, e.clientY);
        const destination = target && (target.side !== p.side || target.slot !== p.slot) ? target
          : !target && p.side === "own" && element?.closest(".inventory-backdrop")
            && !element.closest(".inventory-shell, .inventory-context") ? "ground" : null;
        if (destination) {
          const ticket = {};
          settlement.current = ticket;
          press.current = null;
          if (p.element.hasPointerCapture(p.id)) p.element.releasePointerCapture(p.id);
          const rect = destination !== "ground" ? element?.closest(".inventory-slot")?.getBoundingClientRect() : null;
          setDrag({ ...p, settling: true, target,
            x: rect ? rect.left + p.offsetX : e.clientX,
            y: rect ? rect.top + p.offsetY : e.clientY });
          // Keep only the visual tile, never optimistically change inventory state.
          void callback.current(p, destination).finally(() => {
            if (settlement.current !== ticket) return;
            settlement.current = null;
            setDrag(null);
          });
          return;
        }
      }
      cancel();
    },
  };
}
