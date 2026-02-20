import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
  ConnectedSocket,
  MessageBody,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Logger } from '@nestjs/common';

@WebSocketGateway({
  cors: { origin: '*' },
  namespace: '/progress',
})
export class ProgressGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server: Server;
  private readonly logger = new Logger(ProgressGateway.name);
  private connectedClients = new Map<string, string>();

  handleConnection(client: Socket) {
    this.logger.log(`Client connected: ${client.id}`);
  }

  handleDisconnect(client: Socket) {
    this.connectedClients.delete(client.id);
    this.logger.log(`Client disconnected: ${client.id}`);
  }

  @SubscribeMessage('join')
  handleJoin(@ConnectedSocket() client: Socket, @MessageBody() data: { userId: string }) {
    this.connectedClients.set(client.id, data.userId);
    client.join(`user_${data.userId}`);
    return { event: 'joined', data: { userId: data.userId } };
  }

  notifyProgress(userId: string, data: { type: string; lessonId?: string; score?: number; xp?: number }) {
    this.server.to(`user_${userId}`).emit('progress_update', data);
  }

  notifyBadgeEarned(userId: string, badge: { name: string; description: string }) {
    this.server.to(`user_${userId}`).emit('badge_earned', badge);
  }

  notifyStreakUpdate(userId: string, streakDays: number) {
    this.server.to(`user_${userId}`).emit('streak_update', { streakDays });
  }
}
