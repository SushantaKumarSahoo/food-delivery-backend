import { Injectable, NotFoundException, Logger } from '@nestjs/common';
import { PrismaService } from '@quickbite/prisma';

@Injectable()
export class TrackingService {
  private readonly logger = new Logger(TrackingService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Get the latest known location for an order's delivery assignment.
   */
  async getLatestLocation(orderId: string) {
    const tracking = await (this.prisma as any).deliveryTracking.findFirst({
      where: { orderId },
      orderBy: { updatedAt: 'desc' },
    });
    if (!tracking) throw new NotFoundException('No tracking data found for this order');
    return tracking;
  }

  /**
   * Persist a driver location update (called from the WebSocket gateway).
   */
  async upsertLocation(data: {
    orderId: string;
    partnerId: string;
    lat: number;
    lng: number;
  }) {
    try {
      return await (this.prisma as any).deliveryTracking.upsert({
        where: { orderId: data.orderId },
        update: {
          lat: data.lat,
          lng: data.lng,
          partnerId: data.partnerId,
          updatedAt: new Date(),
        },
        create: {
          orderId: data.orderId,
          partnerId: data.partnerId,
          lat: data.lat,
          lng: data.lng,
        },
      });
    } catch (err: any) {
      this.logger.warn(`Could not persist tracking update: ${err.message}`);
      return null;
    }
  }

  /**
   * Update the delivery partner's geographic location in the DB (PostGIS point).
   */
  async updatePartnerLocation(partnerId: string, lat: number, lng: number) {
    try {
      await this.prisma.$executeRaw`
        UPDATE delivery_partners
        SET current_location = ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326),
            updated_at = NOW()
        WHERE id = ${partnerId}::uuid
      `;
      this.logger.debug(`Partner ${partnerId} location updated: (${lat}, ${lng})`);
    } catch (err: any) {
      this.logger.warn(`PostGIS location update failed: ${err.message}`);
    }
  }

  /**
   * Get complete location history from tracking events table.
   */
  async getLocationHistory(orderId: string, limit = 50) {
    try {
      return await (this.prisma as any).deliveryTracking.findMany({
        where: { orderId },
        orderBy: { updatedAt: 'desc' },
        take: limit,
      });
    } catch {
      return [];
    }
  }

  /**
   * Get the current delivery assignment for an order (incl. partner details).
   */
  async getOrderDeliveryStatus(orderId: string) {
    const order = await this.prisma.order.findFirst({
      where: { id: orderId },
      select: { id: true, status: true, userId: true },
    });
    if (!order) throw new NotFoundException('Order not found');

    const assignment = await this.prisma.deliveryAssignment.findFirst({
      where: { orderId },
      orderBy: { createdAt: 'desc' },
    });

    const location = await (this.prisma as any).deliveryTracking.findFirst({
      where: { orderId },
      orderBy: { updatedAt: 'desc' },
    });

    return {
      orderId,
      orderStatus: order.status,
      assignment,
      lastKnownLocation: location
        ? { lat: location.lat, lng: location.lng, updatedAt: location.updatedAt }
        : null,
    };
  }
}
