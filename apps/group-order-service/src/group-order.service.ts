import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '@quickbite/prisma';
import { v4 as uuidv4 } from 'uuid';

@Injectable()
export class GroupOrderService {
  constructor(private readonly prisma: PrismaService) {}

  async createSession(hostUserId: string, data: any) {
    const tenant = await this.prisma.platformTenant.findFirst();
    const inviteCode = uuidv4().substring(0, 8).toUpperCase();

    const session = await this.prisma.groupOrder.create({
      data: {
        createdByUserId: hostUserId,
        tenantId: tenant?.id || 'default-tenant',
        storeId: data.storeId,
        inviteCode,
        status: 'open',
        maxMembers: data.maxParticipants || 10,
        orderDeadline: new Date(Date.now() + 30 * 60 * 1000), // 30 min
      },
    });

    // Add host as first participant
    await this.prisma.groupMember.create({
      data: {
        groupOrderId: session.id,
        userId: hostUserId,
        role: 'host',
      },
    });

    return session;
  }

  async getSession(sessionId: string) {
    const session = await this.prisma.groupOrder.findFirst({
      where: { id: sessionId },
      include: {
        members: true,
        cartItems: true,
      },
    });
    if (!session) throw new NotFoundException('Group order session not found');
    return session;
  }

  async joinSession(inviteCode: string, userId: string) {
    const session = await this.prisma.groupOrder.findFirst({
      where: { inviteCode, status: 'open' },
      include: { members: true },
    });
    if (!session) throw new NotFoundException('Invalid invite code or session expired');

    if (session.orderDeadline && new Date() > session.orderDeadline) {
      throw new BadRequestException('Session has expired');
    }

    const alreadyJoined = session.members.some(
      (p: any) => p.userId === userId,
    );
    if (alreadyJoined) return { message: 'Already in session', session };

    await this.prisma.groupMember.create({
      data: {
        groupOrderId: session.id,
        userId,
        role: 'member',
      },
    });

    return { message: 'Joined session', sessionId: session.id };
  }

  async addItems(sessionId: string, userId: string, items: any[]) {
    const session = await this.getSession(sessionId);
    if (session.status !== 'open') {
      throw new BadRequestException('Session is not open');
    }

    const member = await this.prisma.groupMember.findFirst({
      where: { groupOrderId: sessionId, userId }
    });
    if (!member) throw new BadRequestException('User is not a member of this session');

    const created = [];
    for (const item of items) {
      const record = await this.prisma.groupCartItem.create({
        data: {
          groupOrderId: sessionId,
          memberId: member.id,
          userId,
          productId: item.productId,
          quantity: item.quantity || 1,
          unitPrice: item.price || 0,
        },
      });
      created.push(record);
    }
    return created;
  }

  async checkout(sessionId: string, hostUserId: string) {
    const session = await this.getSession(sessionId);
    if (session.createdByUserId !== hostUserId) {
      throw new BadRequestException('Only the host can checkout');
    }

    if (session.cartItems.length === 0) {
      throw new BadRequestException('No items in the group order');
    }

    // Calculate total
    const total = session.cartItems.reduce(
      (sum: number, i: any) => sum + Number(i.unitPrice) * i.quantity,
      0,
    );

    // Mark session as checked out
    await this.prisma.groupOrder.update({
      where: { id: sessionId },
      data: { status: 'checked_out' },
    });

    return {
      message: 'Group order checked out',
      sessionId,
      totalAmount: total,
      itemCount: session.cartItems.length,
      participantCount: session.members.length,
    };
  }
}
