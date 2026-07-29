import { Logger } from '@nestjs/common';
import * as WebSocket from 'ws';

/**
 * Plain-WebSocket event bus (RFC 6455), compatible with Flutter's
 * `web_socket_channel` client. Replaces the Python EventBus.
 *
 * Flutter connects to ws://<host>:3000/events and receives JSON messages
 * of the form `{"event": "...", "data": ...}`.
 *
 * The backend pushes events by calling `eventsGateway.broadcast('event', data)`.
 *
 * NOTE: This is a bare `ws` server, NOT a NestJS @WebSocketGateway. Socket.IO's
 * Engine.IO handshake protocol is incompatible with plain WebSocket clients, so
 * we use `ws` directly and attach it to the HTTP server in main.ts.
 */
export class EventsGateway {
  private readonly logger = new Logger(EventsGateway.name);
  private wss: WebSocket.WebSocketServer | null = null;
  private clients = new Set<WebSocket.WebSocket>();

  /** Attach the WebSocket server to the given HTTP server, on /events. */
  attach(server: import('http').Server | import('https').Server): void {
    this.wss = new WebSocket.WebSocketServer({ server, path: '/events' });
    this.wss.on('connection', (ws: WebSocket.WebSocket) => {
      this.clients.add(ws);
      this.logger.log(`Client connected (${this.clients.size} total)`);

      ws.on('message', (raw: WebSocket.RawData) => {
        try {
          const msg = JSON.parse(raw.toString());
          // Simple ping/pong heartbeat.
          if (msg?.event === 'ping') {
            ws.send(JSON.stringify({ event: 'pong', data: msg.data }));
          }
        } catch {
          // ignore malformed frames
        }
      });

      ws.on('close', () => {
        this.clients.delete(ws);
        this.logger.log(`Client disconnected (${this.clients.size} total)`);
      });

      ws.on('error', () => {
        this.clients.delete(ws);
      });
    });
    this.logger.log('WebSocket server listening on /events');
  }

  /** Broadcast a JSON event to every connected client. */
  broadcast(event: string, data: unknown): void {
    const payload = JSON.stringify({ event, data });
    for (const ws of this.clients) {
      if (ws.readyState === WebSocket.WebSocket.OPEN) {
        ws.send(payload);
      }
    }
  }
}