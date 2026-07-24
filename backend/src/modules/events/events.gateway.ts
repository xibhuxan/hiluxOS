import {
  WebSocketGateway,
  WebSocketServer,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  MessageBody,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Logger } from '@nestjs/common';

/**
 * Replaces the Python EventBus. Flutter connects to /events and listens for
 * real-time events (vehicle signals, radio status, gpio changes, etc.).
 *
 * The backend can push events by calling `eventsGateway.broadcast('event', data)`.
 */
@WebSocketGateway({ namespace: '/events', cors: true })
export class EventsGateway implements OnGatewayConnection, OnGatewayDisconnect {
  private readonly logger = new Logger(EventsGateway.name);

  @WebSocketServer()
  server!: Server;

  handleConnection(client: Socket) {
    this.logger.log(`Client connected: ${client.id}`);
  }

  handleDisconnect(client: Socket) {
    this.logger.log(`Client disconnected: ${client.id}`);
  }

  /** Echo + heartbeat: client can ping to verify the connection is alive. */
  @SubscribeMessage('ping')
  onPing(_client: Socket, @MessageBody() data: unknown) {
    return { event: 'pong', data };
  }

  /** Broadcast an event to every connected client. */
  broadcast(event: string, data: unknown) {
    this.server.emit(event, data);
  }
}