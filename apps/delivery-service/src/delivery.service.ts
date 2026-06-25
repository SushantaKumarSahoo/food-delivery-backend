import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '@quickbite/prisma';
import { KafkaService, KAFKA_TOPICS } from '@quickbite/common';

@Injectable()
export class DeliveryService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly kafkaService: KafkaService,
  ) {}

  async registerPartner(data: any) {
    const tenant = await this.prisma.platformTenant.findFirst();
    const partner = await this.prisma.deliveryPartner.create({
      data: {
        tenantId: tenant?.id || 'default-tenant',
        userId: data.userId,
        firstName: data.fullName.split(' ')[0],
        lastName: data.fullName.split(' ').slice(1).join(' ') || '',
        phone: data.phoneNumber,
        partnerCode: `DP-${Math.floor(1000 + Math.random() * 9000)}`,
        status: 'available',
      },
    });

    return { message: 'Delivery partner registered', partnerId: partner.id };
  }

  async listPartners(status?: string) {
    return this.prisma.deliveryPartner.findMany({
      where: status ? { status } : undefined,
    });
  }

  async assignPartner(orderId: string, partnerId: string) {
    const order = await this.prisma.order.findFirst({ where: { id: orderId } });
    if (!order) throw new NotFoundException('Order not found');

    const partner = await this.prisma.deliveryPartner.findFirst({
      where: { id: partnerId, status: 'available' },
    });
    if (!partner) throw new NotFoundException('Partner not available');

    const assignment = await this.prisma.deliveryAssignment.create({
      data: {
        orderId,
        partnerId,
        status: 'accepted',
        estimatedDistanceKm: 7.5,
        estimatedDurationMin: 25,
      },
    });

    // Mark partner as busy
    await this.prisma.deliveryPartner.update({
      where: { id: partnerId },
      data: { status: 'on_delivery' },
    });

    // Update order status
    await this.prisma.order.updateMany({
      where: { id: orderId },
      data: { status: 'driver_assigned' },
    });

    // Publish Kafka event
    await this.kafkaService.emit(KAFKA_TOPICS.DELIVERY_ASSIGNED, {
      assignmentId: assignment.id,
      orderId,
      partnerId,
      partnerName: `${partner.firstName} ${partner.lastName}`,
      phone: partner.phone,
      estimatedDurationMin: assignment.estimatedDurationMin,
    });

    return assignment;
  }

  async autoAssignPartner(orderId: string) {
    const order = await this.prisma.order.findFirst({ where: { id: orderId } });
    if (!order) throw new NotFoundException('Order not found');

    // Use PostGIS raw query to find nearest available online partner
    // We join the stores table to get the store's geography point
    const nearestPartners: any[] = await this.prisma.$queryRaw`
      SELECT dp.id, 
             ST_Distance(dp.current_location, s.location) as distance_meters
      FROM delivery_partners dp, stores s
      WHERE s.id = ${order.storeId}::uuid
        AND dp.status = 'available'
        AND dp.is_online = true
        AND dp.current_location IS NOT NULL
        AND s.location IS NOT NULL
      ORDER BY dp.current_location <-> s.location
      LIMIT 1
    `;

    if (!nearestPartners || nearestPartners.length === 0) {
      // Fallback: just get any available partner if no location data
      const fallbackPartner = await this.prisma.deliveryPartner.findFirst({
        where: { status: 'available' },
      });
      if (!fallbackPartner) {
        return { message: 'No partner available, order queued' };
      }
      return this.assignPartner(orderId, fallbackPartner.id);
    }

    const bestPartner = nearestPartners[0];
    return this.assignPartner(orderId, bestPartner.id);
  }

  async updateDeliveryStatus(assignmentId: string, status: string) {
    const assignment = await this.prisma.deliveryAssignment.findFirst({
      where: { id: assignmentId },
    });
    if (!assignment) throw new NotFoundException('Assignment not found');

    await this.prisma.deliveryAssignment.update({
      where: { id: assignmentId },
      data: {
        status,
        pickedUpAt: status === 'picked_up' ? new Date() : undefined,
        deliveredAt: status === 'delivered' ? new Date() : undefined,
      } as any,
    });

    // Free up partner if delivered
    if (status === 'delivered' || status === 'failed') {
      await this.prisma.deliveryPartner.update({
        where: { id: assignment.partnerId },
        data: { status: 'available' },
      });

      if (status === 'delivered') {
        await this.kafkaService.emit(KAFKA_TOPICS.DELIVERY_COMPLETED, {
          assignmentId,
          orderId: assignment.orderId,
          partnerId: assignment.partnerId,
        });
      }
    }

    await this.kafkaService.emit(KAFKA_TOPICS.DELIVERY_STATUS_UPDATED, {
      assignmentId,
      orderId: assignment.orderId,
      status,
    });

    return { message: 'Status updated', status };
  }

  async getAssignment(assignmentId: string) {
    const a = await this.prisma.deliveryAssignment.findFirst({
      where: { id: assignmentId },
    });
    if (!a) throw new NotFoundException('Assignment not found');
    return a;
  }

  async getOrderAssignment(orderId: string) {
    return this.prisma.deliveryAssignment.findFirst({
      where: { orderId },
      orderBy: { createdAt: 'desc' },
    });
  }
}
