import { lazy, StrictMode, Suspense } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App";
import { isBrowser } from "./lib/nui";
import "./styles.css";
import "./design.css";
import "./menus.css";
import "./organizations.css";
import "./inventory.css";
import "./commerce.css";
import "./creator.css";
import "./nativeui.css";
import { installSelectionGuard } from "./lib/selection";

installSelectionGuard();

const root = document.getElementById("root");
const studio =
  isBrowser() && !new URLSearchParams(window.location.search).has("view");
const BrowserStudio = lazy(() => import("./dev/BrowserStudio"));
document.documentElement.classList.toggle("game-ui", !studio);

if (!root) {
  throw new Error("Missing #root element");
}

createRoot(root).render(
  <StrictMode>
    {studio ? (
      <Suspense
        fallback={<p style={{ padding: 24 }}>UI Studio wird geladen …</p>}
      >
        <BrowserStudio />
      </Suspense>
    ) : (
      <App />
    )}
  </StrictMode>,
);
