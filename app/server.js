const express = require('express');

// App de health-check do desafio tecnico Lacrei Saude
const app = express();
const PORT = process.env.PORT || 3000;
const APP_PREFIX = process.env.APP_PREFIX || '';

app.get(`${APP_PREFIX}/status`, (req, res) => {
  res.status(200).json({
    status: 'ok',
    uptime_seconds: process.uptime(),
    timestamp: new Date().toISOString(),
  });
});

app.get('/', (req, res) => {
  res.status(200).send('Lacrei Saude - status app');
});

const server = app.listen(PORT, () => {
  console.log(`Servidor escutando na porta ${PORT}`);
});

// Graceful shutdown - importante em ECS/EKS: o orquestrador manda SIGTERM
// antes de matar o container e espera o processo encerrar sozinho.
process.on('SIGTERM', () => {
  console.log('SIGTERM recebido, encerrando servidor...');
  server.close(() => {
    console.log('Servidor encerrado.');
    process.exit(0);
  });
});
