let wss = null;

function initWebSocket(server) {
  const { WebSocketServer } = require("ws");
  wss = new WebSocketServer({ server });
  wss.on("connection", (socket) => {
    socket.send(JSON.stringify({ type: "connected", message: "WebSocket ativo" }));
  });
}

function broadcast(event, payload) {
  if (!wss) return;
  const message = JSON.stringify({ event, payload, ts: Date.now() });
  wss.clients.forEach((client) => {
    if (client.readyState === 1) client.send(message);
  });
}

module.exports = { initWebSocket, broadcast };
