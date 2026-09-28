import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "../styles.css";
import "../design.css";
import { installSelectionGuard } from "../lib/selection";
import { LoadingScreen } from "./LoadingScreen";

installSelectionGuard();
const root = document.getElementById("root");
if (!root) throw new Error("Missing loading root");
const preview = new URLSearchParams(location.search).get("preview") === "1"
  && (location.hostname === "localhost" || location.hostname === "127.0.0.1");
createRoot(root).render(<StrictMode><LoadingScreen preview={preview} /></StrictMode>);
