import { Test, TestingModule } from '@nestjs/testing';
import { PaymentService } from './payment.service';
import { PrismaService } from '@quickbite/prisma';
import { KafkaService } from '@quickbite/common';
import { NotFoundException } from '@nestjs/common';

// Mock Stripe as a class (default export, ESM-style)
const mockStripeInstance = {
  paymentIntents: {
    create: jest.fn().mockResolvedValue({ id: 'pi_mock', client_secret: 'cs_mock' }),
  },
  refunds: {
    create: jest.fn().mockResolvedValue({ id: 'ref_mock' }),
  },
};
jest.mock('stripe', () => {
  const StripeMock = jest.fn().mockImplementation(() => mockStripeInstance);
  return { __esModule: true, default: StripeMock };
});

const mockPrisma = {
  order: { findFirst: jest.fn(), updateMany: jest.fn() },
  payment: { create: jest.fn(), findFirst: jest.fn(), updateMany: jest.fn(), findMany: jest.fn() },
};
const mockKafka = { emit: jest.fn().mockResolvedValue(undefined) };

describe('PaymentService', () => {
  let service: PaymentService;

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PaymentService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: KafkaService, useValue: mockKafka },
      ],
    }).compile();
    service = module.get<PaymentService>(PaymentService);
  });

  it('should be defined', () => expect(service).toBeDefined());

  it('initiatePayment throws NotFoundException if order not found', async () => {
    mockPrisma.order.findFirst.mockResolvedValue(null);
    await expect(service.initiatePayment('bad', {})).rejects.toThrow(NotFoundException);
  });

  it('initiatePayment returns clientSecret for stripe', async () => {
    mockPrisma.order.findFirst.mockResolvedValue({ id: 'o1', userId: 'u1', tenantId: 't1', totalAmount: 200 });
    mockPrisma.payment.create.mockResolvedValue({ id: 'pay1' });
    mockStripeInstance.paymentIntents.create.mockResolvedValue({ id: 'pi_mock', client_secret: 'cs_mock' });
    const result = await service.initiatePayment('o1', { methodType: 'card' });
    expect(result).toHaveProperty('clientSecret', 'cs_mock');
  });

  it('processWebhook handles payment_intent.succeeded', async () => {
    mockPrisma.payment.findFirst.mockResolvedValue({ id: 'pay1', orderId: 'o1', userId: 'u1', amount: 200 });
    mockPrisma.payment.updateMany.mockResolvedValue({});
    mockPrisma.order.updateMany.mockResolvedValue({});
    const result = await service.processWebhook({
      type: 'payment_intent.succeeded',
      data: { object: { id: 'pi_mock' } },
    });
    expect(result.status).toBe('success');
    expect(mockKafka.emit).toHaveBeenCalled();
  });

  it('getPaymentStatus throws for missing payment', async () => {
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    await expect(service.getPaymentStatus('bad')).rejects.toThrow(NotFoundException);
  });

  it('getPaymentStatus returns payment for valid id', async () => {
    mockPrisma.payment.findFirst.mockResolvedValue({ id: 'pay1', status: 'success' });
    const result = await service.getPaymentStatus('pay1');
    expect(result).toHaveProperty('id', 'pay1');
  });

  it('getOrderPayments returns list', async () => {
    mockPrisma.payment.findMany.mockResolvedValue([{ id: 'pay1' }]);
    const result = await service.getOrderPayments('o1');
    expect(Array.isArray(result)).toBe(true);
  });
});
