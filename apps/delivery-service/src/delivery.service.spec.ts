import { Test, TestingModule } from '@nestjs/testing';
import { DeliveryService } from './delivery.service';
import { PrismaService } from '@quickbite/prisma';
import { KafkaService } from '@quickbite/common';
import { NotFoundException } from '@nestjs/common';

const mockPrisma = {
  platformTenant: { findFirst: jest.fn().mockResolvedValue({ id: 't1' }) },
  deliveryPartner: { create: jest.fn(), findMany: jest.fn(), findFirst: jest.fn(), update: jest.fn() },
  deliveryAssignment: { create: jest.fn(), findFirst: jest.fn(), update: jest.fn() },
  order: { findFirst: jest.fn(), updateMany: jest.fn() },
  $queryRaw: jest.fn().mockResolvedValue([]),
};
const mockKafka = { emit: jest.fn().mockResolvedValue(undefined) };

describe('DeliveryService', () => {
  let service: DeliveryService;
  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DeliveryService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: KafkaService, useValue: mockKafka },
      ],
    }).compile();
    service = module.get<DeliveryService>(DeliveryService);
    jest.clearAllMocks();
    mockPrisma.platformTenant.findFirst.mockResolvedValue({ id: 't1' });
  });

  it('registerPartner creates a partner record', async () => {
    mockPrisma.deliveryPartner.create.mockResolvedValue({ id: 'dp1' });
    const result = await service.registerPartner({ userId: 'u1', fullName: 'Ali Khan', phoneNumber: '+91999' });
    expect(result).toHaveProperty('partnerId', 'dp1');
  });

  it('assignPartner throws if order not found', async () => {
    mockPrisma.order.findFirst.mockResolvedValue(null);
    await expect(service.assignPartner('bad', 'dp1')).rejects.toThrow(NotFoundException);
  });

  it('assignPartner throws if partner not available', async () => {
    mockPrisma.order.findFirst.mockResolvedValue({ id: 'o1' });
    mockPrisma.deliveryPartner.findFirst.mockResolvedValue(null);
    await expect(service.assignPartner('o1', 'dp1')).rejects.toThrow(NotFoundException);
  });

  it('assignPartner creates assignment and emits Kafka event', async () => {
    mockPrisma.order.findFirst.mockResolvedValue({ id: 'o1', storeId: 's1' });
    mockPrisma.deliveryPartner.findFirst.mockResolvedValue({ id: 'dp1', firstName: 'Ali', lastName: 'Khan', phone: '+91999', status: 'available' });
    mockPrisma.deliveryAssignment.create.mockResolvedValue({ id: 'da1', estimatedDurationMin: 25, orderId: 'o1', partnerId: 'dp1' });
    mockPrisma.deliveryPartner.update.mockResolvedValue({});
    mockPrisma.order.updateMany.mockResolvedValue({});
    const result = await service.assignPartner('o1', 'dp1');
    expect(result).toHaveProperty('id', 'da1');
    expect(mockKafka.emit).toHaveBeenCalled();
  });
});
