import { useEffect, useRef } from "react";

const codes: Record<string, string> = {
  Backspace: "BACKSPACE", Tab: "TAB", Enter: "RETURN", Space: "SPACE", CapsLock: "CAPITAL",
  ShiftLeft: "LSHIFT", ShiftRight: "RSHIFT", ControlLeft: "LCONTROL", ControlRight: "RCONTROL",
  AltLeft: "LMENU", Insert: "INSERT", Delete: "DELETE", Home: "HOME", End: "END",
  PageUp: "PRIOR", PageDown: "NEXT", ArrowLeft: "LEFT", ArrowRight: "RIGHT", ArrowUp: "UP", ArrowDown: "DOWN",
  NumpadMultiply: "MULTIPLY", NumpadAdd: "ADD", NumpadSubtract: "SUBTRACT",
  NumpadDecimal: "DECIMAL", NumpadDivide: "DIVIDE", NumpadEnter: "RETURN",
};
const oem: Record<number, string> = {
  186: "OEM_1", 187: "OEM_PLUS", 188: "OEM_COMMA", 189: "OEM_MINUS", 190: "OEM_PERIOD",
  192: "OEM_3", 219: "OEM_4", 220: "OEM_5", 221: "OEM_6", 222: "OEM_7", 226: "OEM_102",
};
export function inputKey(event: KeyboardEvent): string | undefined {
  if (/^Numpad[0-9]$/.test(event.code)) return `NUMPAD${event.code.slice(-1)}`;
  if (codes[event.code]) return codes[event.code];
  if (/^[a-z0-9]$/i.test(event.key) || /^F\d{1,2}$/.test(event.key)) return event.key.toUpperCase();
  // CEF on Windows exposes virtual-key codes for layout-dependent OEM keys.
  return oem[event.keyCode];
}
export function editing(target: EventTarget | null): boolean {
  return target instanceof HTMLElement && !!target.closest('input, textarea, select, [contenteditable]:not([contenteditable="false"])');
}

// In-game commands open the view; while NUI owns focus, its DOM handles the
// matching close key. Never forward all NUI keys to gameplay or unlock controls.
export function useMenuToggle(key: string | undefined, onToggle: () => void, disabled = false) {
  const action = useRef(onToggle);
  action.current = onToggle;
  useEffect(() => {
    if (!key || disabled) return;
    const blocked = (event: Event) => event.defaultPrevented || editing(event.target) || !!document.querySelector('dialog[open]');
    const keyboard = (event: KeyboardEvent) => {
      if (blocked(event) || event.repeat || event.isComposing || event.metaKey || inputKey(event) !== key) return;
      if ((event.ctrlKey && !key.includes("CONTROL")) || (event.altKey && key !== "LMENU")) return;
      event.preventDefault();
      action.current();
    };
    const pointer = (event: MouseEvent | WheelEvent) => {
      if (blocked(event) || event.ctrlKey || event.altKey || event.metaKey || event.shiftKey) return;
      const target = event.target;
      if (target instanceof HTMLElement && target.closest('button, a, [role="button"], [draggable="true"]')) return;
      const wheel = event instanceof WheelEvent;
      // Preserve normal scrolling and primary mouse interactions inside panels.
      if ((wheel || event.button !== 1) && target instanceof HTMLElement
        && !target.matches('body, #root, .menu-backdrop, .inventory-backdrop, .commerce-backdrop')) return;
      const actual = wheel ? (event.deltaY < 0 ? "WHEELUP" : event.deltaY > 0 ? "WHEELDOWN" : "")
        : ({ 0: "MOUSE1", 1: "MOUSE3", 2: "MOUSE2" } as Record<number, string>)[event.button];
      if (actual !== key) return;
      event.preventDefault();
      action.current();
    };
    window.addEventListener("keydown", keyboard);
    window.addEventListener("mousedown", pointer);
    window.addEventListener("wheel", pointer, { passive: false });
    return () => {
      window.removeEventListener("keydown", keyboard);
      window.removeEventListener("mousedown", pointer);
      window.removeEventListener("wheel", pointer);
    };
  }, [key, disabled]);
}
