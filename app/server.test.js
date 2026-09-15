const request = require('supertest');
const app = require('./server');

describe('GET /status', () => {
  test('retorna status saudável e campos operacionais', async () => {
    const response = await request(app).get('/status');

    expect(response.statusCode).toBe(200);
    expect(response.body.status).toBe('ok');
    expect(typeof response.body.uptime_seconds).toBe('number');
    expect(Number.isNaN(Date.parse(response.body.timestamp))).toBe(false);
  });
});

describe('GET /', () => {
  test('retorna a identificação da aplicação', async () => {
    const response = await request(app).get('/');

    expect(response.statusCode).toBe(200);
    expect(response.text).toContain('Lacrei Saude');
  });
});
