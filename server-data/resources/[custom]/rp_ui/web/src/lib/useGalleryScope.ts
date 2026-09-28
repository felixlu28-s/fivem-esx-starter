import { useEffect, useState } from "react";
import { phoneRequest } from "./phoneRequest";

export function useGalleryScope(session: string, preview: boolean) {
  const [scope, setScope] = useState(""), [error, setError] = useState("");
  useEffect(() => {
    let cancelled = false;
    setScope(""); setError("");
    void phoneRequest(session, preview, "home", {}).then((result) => {
      if (cancelled) return;
      if (!result.ok || result.phone?.kind !== "home" || !result.phone.profile.galleryScope) throw new Error("Deine Galerie konnte nicht geöffnet werden.");
      setScope(result.phone.profile.galleryScope);
    }).catch((e: unknown) => { if (!cancelled) setError(e instanceof Error ? e.message : "Galerie nicht verfügbar."); });
    return () => { cancelled = true; };
  }, [session, preview]);
  return { scope, error };
}
