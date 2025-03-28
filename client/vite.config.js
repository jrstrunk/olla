import gleam from "vite-gleam";

export default {
  plugins: [gleam()],
  build: {
    rollupOptions: {
      input: "src/client_script.js",
      output: {
        dir: "../server/priv/static",
        entryFileNames: "client_script.mjs",
      }
    }
  }
}