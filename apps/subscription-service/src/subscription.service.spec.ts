import { Test, TestingModule } from '@nestjs/testing';
import { SubscriptionService } from './subscription.service';
import { PrismaService } from '@quickbite/prisma';
import { KafkaService } from '@quickbite/common';
import { NotFoundException, BadRequestException } from '@nestjs/common';

const mockPrisma = {
  subscriptionPlan: { findMany: jest.fn(), findFirst: jest.fn() },
  userSubscription: { findFirst: jest.fn(), create: jest.fn(), update: jest.fn(), findMany: jest.fn() },
};
const mockKafka = { emit: jest.fn().mockResolvedValue(undefined) };

describe('SubscriptionService', () => {
  let service: SubscriptionService;
  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SubscriptionService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: KafkaService, useValue: mockKafka },
      ],
    }).compile();
    service = module.get<SubscriptionService>(SubscriptionService);
    jest.clearAllMocks();
  });

  it('getPlans returns active plans', async () => {
    (mockPrisma as any).subscriptionPlan.findMany = jest.fn().mockResolvedValue([{ id: 'p1', name: 'Gold' }]);
    const result = await service.getPlans();
    expect(result).toHaveLength(1);
  });

  it('subscribe throws if plan not found', async () => {
    (mockPrisma as any).subscriptionPlan.findFirst = jest.fn().mockResolvedValue(null);
    (mockPrisma as any).userSubscription.findFirst = jest.fn().mockResolvedValue(null);
    await expect(service.subscribe('u1', 'bad')).rejects.toThrow(NotFoundException);
  });

  it('subscribe throws if already subscribed', async () => {
    (mockPrisma as any).subscriptionPlan.findFirst = jest.fn().mockResolvedValue({ id: 'p1', durationDays: 30 });
    (mockPrisma as any).userSubscription.findFirst = jest.fn().mockResolvedValue({ id: 'sub1', status: 'active' });
    await expect(service.subscribe('u1', 'p1')).rejects.toThrow(BadRequestException);
  });

  it('subscribe creates subscription and emits event', async () => {
    (mockPrisma as any).subscriptionPlan.findFirst = jest.fn().mockResolvedValue({ id: 'p1', durationDays: 30, name: 'Gold', isActive: true });
    (mockPrisma as any).userSubscription.findFirst = jest.fn().mockResolvedValue(null);
    (mockPrisma as any).userSubscription.create = jest.fn().mockResolvedValue({ id: 'sub1' });
    const result = await service.subscribe('u1', 'p1');
    expect(result).toHaveProperty('id', 'sub1');
    expect(mockKafka.emit).toHaveBeenCalled();
  });
});
