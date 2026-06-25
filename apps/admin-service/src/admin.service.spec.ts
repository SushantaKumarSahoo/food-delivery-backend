import { Test, TestingModule } from '@nestjs/testing';
import { AdminService } from './admin.service';
import { PrismaService } from '@quickbite/prisma';
import { NotFoundException } from '@nestjs/common';

const mockPrisma = {
  user: { findUnique: jest.fn(), update: jest.fn(), count: jest.fn().mockResolvedValue(10) },
  order: { count: jest.fn().mockResolvedValue(50) },
  merchant: { findMany: jest.fn(), count: jest.fn().mockResolvedValue(5), update: jest.fn() },
  payment: { aggregate: jest.fn().mockResolvedValue({ _sum: { amount: 5000 } }) },
  adminUser: { findMany: jest.fn().mockResolvedValue([]), create: jest.fn() },
  adminRole: { findMany: jest.fn().mockResolvedValue([]) },
  featureFlag: { findMany: jest.fn().mockResolvedValue([]), upsert: jest.fn() },
};

describe('AdminService', () => {
  let service: AdminService;
  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [AdminService, { provide: PrismaService, useValue: mockPrisma }],
    }).compile();
    service = module.get<AdminService>(AdminService);
    jest.clearAllMocks();
  });

  it('should be defined', () => expect(service).toBeDefined());

  it('banUser throws NotFoundException if user not found', async () => {
    mockPrisma.user.findUnique.mockResolvedValue(null);
    await expect(service.banUser('u1', 'spam')).rejects.toThrow(NotFoundException);
  });

  it('banUser updates status to suspended', async () => {
    mockPrisma.user.findUnique.mockResolvedValue({ id: 'u1' });
    mockPrisma.user.update.mockResolvedValue({ id: 'u1', status: 'suspended' });
    const result = await service.banUser('u1', 'spam');
    expect(result.status).toBe('suspended');
  });

  it('getDashboardMetrics returns summary', async () => {
    mockPrisma.user.count.mockResolvedValue(100);
    mockPrisma.order.count.mockResolvedValue(200);
    mockPrisma.merchant.count.mockResolvedValue(20);
    mockPrisma.payment.aggregate.mockResolvedValue({ _sum: { amount: 10000 } });
    const result = await service.getDashboardMetrics();
    expect(result).toHaveProperty('totalUsers');
    expect(result).toHaveProperty('totalRevenue');
  });

  it('getAdminUsers returns list', async () => {
    mockPrisma.adminUser.findMany.mockResolvedValue([{ id: 'a1' }]);
    const result = await service.getAdminUsers();
    expect(Array.isArray(result)).toBe(true);
  });
});
