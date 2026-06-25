import { Test, TestingModule } from '@nestjs/testing';
import { CartService } from './cart.service';
import { PrismaService } from '@quickbite/prisma';
import { BadRequestException, NotFoundException } from '@nestjs/common';

const mockPrisma = {
  cart: { findFirst: jest.fn(), create: jest.fn(), update: jest.fn() },
  cartItem: { findFirst: jest.fn(), create: jest.fn(), update: jest.fn(), delete: jest.fn(), deleteMany: jest.fn(), findMany: jest.fn() },
  platformTenant: { findFirst: jest.fn().mockResolvedValue({ id: 't1' }) },
  coupon: { findFirst: jest.fn() },
};

describe('CartService', () => {
  let service: CartService;
  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [CartService, { provide: PrismaService, useValue: mockPrisma }],
    }).compile();
    service = module.get<CartService>(CartService);
    jest.clearAllMocks();
    mockPrisma.platformTenant.findFirst.mockResolvedValue({ id: 't1' });
  });

  it('getCart creates new cart when none exists and storeId provided', async () => {
    mockPrisma.cart.findFirst.mockResolvedValue(null);
    mockPrisma.cart.create.mockResolvedValue({ id: 'c1', storeId: 's1', items: [] });
    const result = await service.getCart('u1', 's1');
    expect(result).toHaveProperty('id', 'c1');
  });

  it('getCart throws BadRequestException if no storeId for new cart', async () => {
    mockPrisma.cart.findFirst.mockResolvedValue(null);
    await expect(service.getCart('u1')).rejects.toThrow(BadRequestException);
  });

  it('addItem increments quantity if product already in cart', async () => {
    mockPrisma.cart.findFirst.mockResolvedValue({ id: 'c1', storeId: 's1', items: [] });
    mockPrisma.cartItem.findFirst.mockResolvedValue({ id: 'ci1', quantity: 1 });
    mockPrisma.cartItem.update.mockResolvedValue({ id: 'ci1', quantity: 2 });
    const result = await service.addItem('u1', { storeId: 's1', productId: 'p1', quantity: 1, price: 100 });
    expect(result).toHaveProperty('quantity', 2);
  });

  it('clearCart removes all cart items', async () => {
    mockPrisma.cart.findFirst.mockResolvedValue({ id: 'c1' });
    mockPrisma.cartItem.deleteMany.mockResolvedValue({});
    const result = await service.clearCart('u1');
    expect(result.message).toBe('Cart cleared');
  });
});
