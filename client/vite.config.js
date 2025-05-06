import gleam from "vite-gleam";

export default {
  plugins: [gleam()],
  build: {
    rollupOptions: {
      input: "src/o11a_client_script.js",
      output: {
        dir: "../server/priv/static",
        entryFileNames: "o11a_client_script.mjs",
      }
    }
  }
}