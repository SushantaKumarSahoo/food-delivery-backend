import { Test, TestingModule } from '@nestjs/testing';
import { WalletService } from './wallet.service';
import { PrismaService } from '@quickbite/prisma';
import { BadRequestException } from '@nestjs/common';

const mockPrisma = {
  platformTenant: { findFirst: jest.fn().mockResolvedValue({ id: 't1' }) },
  wallet: { findFirst: jest.fn(), create: jest.fn(), update: jest.fn() },
  walletTransaction: { create: jest.fn(), findMany: jest.fn() },
};

describe('WalletService', () => {
  let service: WalletService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [WalletService, { provide: PrismaService, useValue: mockPrisma }],
    }).compile();
    service = module.get<WalletService>(WalletService);
    jest.clearAllMocks();
  });

  it('should be defined', () => expect(service).toBeDefined());

  it('getBalance creates wallet if not exists', async () => {
    (mockPrisma as any).wallet.findFirst = jest.fn().mockResolvedValue(null);
    (mockPrisma as any).wallet.create = jest.fn().mockResolvedValue({ id: 'w1', balance: 0, currency: 'INR' });
    const result = await service.getBalance('u1');
    expect(result).toHaveProperty('balance', 0);
    expect(result).toHaveProperty('currency', 'INR');
  });

  it('topUp throws BadRequestException for zero amount', async () => {
    await expect(service.topUp('u1', 0, 'upi')).rejects.toThrow(BadRequestException);
  });

  it('topUp increases balance', async () => {
    (mockPrisma as any).wallet.findFirst = jest.fn().mockResolvedValue({ id: 'w1', balance: 100, currency: 'INR' });
    (mockPrisma as any).wallet.update = jest.fn().mockResolvedValue({});
    (mockPrisma as any).walletTransaction.create = jest.fn().mockResolvedValue({});
    const result = await service.topUp('u1', 50, 'upi');
    expect(result.balance).toBe(150);
  });

  it('deduct throws BadRequestException for insufficient balance', async () => {
    (mockPrisma as any).wallet.findFirst = jest.fn().mockResolvedValue({ id: 'w1', balance: 10, currency: 'INR' });
    await expect(service.deduct('u1', 100, 'o1')).rejects.toThrow(BadRequestException);
  });

  it('deduct decreases balance successfully', async () => {
    (mockPrisma as any).wallet.findFirst = jest.fn().mockResolvedValue({ id: 'w1', balance: 200, currency: 'INR' });
    (mockPrisma as any).wallet.update = jest.fn().mockResolvedValue({});
    (mockPrisma as any).walletTransaction.create = jest.fn().mockResolvedValue({});
    const result = await service.deduct('u1', 50, 'o1');
    expect(result.balance).toBe(150);
  });

  it('getTransactions returns list', async () => {
    (mockPrisma as any).wallet.findFirst = jest.fn().mockResolvedValue({ id: 'w1', balance: 0, currency: 'INR' });
    (mockPrisma as any).walletTransaction.findMany = jest.fn().mockResolvedValue([{ id: 'tx1' }]);
    const result = await service.getTransactions('u1');
    expect(Array.isArray(result)).toBe(true);
  });
});
