import { Test, TestingModule } from '@nestjs/testing';
import { OrderService } from './order.service';
import { PrismaService } from '@quickbite/prisma';
import { KafkaService } from '@quickbite/common';
import { NotFoundException } from '@nestjs/common';

const mockPrisma = {
  platformTenant: { findFirst: jest.fn().mockResolvedValue({ id: 't1' }) },
  cartItem: { findMany: jest.fn().mockResolvedValue([]) },
  cart: { findFirst: jest.fn().mockResolvedValue(null) },
  order: { create: jest.fn(), findFirst: jest.fn(), findMany: jest.fn(), updateMany: jest.fn() },
  orderItem: { create: jest.fn(), findMany: jest.fn().mockResolvedValue([]) },
  orderEvent: { findMany: jest.fn().mockResolvedValue([]) },
};
const mockKafka = { emit: jest.fn().mockResolvedValue(undefined) };

describe('OrderService', () => {
  let service: OrderService;
  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrderService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: KafkaService, useValue: mockKafka },
      ],
    }).compile();
    service = module.get<OrderService>(OrderService);
    jest.clearAllMocks();
    mockPrisma.platformTenant.findFirst.mockResolvedValue({ id: 't1' });
  });

  it('createOrder creates order and emits Kafka event', async () => {
    mockPrisma.order.create.mockResolvedValue({ id: 'o1', userId: 'u1', storeId: 's1', merchantId: 'm1', totalAmount: 100, orderNumber: 'QB-1' });
    mockPrisma.orderItem.create.mockResolvedValue({});
    const result = await service.createOrder('u1', { items: [{ productId: 'p1', unitPrice: 100, quantity: 1, totalPrice: 100 }], storeId: 's1', merchantId: 'm1' });
    expect(result).toHaveProperty('id', 'o1');
    expect(mockKafka.emit).toHaveBeenCalled();
  });

  it('getOrder throws NotFoundException for missing order', async () => {
    mockPrisma.order.findFirst.mockResolvedValue(null);
    await expect(service.getOrder('bad')).rejects.toThrow(NotFoundException);
  });

  it('cancelOrder emits ORDER_CANCELLED event', async () => {
    mockPrisma.order.findFirst.mockResolvedValue({ id: 'o1', status: 'created', userId: 'u1' });
    mockPrisma.orderItem.findMany.mockResolvedValue([]);
    mockPrisma.order.updateMany.mockResolvedValue({});
    const result = await service.cancelOrder('o1', 'Changed mind');
    expect(result.message).toBe('Order cancelled');
    expect(mockKafka.emit).toHaveBeenCalled();
  });
});
