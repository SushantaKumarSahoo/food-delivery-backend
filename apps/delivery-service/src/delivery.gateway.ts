import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '@quickbite/prisma';

@WebSocketGateway({
  cors: { origin: '*' },
  namespace: '/delivery',
})
export class DeliveryGateway
  implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer() server: Server;
  private readonly logger = new Logger(DeliveryGateway.name);

  // Map: partnerId -> socketId
  private partnerSockets = new Map<string, string>();

  constructor(
    private readonly jwtService: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  afterInit() {
    this.logger.log('Delivery WebSocket Gateway initialized');
  }

  handleConnection(client: Socket) {
    this.logger.log(`Client connected: ${client.id}`);
  }

  handleDisconnect(client: Socket) {
    // Remove partner from map on disconnect
    for (const [partnerId, socketId] of this.partnerSockets.entries()) {
      if (socketId === client.id) {
        this.partnerSockets.delete(partnerId);
        this.logger.log(`Partner ${partnerId} disconnected`);
        break;
      }
    }
  }

  // ─── Customer joins order tracking room ──────────────────────────────────

  @SubscribeMessage('track_order')
  async handleTrackOrder(
    @MessageBody() data: { orderId: string; token: string },
    @ConnectedSocket() client: Socket,
  ) {
    try {
      this.jwtService.verify(data.token, {
        secret: process.env.JWT_SECRET || 'super-secret',
      });
      client.join(`order:${data.orderId}`);
      this.logger.log(`Customer tracking order ${data.orderId}`);

      // Send current location immediately if available
      const assignment = await this.prisma.deliveryAssignment.findFirst({
        where: { orderId: data.orderId },
        include: { partner: true },
      });

      if (assignment?.partner) {
        const partner = assignment.partner as any;
        if (partner.currentLat && partner.currentLng) {
          client.emit('rider_location', {
            orderId: data.orderId,
            lat: partner.currentLat,
            lng: partner.currentLng,
            riderName: `${partner.firstName} ${partner.lastName}`,
            status: assignment.status,
          });
        }
      }

      client.emit('tracking_joined', { orderId: data.orderId });
    } catch {
      client.emit('error', { message: 'Invalid token' });
    }
  }

  // ─── Rider sends their live location ────────────────────────────────────

  @SubscribeMessage('rider_update_location')
  async handleRiderLocation(
    @MessageBody()
    data: { partnerId: string; orderId: string; lat: number; lng: number; token: string },
    @ConnectedSocket() client: Socket,
  ) {
    try {
      this.jwtService.verify(data.token, {
        secret: process.env.JWT_SECRET || 'super-secret',
      });

      // Register socket for this partner
      this.partnerSockets.set(data.partnerId, client.id);

      // Persist location to DB
      await this.prisma.deliveryPartner.updateMany({
        where: { id: data.partnerId },
        data: {
          currentLat: data.lat,
          currentLng: data.lng,
          lastLocationAt: new Date(),
        } as any,
      });

      // Broadcast to all customers tracking this order
      this.server.to(`order:${data.orderId}`).emit('rider_location', {
        orderId: data.orderId,
        lat: data.lat,
        lng: data.lng,
        timestamp: new Date().toISOString(),
      });
    } catch {
      client.emit('error', { message: 'Invalid token' });
    }
  }

  // ─── Called by delivery service when status changes ──────────────────────

  broadcastOrderStatus(orderId: string, status: string, eta?: number) {
    this.server.to(`order:${orderId}`).emit('order_status', {
      orderId,
      status,
      estimatedMinutes: eta,
      timestamp: new Date().toISOString(),
    });
  }
}
