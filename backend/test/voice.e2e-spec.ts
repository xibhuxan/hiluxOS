import { INestApplication } from '@nestjs/common';
import { buildApp, agent } from './setup';

/**
 * E2E over the voice REST surface, driven by the mock voice driver (no
 * microphone or speech models needed). EventsGateway is stubbed by buildApp.
 */
describe('Voice (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    ({ app } = await buildApp());
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /api/voice reports availability and history', async () => {
    const res = await agent(app).get('/api/voice').expect(200);
    expect(res.body.status).toBe('idle');
    expect(res.body.availability.asr).toBe(true);
    expect(res.body.availability.tts).toBe(true);
    expect(Array.isArray(res.body.history)).toBe(true);
  });

  it('POST /api/voice/command runs a text command and returns the turn', async () => {
    const res = await agent(app)
      .post('/api/voice/command')
      .send({ text: 'llévame a Bilbao' })
      .expect(201);
    expect(res.body.intent).toBe('navigate');
    expect(res.body.acted).toBe(true);
    expect(res.body.reply).toMatch(/bilbao/i);
  });

  it('POST /api/voice/command validates the body', async () => {
    await agent(app).post('/api/voice/command').send({}).expect(400);
    await agent(app).post('/api/voice/command').send({ text: '' }).expect(400);
  });

  it('GET /api/voice/history accumulates turns', async () => {
    await agent(app).post('/api/voice/command').send({ text: 'qué tiempo hace' }).expect(201);
    await agent(app).post('/api/voice/command').send({ text: 'pon música' }).expect(201);
    const res = await agent(app).get('/api/voice/history').expect(200);
    expect(res.body.history.length).toBeGreaterThanOrEqual(2);
    expect(res.body.history.at(-1).intent).toBe('media_control');
  });

  it('POST /api/voice/speak returns a WAV audio body', async () => {
    const res = await agent(app)
      .post('/api/voice/speak')
      .send({ text: 'Hola, soy tu asistente' })
      .expect(201)
      .expect('Content-Type', /audio\/wav/);
    expect(res.body.length).toBeGreaterThan(44);
    expect(res.body.subarray(0, 4).toString()).toBe('RIFF');
  });

  it('DELETE /api/voice/history clears the conversation', async () => {
    await agent(app).post('/api/voice/command').send({ text: 'hola' }).expect(201);
    await agent(app).delete('/api/voice/history').expect(200);
    const res = await agent(app).get('/api/voice/history').expect(200);
    expect(res.body.history).toEqual([]);
  });
});
