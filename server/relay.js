// Serveur relais RTS Defense : met en relation 2 joueurs par un code de salon
// et transmet leurs messages binaires (le jeu, lui, tourne chez l'hôte).
const http = require("http");
const { WebSocketServer } = require("ws");

const PORT = process.env.PORT || 8080;
const ROOM_TTL_MS = 30 * 60 * 1000; // un salon vide expire au bout de 30 min
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // sans O/0, I/1

const rooms = new Map(); // code -> { host, guest, created }

const server = http.createServer((req, res) => {
  // Page de santé (utile pour les hébergeurs type Render / Railway)
  res.writeHead(200, { "Content-Type": "text/plain; charset=utf-8" });
  res.end(`RTS Defense relay ok - ${rooms.size} salon(s)\n`);
});

const wss = new WebSocketServer({ server, maxPayload: 512 * 1024 });

function send(ws, obj) {
  if (ws && ws.readyState === ws.OPEN) ws.send(JSON.stringify(obj));
}

function newCode() {
  for (let tries = 0; tries < 100; tries++) {
    let code = "";
    for (let i = 0; i < 4; i++) code += ALPHABET[Math.floor(Math.random() * ALPHABET.length)];
    if (!rooms.has(code)) return code;
  }
  return null;
}

function partnerOf(ws) {
  const room = ws.room && rooms.get(ws.room);
  if (!room) return null;
  return room.host === ws ? room.guest : room.host;
}

wss.on("connection", (ws) => {
  ws.isAlive = true;
  ws.on("pong", () => (ws.isAlive = true));

  ws.on("message", (data, isBinary) => {
    if (isBinary) {
      // Message de jeu : transmis tel quel au partenaire
      const other = partnerOf(ws);
      if (other && other.readyState === other.OPEN) other.send(data, { binary: true });
      return;
    }
    let msg;
    try {
      msg = JSON.parse(data.toString());
    } catch {
      return send(ws, { op: "error", msg: "Message invalide" });
    }
    if (msg.op === "host") {
      const code = newCode();
      if (!code) return send(ws, { op: "error", msg: "Serveur plein" });
      rooms.set(code, { host: ws, guest: null, created: Date.now() });
      ws.room = code;
      send(ws, { op: "room", code });
    } else if (msg.op === "join") {
      const code = String(msg.code || "").toUpperCase().trim();
      const room = rooms.get(code);
      if (!room) return send(ws, { op: "error", msg: "Salon introuvable" });
      if (room.guest) return send(ws, { op: "error", msg: "Salon déjà complet" });
      room.guest = ws;
      ws.room = code;
      send(ws, { op: "joined", code });
      send(room.host, { op: "partner" });
    }
  });

  ws.on("close", () => {
    const room = ws.room && rooms.get(ws.room);
    if (!room) return;
    if (room.host === ws) {
      send(room.guest, { op: "closed" });
      rooms.delete(ws.room);
    } else if (room.guest === ws) {
      room.guest = null;
      send(room.host, { op: "left" });
    }
  });
});

// Nettoyage : connexions mortes et salons abandonnés
setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws.isAlive) {
      ws.terminate();
      continue;
    }
    ws.isAlive = false;
    ws.ping();
  }
  const now = Date.now();
  for (const [code, room] of rooms) {
    if (!room.guest && now - room.created > ROOM_TTL_MS) {
      send(room.host, { op: "closed" });
      rooms.delete(code);
    }
  }
}, 20000);

server.listen(PORT, () => console.log(`RTS Defense relay en écoute sur le port ${PORT}`));
