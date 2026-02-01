import { createRoot } from "react-dom/client";
import { StrictMode } from "react";
import { KcPage } from "./keycloak-theme/kc.gen";

// This file is the entry point for Keycloakify
// It renders the appropriate Keycloak page based on kcContext

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    {window.kcContext ? (
      <KcPage kcContext={window.kcContext} />
    ) : (
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          minHeight: "100vh",
          fontFamily: "system-ui, sans-serif",
          color: "#64748b",
        }}
      >
        <h1 style={{ color: "#1e293b", marginBottom: "0.5rem" }}>FinAppKC Theme</h1>
        <p>This page only works within Keycloak context.</p>
        <p style={{ fontSize: "0.875rem" }}>
          Run <code style={{ background: "#f1f5f9", padding: "0.25rem 0.5rem", borderRadius: "4px" }}>npm run dev</code> with mock context for development.
        </p>
      </div>
    )}
  </StrictMode>
);
