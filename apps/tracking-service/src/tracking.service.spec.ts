import { Test, TestingModule } from '@nestjs/testing';
import { TrackingService } from './tracking.service';
import { PrismaService } from '@quickbite/prisma';
import { NotFoundException } from '@nestjs/common';

const mockPrisma = {
  order: { findFirst: jest.fn() },
  deliveryAssignment: { findFirst: jest.fn() },
  $executeRaw: jest.fn().mockResolvedValue(1),
  deliveryTracking: { findFirst: jest.fn(), findMany: jest.fn(), upsert: jest.fn() },
};

describe('TrackingService', () => {
  let service: TrackingService;
  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [TrackingService, { provide: PrismaService, useValue: mockPrisma }],
    }).compile();
    service = module.get<TrackingService>(TrackingService);
    jest.clearAllMocks();
  });

  it('getLatestLocation throws NotFoundException if no data', async () => {
    (mockPrisma as any).deliveryTracking.findFirst = jest.fn().mockResolvedValue(null);
    await expect(service.getLatestLocation('o1')).rejects.toThrow(NotFoundException);
  });

  it('getLatestLocation returns tracking data', async () => {
    (mockPrisma as any).deliveryTracking.findFirst = jest.fn().mockResolvedValue({ lat: 12.9, lng: 77.6 });
    const result = await service.getLatestLocation('o1');
    expect(result).toHaveProperty('lat', 12.9);
  });

  it('upsertLocation persists location data', async () => {
    (mockPrisma as any).deliveryTracking.upsert = jest.fn().mockResolvedValue({ orderId: 'o1', lat: 12.9, lng: 77.6 });
    const result = await service.upsertLocation({ orderId: 'o1', partnerId: 'dp1', lat: 12.9, lng: 77.6 });
    expect(result).toHaveProperty('lat', 12.9);
  });

  it('getOrderDeliveryStatus throws if order not found', async () => {
    mockPrisma.order.findFirst.mockResolvedValue(null);
    await expect(service.getOrderDeliveryStatus('bad')).rejects.toThrow(NotFoundException);
  });
});
