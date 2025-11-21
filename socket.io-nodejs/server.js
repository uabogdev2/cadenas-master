require('dotenv').config();

const path = require('path');
const express = require('express');
const cors = require('cors');
const http = require('http');

const { initSocketServer } = require('./src/socket/duelGateway');

const app = express();
const server = http.createServer(app);

const allowedOrigins = process.env.CORS_ALLOWED_ORIGINS
  ? process.env.CORS_ALLOWED_ORIGINS.split(',').map((origin) => origin.trim())
  : '*';

console.log(
  '[socket-io] CORS allow list:',
  Array.isArray(allowedOrigins) ? allowedOrigins.join(', ') : allowedOrigins
);

app.use(
  cors({
    origin: allowedOrigins,
    credentials: true,
  })
);
app.use(express.json());

app.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'Socket.IO server prêt',
    timestamp: new Date().toISOString(),
  });
});

app.get('/health', (req, res) => {
  res.json({
    success: true,
    message: 'OK',
    timestamp: new Date().toISOString(),
  });
});

app.use('/socket-test', express.static(path.join(__dirname, 'public/socket-test')));

function resolveRuntimePort() {
  const candidates = [process.env.PORT, process.env.SOCKET_PORT];

  for (const value of candidates) {
    if (!value) continue;
    const parsed = Number(value);
    if (!Number.isNaN(parsed) && parsed > 0) {
      return parsed;
    }
  }

  if (process.env.NODE_ENV !== 'production') {
    console.warn('[socket-io] PORT non défini, utilisation du port 4000 en développement.');
    return 4000;
  }

  return null;
}

const runtimePort = resolveRuntimePort();
const runtimeHost = process.env.HOST || '0.0.0.0';

if (!runtimePort) {
  console.error('[socket-io] Aucun port défini. Définissez PORT ou SOCKET_PORT dans votre environnement.');
  process.exit(1);
}

console.log('[socket-io] Port retenu', runtimePort);

const io = initSocketServer(server, {
  cors: {
    origin: allowedOrigins,
    credentials: true,
  },
});

server.listen(runtimePort, runtimeHost, () => {
  console.log(`[socket-io] Serveur à l'écoute sur ${runtimeHost}:${runtimePort}`);
});

function gracefulShutdown(signal) {
  console.log(`\n[socket-io] ${signal} reçu - arrêt en cours`);
  io.close(() => {
    server.close(() => process.exit(0));
  });
}

process.on('SIGINT', () => gracefulShutdown('SIGINT'));
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));

module.exports = { app, server, io };

