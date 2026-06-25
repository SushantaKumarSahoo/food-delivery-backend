import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Injectable, Logger } from '@nestjs/common';
import { TrackingService } from './tracking.service';

@Injectable()
@WebSocketGateway({ cors: { origin: '*' }, namespace: '/tracking' })
export class TrackingGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(TrackingGateway.name);
  private connectedClients = new Map<string, string>(); // socketId -> userId

  constructor(private readonly trackingService: TrackingService) {}

  handleConnection(client: Socket) {
    this.logger.log(`Client connected: ${client.id}`);
  }

  handleDisconnect(client: Socket) {
    this.connectedClients.delete(client.id);
    this.logger.log(`Client disconnected: ${client.id}`);
  }

  @SubscribeMessage('joinOrderRoom')
  handleJoinRoom(
    @MessageBody() data: { orderId: string; token?: string },
    @ConnectedSocket() client: Socket,
  ) {
    client.join(`order:${data.orderId}`);
    this.logger.log(`Client ${client.id} joined room order:${data.orderId}`);
    return { event: 'joined', data: data.orderId };
  }

  @SubscribeMessage('leaveOrderRoom')
  handleLeaveRoom(
    @MessageBody() orderId: string,
    @ConnectedSocket() client: Socket,
  ) {
    client.leave(`order:${orderId}`);
    return { event: 'left', data: orderId };
  }

  @SubscribeMessage('locationUpdate')
  async handleLocationUpdate(
    @MessageBody()
    data: { orderId: string; lat: number; lng: number; partnerId?: string },
  ) {
    // Persist via TrackingService
    await this.trackingService.upsertLocation({
      orderId: data.orderId,
      partnerId: data.partnerId || 'unknown',
      lat: data.lat,
      lng: data.lng,
    });

    // Update PostGIS point on delivery_partners
    if (data.partnerId && data.partnerId !== 'unknown') {
      await this.trackingService.updatePartnerLocation(data.partnerId, data.lat, data.lng);
    }

    const update = { lat: data.lat, lng: data.lng, timestamp: new Date() };
    this.server.to(`order:${data.orderId}`).emit('onLocationUpdate', update);
  }

  // Called externally (e.g. delivery Kafka consumer) when assignment happens
  broadcastDeliveryAssigned(orderId: string, payload: any) {
    this.server.to(`order:${orderId}`).emit('deliveryAssigned', payload);
  }

  broadcastStatusUpdate(orderId: string, status: string) {
    this.server.to(`order:${orderId}`).emit('orderStatusUpdate', { status });
  }
}
