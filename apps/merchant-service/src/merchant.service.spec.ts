import { Test, TestingModule } from '@nestjs/testing';
import { MerchantService } from './merchant.service';
import { PrismaService } from '@quickbite/prisma';
import { NotFoundException } from '@nestjs/common';

const mockPrisma = {
  merchant: {
    create: jest.fn(),
    findMany: jest.fn(),
    findUnique: jest.fn(),
    update: jest.fn(),
    count: jest.fn(),
  },
  store: {
    create: jest.fn(),
    findFirst: jest.fn(),
    findMany: jest.fn(),
    update: jest.fn(),
  },
  platformTenant: { findFirst: jest.fn().mockResolvedValue({ id: 't1' }) },
  storeHour: { findMany: jest.fn().mockResolvedValue([]), deleteMany: jest.fn(), createMany: jest.fn() },
};

describe('MerchantService', () => {
  let service: MerchantService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [MerchantService, { provide: PrismaService, useValue: mockPrisma }],
    }).compile();
    service = module.get<MerchantService>(MerchantService);
    jest.clearAllMocks();
  });

  it('should be defined', () => expect(service).toBeDefined());

  it('onboardMerchant creates merchant record', async () => {
    mockPrisma.merchant.create.mockResolvedValue({ id: 'm1', status: 'pending', brandName: 'Test Biz' });
    const result = await service.onboardMerchant('t1', 'u1', { businessName: 'Test Biz', businessType: 'restaurant' });
    expect(result).toHaveProperty('id', 'm1');
    expect(mockPrisma.merchant.create).toHaveBeenCalled();
  });

  it('getMerchant returns merchant', async () => {
    mockPrisma.merchant.findUnique.mockResolvedValue({ id: 'm1', stores: [], bankAccounts: [] });
    const result = await service.getMerchant('m1');
    expect(result).toHaveProperty('id', 'm1');
  });

  it('getMerchant throws NotFoundException if not found', async () => {
    mockPrisma.merchant.findUnique.mockResolvedValue(null);
    await expect(service.getMerchant('bad')).rejects.toThrow(NotFoundException);
  });

  it('listMerchants returns array', async () => {
    mockPrisma.merchant.findMany.mockResolvedValue([{ id: 'm1' }]);
    const result = await service.listMerchants();
    expect(Array.isArray(result)).toBe(true);
  });

  it('approveMerchant updates status to approved', async () => {
    mockPrisma.merchant.findUnique.mockResolvedValue({ id: 'm1', stores: [], bankAccounts: [] });
    mockPrisma.merchant.update.mockResolvedValue({ id: 'm1', status: 'approved' });
    const result = await service.approveMerchant('m1');
    expect(result.status).toBe('approved');
  });

  it('getStoresByMerchant returns stores', async () => {
    mockPrisma.store.findMany.mockResolvedValue([{ id: 's1' }]);
    const result = await service.getStoresByMerchant('m1');
    expect(Array.isArray(result)).toBe(true);
  });

  it('updateStore throws NotFoundException if store not in merchant', async () => {
    mockPrisma.store.findFirst.mockResolvedValue(null);
    await expect(service.updateStore('m1', 'bad', {})).rejects.toThrow(NotFoundException);
  });
});
