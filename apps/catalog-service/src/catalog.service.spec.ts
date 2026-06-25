import { Test, TestingModule } from '@nestjs/testing';
import { CatalogService } from './catalog.service';
import { PrismaService } from '@quickbite/prisma';
import { NotFoundException } from '@nestjs/common';

// Mock ioredis as a constructor (default export)
const mockRedisInstance = {
  get: jest.fn().mockResolvedValue(null),
  set: jest.fn().mockResolvedValue('OK'),
  del: jest.fn().mockResolvedValue(1),
  on: jest.fn(),
};
jest.mock('ioredis', () => {
  const RedisMock = jest.fn().mockImplementation(() => mockRedisInstance);
  return { __esModule: true, default: RedisMock };
});

const mockPrisma = {
  vertical: { findMany: jest.fn(), create: jest.fn() },
  category: { findMany: jest.fn(), create: jest.fn() },
  product: { findMany: jest.fn(), findUnique: jest.fn(), create: jest.fn(), update: jest.fn() },
  addOnGroup: { findMany: jest.fn(), create: jest.fn() },
};

describe('CatalogService', () => {
  let service: CatalogService;

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      providers: [CatalogService, { provide: PrismaService, useValue: mockPrisma }],
    }).compile();
    service = module.get<CatalogService>(CatalogService);
  });

  it('should be defined', () => expect(service).toBeDefined());

  it('getVerticals fetches from DB when cache is empty', async () => {
    mockRedisInstance.get.mockResolvedValueOnce(null);
    mockPrisma.vertical.findMany.mockResolvedValue([{ id: 'v1', name: 'Food', isActive: true }]);
    const result = await service.getVerticals();
    expect(result).toHaveLength(1);
  });

  it('getVerticals returns cached data when available', async () => {
    mockRedisInstance.get.mockResolvedValueOnce(JSON.stringify([{ id: 'v1', name: 'Food' }]));
    const result = await service.getVerticals();
    expect(result).toHaveLength(1);
    expect(mockPrisma.vertical.findMany).not.toHaveBeenCalled();
  });

  it('getProductDetails throws NotFoundException if product missing', async () => {
    mockRedisInstance.get.mockResolvedValueOnce(null);
    mockPrisma.product.findUnique.mockResolvedValue(null);
    await expect(service.getProductDetails('bad')).rejects.toThrow(NotFoundException);
  });

  it('getProductsByStore returns products list', async () => {
    mockRedisInstance.get.mockResolvedValueOnce(null);
    mockPrisma.product.findMany.mockResolvedValue([{ id: 'p1', name: 'Burger' }]);
    const result = await service.getProductsByStore('s1');
    expect(result).toHaveLength(1);
  });

  it('createProduct invalidates cache and returns product', async () => {
    mockPrisma.product.create.mockResolvedValue({ id: 'p1', storeId: 's1' });
    const result = await service.createProduct({ name: 'Pizza', storeId: 's1' });
    expect(result).toHaveProperty('id', 'p1');
    expect(mockRedisInstance.del).toHaveBeenCalled();
  });
});
