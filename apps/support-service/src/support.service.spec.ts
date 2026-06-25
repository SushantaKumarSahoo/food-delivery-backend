import { Test, TestingModule } from '@nestjs/testing';
import { SupportService } from './support.service';
import { PrismaService } from '@quickbite/prisma';
import { KafkaService } from '@quickbite/common';
import { NotFoundException, ForbiddenException } from '@nestjs/common';

const mockPrisma = {
  platformTenant: { findFirst: jest.fn().mockResolvedValue({ id: 't1' }) },
  supportTicket: { create: jest.fn(), findMany: jest.fn(), findFirst: jest.fn(), update: jest.fn() },
  supportMessage: { create: jest.fn(), findMany: jest.fn() },
  faq: { findMany: jest.fn().mockResolvedValue([]) },
};
const mockKafka = { emit: jest.fn().mockResolvedValue(undefined) };

describe('SupportService', () => {
  let service: SupportService;
  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SupportService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: KafkaService, useValue: mockKafka },
      ],
    }).compile();
    service = module.get<SupportService>(SupportService);
    jest.clearAllMocks();
  });

  it('createTicket creates ticket and emits Kafka event', async () => {
    (mockPrisma as any).supportTicket.create = jest.fn().mockResolvedValue({ id: 'tkt1', ticketNumber: 'TKT-1' });
    const result = await service.createTicket('u1', { subject: 'Help', description: 'Need help' });
    expect(result).toHaveProperty('id', 'tkt1');
    expect(mockKafka.emit).toHaveBeenCalled();
  });

  it('getTicket throws NotFoundException if not found', async () => {
    (mockPrisma as any).supportTicket.findFirst = jest.fn().mockResolvedValue(null);
    await expect(service.getTicket('bad')).rejects.toThrow(NotFoundException);
  });

  it('getTicket throws ForbiddenException if not owned by user', async () => {
    (mockPrisma as any).supportTicket.findFirst = jest.fn().mockResolvedValue({ id: 'tkt1', userId: 'other', messages: [] });
    await expect(service.getTicket('tkt1', 'u1')).rejects.toThrow(ForbiddenException);
  });

  it('updateTicketStatus emits resolved event', async () => {
    (mockPrisma as any).supportTicket.findFirst = jest.fn().mockResolvedValue({ id: 'tkt1', userId: 'u1' });
    (mockPrisma as any).supportTicket.update = jest.fn().mockResolvedValue({ id: 'tkt1', status: 'resolved' });
    const result = await service.updateTicketStatus('tkt1', 'resolved', 'Fixed');
    expect(result.status).toBe('resolved');
    expect(mockKafka.emit).toHaveBeenCalled();
  });

  it('getFaqs returns faq list', async () => {
    (mockPrisma as any).faq.findMany = jest.fn().mockResolvedValue([{ id: 'f1', question: 'How?', answer: 'Yes.' }]);
    const result = await service.getFaqs();
    expect(result).toHaveLength(1);
  });
});
