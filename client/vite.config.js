import gleam from "vite-gleam";

export default {
  plugins: [gleam()],
  build: {
    rollupOptions: {
      input: "src/client.js",
      output: {
        dir: "../server/priv/static",
        entryFileNames: "client.mjs",
      }
    }
  }
}