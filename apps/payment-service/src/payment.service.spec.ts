import { Test, TestingModule } from '@nestjs/testing';
import { PaymentService } from './payment.service';
import { PrismaService } from '@quickbite/prisma';
import { KafkaService } from '@quickbite/common';
import { NotFoundException } from '@nestjs/common';
import { Cashfree, CFEnvironment } from 'cashfree-pg';

// Mock Cashfree
jest.mock('cashfree-pg', () => {
  return {
    CFEnvironment: {
      SANDBOX: 1,
      PRODUCTION: 2
    },
    Cashfree: jest.fn().mockImplementation(() => {
      return {
        PGCreateOrder: jest.fn().mockResolvedValue({
          data: { payment_session_id: 'cf_session_mock' }
        }),
        PGVerifyWebhookSignature: jest.fn(),
        PGFetchOrder: jest.fn().mockResolvedValue({
          data: { order_status: 'PAID' }
        }),
        PGOrderCreateRefund: jest.fn().mockResolvedValue({
          data: { refund_id: 'ref_mock' }
        })
      };
    })
  };
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

  it('initiatePayment returns paymentSessionId for cashfree', async () => {
    mockPrisma.order.findFirst.mockResolvedValue({ id: 'o1', userId: 'u1', tenantId: 't1', totalAmount: 200 });
    mockPrisma.payment.create.mockResolvedValue({ id: 'pay1' });
    const result = await service.initiatePayment('o1', { methodType: 'upi' });
    expect(result).toHaveProperty('paymentSessionId', 'cf_session_mock');
    expect(result).toHaveProperty('cfOrderId');
  });

  it('processWebhook handles SUCCESS', async () => {
    mockPrisma.payment.findFirst.mockResolvedValue({ id: 'pay1', orderId: 'o1', userId: 'u1', amount: 200 });
    mockPrisma.payment.updateMany.mockResolvedValue({});
    mockPrisma.order.updateMany.mockResolvedValue({});
    
    const rawBody = JSON.stringify({
      data: {
        order: { order_id: 'cf_order_mock' },
        payment: { payment_status: 'SUCCESS' }
      }
    });

    const result = await service.processWebhook(rawBody, 'mock_signature', 'mock_timestamp');
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
