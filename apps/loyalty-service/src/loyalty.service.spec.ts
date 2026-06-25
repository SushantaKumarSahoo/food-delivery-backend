import { Test, TestingModule } from '@nestjs/testing';
import { LoyaltyService } from './loyalty.service';
import { PrismaService } from '@quickbite/prisma';
import { BadRequestException } from '@nestjs/common';

const mockPrisma = {
  platformTenant: { findFirst: jest.fn().mockResolvedValue({ id: 't1' }) },
  loyaltyWallet: { findFirst: jest.fn(), create: jest.fn(), update: jest.fn() },
  loyaltyTransaction: { create: jest.fn() },
  coupon: { findMany: jest.fn(), findFirst: jest.fn() },
};

describe('LoyaltyService', () => {
  let service: LoyaltyService;
  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [LoyaltyService, { provide: PrismaService, useValue: mockPrisma }],
    }).compile();
    service = module.get<LoyaltyService>(LoyaltyService);
    jest.clearAllMocks();
  });

  it('getPointsBalance creates wallet if not exists', async () => {
    (mockPrisma as any).loyaltyWallet.findFirst = jest.fn().mockResolvedValue(null);
    (mockPrisma as any).loyaltyWallet.create = jest.fn().mockResolvedValue({ id: 'lw1', balance: 0, lifetimeEarned: 0 });
    const result = await service.getPointsBalance('u1');
    expect(result).toHaveProperty('tier', 'bronze');
  });

  it('redeemPoints throws if insufficient balance', async () => {
    (mockPrisma as any).loyaltyWallet.findFirst = jest.fn().mockResolvedValue({ id: 'lw1', balance: 10, lifetimeEarned: 10 });
    await expect(service.redeemPoints('u1', 100)).rejects.toThrow(BadRequestException);
  });

  it('handleOrderCompleted awards points', async () => {
    (mockPrisma as any).loyaltyWallet.findFirst = jest.fn().mockResolvedValue({ id: 'lw1', balance: 0, lifetimeEarned: 0 });
    (mockPrisma as any).loyaltyWallet.update = jest.fn().mockResolvedValue({});
    (mockPrisma as any).loyaltyTransaction.create = jest.fn().mockResolvedValue({});
    await service.handleOrderCompleted({ userId: 'u1', orderId: 'o1', totalAmount: 200 });
    expect((mockPrisma as any).loyaltyWallet.update).toHaveBeenCalled();
  });
});
