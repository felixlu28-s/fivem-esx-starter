import { useEffect, useRef, type FormEvent } from "react";
import { fetchNui } from "../lib/nui";

export type PhoneField = { key: string; label: string; value: string; max: number; multiline?: boolean; telephone?: boolean };
export type PhoneFormState = {
  title: string;
  fields: PhoneField[];
  nonce: string;
  submitLabel?: string;
  save: (values: Record<string, string>, nonce: string) => Promise<void>;
};

/** Text editing temporarily owns input; all other phone navigation keeps game movement. */
export function PhoneForm({ form, setForm, busy, submit, session, preview, active = true }: {
  form: PhoneFormState; setForm: (form: PhoneFormState | null) => void; busy: boolean;
  submit: () => void; session: string; preview: boolean; active?: boolean;
}) {
  const ref = useRef<HTMLFormElement>(null);
  const lastField = useRef<HTMLElement | null>(null);
  const current = useRef({ setForm, submit, busy }); current.current = { setForm, submit, busy };
  useEffect(() => {
    if (!active) return;
    ref.current?.querySelector<HTMLElement>("input,textarea,button")?.focus();
    if (!preview) void fetchNui("rp_phone:typing", { session, active: true }).catch(() => undefined);
    return () => { if (!preview) void fetchNui("rp_phone:typing", { session, active: false }).catch(() => undefined); };
  }, [session, preview, active]);
  useEffect(() => {
    const element = ref.current;
    if (!active || !element || element.contains(document.activeElement)) return;
    const previous = lastField.current;
    (previous && element.contains(previous) && !previous.matches(":disabled") ? previous
      : element.querySelector<HTMLElement>("input,textarea,button:not(:disabled)"))?.focus();
  }, [active, busy]);
  useEffect(() => {
    if (!active) return;
    // A rejected async submit may leave focus on body. Form controls must still
    // receive keys, and cancelling never waits for a server response.
    const handler = (event: KeyboardEvent) => {
      const element = ref.current;
      if (!element) return;
      const target = document.activeElement;
      const editing = element.contains(target) && (target instanceof HTMLInputElement || target instanceof HTMLTextAreaElement);
      const cancel = event.key === "Escape" || event.key === "\\" || event.key === "Backspace" && !editing;
      const move = event.key === "ArrowDown" || event.key === "ArrowUp";
      if (!cancel && !move && event.key !== "Enter") return;
      if (event.key === "Enter" && event.shiftKey && target instanceof HTMLTextAreaElement) return;
      event.preventDefault(); event.stopImmediatePropagation();
      if (event.repeat && (cancel || event.key === "Enter")) return;
      if (cancel) { current.current.setForm(null); return; }
      const fields = Array.from(element.querySelectorAll<HTMLElement>("input,textarea,button:not(:disabled)"));
      const index = fields.indexOf(target as HTMLElement);
      if (move) {
        const next = index < 0 ? (event.key === "ArrowDown" ? 0 : fields.length - 1)
          : (index + (event.key === "ArrowDown" ? 1 : fields.length - 1)) % fields.length;
        fields[next]?.focus(); return;
      }
      if (target instanceof HTMLButtonElement && element.contains(target) && target.type === "button") target.click();
      else if (!current.current.busy) current.current.submit();
    };
    window.addEventListener("keydown", handler, true);
    return () => window.removeEventListener("keydown", handler, true);
  }, [active]);
  const send = (event: FormEvent) => { event.preventDefault(); if (!busy) submit(); };
  return <form className="phone-form comm-form" ref={ref} onSubmit={send} aria-busy={busy} onFocusCapture={(event) => { lastField.current = event.target; }}>
    <h3>{form.title}</h3>
    {form.fields.map((field) => {
      const change = (value: string) => setForm({ ...form, fields: form.fields.map((f) => f.key === field.key ? { ...f, value } : f) });
      return <label key={field.key}>{field.label}{field.multiline
        ? <textarea aria-label={field.label} value={field.value} maxLength={field.max} readOnly={busy} onChange={(e) => change(e.target.value)} />
        : <input type={field.telephone ? "tel" : "text"} autoComplete="off" aria-label={field.label} value={field.value} maxLength={field.max} readOnly={busy} onChange={(e) => change(e.target.value)} />}</label>;
    })}
    <div className="comm-form-buttons"><button type="button" onClick={() => setForm(null)}>Abbrechen</button><button type="submit" disabled={busy}>{busy ? "Einen Moment …" : form.submitLabel ?? "Speichern"}</button></div>
    <small>↑ ↓ Feld wechseln · Enter bestätigen · Esc zurück</small>
  </form>;
}
