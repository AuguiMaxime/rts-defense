// Test rapide du relais : un hôte crée un salon, un invité le rejoint, un message binaire passe.
const { spawn } = require("child_process");
const WebSocket = require("ws");
const PORT = 18080;
const srv = spawn(process.execPath, ["relay.js"], { env: { ...process.env, PORT }, stdio: "inherit" });
const fail = (m) => { console.error("ÉCHEC :", m); srv.kill(); process.exit(1); };
setTimeout(() => {
  const host = new WebSocket(`ws://127.0.0.1:${PORT}`);
  host.on("open", () => host.send(JSON.stringify({ op: "host" })));
  host.on("message", (d, bin) => {
    if (bin) {
      if (d.toString() !== "pong") fail("mauvais message reçu par l'hôte");
      console.log("OK : relais dans les deux sens");
      srv.kill();
      process.exit(0);
    }
    const m = JSON.parse(d.toString());
    if (m.op === "room") {
      console.log("OK : salon créé", m.code);
      const guest = new WebSocket(`ws://127.0.0.1:${PORT}`);
      guest.on("open", () => guest.send(JSON.stringify({ op: "join", code: m.code.toLowerCase() })));
      guest.on("message", (d2, bin2) => {
        if (bin2) return guest.send(Buffer.from("pong"), { binary: true });
        const m2 = JSON.parse(d2.toString());
        if (m2.op === "joined") {
          console.log("OK : invité dans le salon");
          host.send(Buffer.from("ping"), { binary: true });
        } else fail(JSON.stringify(m2));
      });
    }
  });
  setTimeout(() => fail("délai dépassé"), 5000);
}, 500);
