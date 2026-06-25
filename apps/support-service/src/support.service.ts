import { Injectable, NotFoundException, ForbiddenException, Logger } from '@nestjs/common';
import { PrismaService } from '@quickbite/prisma';
import { KafkaService, KAFKA_TOPICS } from '@quickbite/common';

@Injectable()
export class SupportService {
  private readonly logger = new Logger(SupportService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly kafkaService: KafkaService,
  ) {}

  // ─── Tickets ────────────────────────────────────────────────────────────────

  async createTicket(userId: string, data: {
    subject: string;
    description: string;
    category?: string;
    orderId?: string;
    priority?: string;
  }) {
    const tenant = await this.prisma.platformTenant.findFirst();

    const ticket = await (this.prisma as any).supportTicket.create({
      data: {
        userId,
        tenantId: tenant?.id || 'default-tenant',
        subject: data.subject,
        description: data.description,
        category: data.category || 'general',
        priority: data.priority || 'normal',
        orderId: data.orderId,
        status: 'open',
        ticketNumber: `TKT-${Date.now()}`,
      },
    });

    await this.kafkaService.emit(KAFKA_TOPICS.SUPPORT_TICKET_CREATED, {
      ticketId: ticket.id,
      userId,
      subject: data.subject,
      category: data.category,
    });

    this.logger.log(`Support ticket created: ${ticket.ticketNumber} for user ${userId}`);
    return ticket;
  }

  async getUserTickets(userId: string, status?: string) {
    return (this.prisma as any).supportTicket.findMany({
      where: {
        userId,
        ...(status ? { status } : {}),
      },
      include: { messages: { orderBy: { createdAt: 'asc' }, take: 1 } },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getAllTickets(status?: string, priority?: string) {
    return (this.prisma as any).supportTicket.findMany({
      where: {
        ...(status ? { status } : {}),
        ...(priority ? { priority } : {}),
      },
      include: {
        messages: { orderBy: { createdAt: 'desc' }, take: 1 },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getTicket(ticketId: string, userId?: string) {
    const ticket = await (this.prisma as any).supportTicket.findFirst({
      where: { id: ticketId },
      include: { messages: { orderBy: { createdAt: 'asc' } } },
    });
    if (!ticket) throw new NotFoundException('Ticket not found');

    // If userId provided (customer), only allow access to their own tickets
    if (userId && ticket.userId !== userId) {
      throw new ForbiddenException('Access denied to this ticket');
    }

    return ticket;
  }

  async updateTicketStatus(ticketId: string, status: string, resolution?: string) {
    const ticket = await (this.prisma as any).supportTicket.findFirst({
      where: { id: ticketId },
    });
    if (!ticket) throw new NotFoundException('Ticket not found');

    const updated = await (this.prisma as any).supportTicket.update({
      where: { id: ticketId },
      data: {
        status,
        ...(resolution ? { resolution } : {}),
        ...(status === 'resolved' ? { resolvedAt: new Date() } : {}),
        ...(status === 'closed' ? { closedAt: new Date() } : {}),
      },
    });

    if (status === 'resolved') {
      await this.kafkaService.emit(KAFKA_TOPICS.SUPPORT_TICKET_RESOLVED, {
        ticketId,
        userId: ticket.userId,
        resolution,
      });
    }

    return updated;
  }

  // ─── Messages ───────────────────────────────────────────────────────────────

  async addMessage(ticketId: string, senderId: string, data: {
    message: string;
    senderType?: 'customer' | 'agent' | 'system';
    attachmentUrl?: string;
  }) {
    const ticket = await (this.prisma as any).supportTicket.findFirst({
      where: { id: ticketId },
    });
    if (!ticket) throw new NotFoundException('Ticket not found');

    // Re-open ticket if customer replies to a resolved ticket
    if (ticket.status === 'resolved' && data.senderType === 'customer') {
      await (this.prisma as any).supportTicket.update({
        where: { id: ticketId },
        data: { status: 'open' },
      });
    }

    const msg = await (this.prisma as any).supportMessage.create({
      data: {
        ticketId,
        senderId,
        senderType: data.senderType || 'customer',
        message: data.message,
        attachmentUrl: data.attachmentUrl,
      },
    });

    // Update ticket's updatedAt
    await (this.prisma as any).supportTicket.update({
      where: { id: ticketId },
      data: { updatedAt: new Date() },
    });

    return msg;
  }

  async getTicketMessages(ticketId: string) {
    return (this.prisma as any).supportMessage.findMany({
      where: { ticketId },
      orderBy: { createdAt: 'asc' },
    });
  }

  // ─── FAQ ────────────────────────────────────────────────────────────────────

  async getFaqs(category?: string) {
    return (this.prisma as any).faq.findMany({
      where: {
        isPublished: true,
        ...(category ? { category } : {}),
      },
      orderBy: { sortOrder: 'asc' },
    });
  }
}
