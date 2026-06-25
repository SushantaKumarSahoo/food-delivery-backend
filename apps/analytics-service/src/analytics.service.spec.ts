import { Test, TestingModule } from '@nestjs/testing';
import { AnalyticsService } from './analytics.service';
import { PrismaService } from '@quickbite/prisma';

const mockPrisma = {
  order: { findMany: jest.fn().mockResolvedValue([]) },
  payment: { aggregate: jest.fn().mockResolvedValue({ _sum: { amount: 0 } }) },
  orderItem: { groupBy: jest.fn().mockResolvedValue([]) },
  user: { count: jest.fn().mockResolvedValue(5) },
};

describe('AnalyticsService', () => {
  let service: AnalyticsService;
  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [AnalyticsService, { provide: PrismaService, useValue: mockPrisma }],
    }).compile();
    service = module.get<AnalyticsService>(AnalyticsService);
    jest.clearAllMocks();
  });

  it('getOrderSummary returns summary object', async () => {
    mockPrisma.order.findMany.mockResolvedValue([{ status: 'delivered', totalAmount: 200, paymentStatus: 'paid', createdAt: new Date() }]);
    const result = await service.getOrderSummary(new Date(Date.now() - 86400000), new Date());
    expect(result).toHaveProperty('total', 1);
    expect(result).toHaveProperty('revenue', 200);
  });

  it('getUserCohorts returns user counts', async () => {
    mockPrisma.user.count.mockResolvedValue(10);
    const result = await service.getUserCohorts();
    expect(result).toHaveProperty('totalUsers');
  });

  it('getTopSellingProducts returns products list', async () => {
    mockPrisma.orderItem.groupBy.mockResolvedValue([{ productId: 'p1', productName: 'Burger', _sum: { quantity: 50 } }]);
    const result = await service.getTopSellingProducts(5);
    expect(result).toHaveLength(1);
  });
});
