import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { keycloakify } from "keycloakify/vite-plugin";
import { resolve } from "path";

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [
    react(),
    keycloakify({
      themeName: "finappkc",
      // Only login theme - using Keycloak default for account console
      accountThemeImplementation: "none",
    }),
  ],
  resolve: {
    alias: [
      { find: "@", replacement: resolve(__dirname, "./src") },
      { find: "@components", replacement: resolve(__dirname, "./src/components") },
      { find: "@login", replacement: resolve(__dirname, "./src/login") },
    ],
  },
  build: {
    sourcemap: true,
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ["react", "react-dom"],
        },
      },
    },
  },
  server: {
    port: 3000,
  },
});
