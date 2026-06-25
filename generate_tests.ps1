$baseDir = "c:\Users\HP\OneDrive\Desktop\ongoing\food delivery backend\apps"

# ─── AUTH SERVICE ────────────────────────────────────────────────────────────
Set-Content -Path "$baseDir\auth-service\src\auth.service.spec.ts" -Encoding UTF8 -Value @'
import { Test, TestingModule } from '@nestjs/testing';
import { AuthService } from './auth.service';
import { PrismaService } from '@quickbite/prisma';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { ConflictException, UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcryptjs';

const mockPrisma = {
  user: { findFirst: jest.fn(), findUnique: jest.fn(), create: jest.fn(), update: jest.fn() },
  platformTenant: { findFirst: jest.fn() },
  customerProfile: { create: jest.fn() },
  otpVerification: { upsert: jest.fn(), findUnique: jest.fn(), update: jest.fn(), delete: jest.fn() },
};

const mockJwt = { sign: jest.fn().mockReturnValue('mock_token'), verify: jest.fn() };
const mockConfig = { get: jest.fn((key: string) => {
  const map: any = { NODE_ENV: 'development', JWT_SECRET: 'secret', JWT_REFRESH_SECRET: 'refresh', JWT_EXPIRES_IN: '60m', JWT_REFRESH_EXPIRES_IN: '7d' };
  return map[key];
}) };

describe('AuthService', () => {
  let service: AuthService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: JwtService, useValue: mockJwt },
        { provide: ConfigService, useValue: mockConfig },
      ],
    }).compile();
    service = module.get<AuthService>(AuthService);
    jest.clearAllMocks();
  });

  describe('register', () => {
    it('throws ConflictException if user exists', async () => {
      mockPrisma.user.findFirst.mockResolvedValue({ id: 'u1' });
      await expect(service.register('a@b.com', '+1', 'pass')).rejects.toThrow(ConflictException);
    });

    it('creates user and returns tokens', async () => {
      mockPrisma.user.findFirst.mockResolvedValue(null);
      mockPrisma.platformTenant.findFirst.mockResolvedValue({ id: 't1' });
      mockPrisma.user.create.mockResolvedValue({ id: 'u1', email: 'a@b.com', role: 'customer' });
      (mockPrisma as any).customerProfile.create = jest.fn().mockResolvedValue({});
      const result = await service.register('a@b.com', '+1', 'pass', 'Alice');
      expect(result).toHaveProperty('access_token');
      expect(result).toHaveProperty('refresh_token');
    });
  });

  describe('validateUser', () => {
    it('returns null if user not found', async () => {
      mockPrisma.user.findFirst.mockResolvedValue(null);
      expect(await service.validateUser('a@b.com', 'pass')).toBeNull();
    });

    it('returns null on wrong password', async () => {
      const hash = await bcrypt.hash('correct', 10);
      mockPrisma.user.findFirst.mockResolvedValue({ id: 'u1', metadata: { passwordHash: hash } });
      expect(await service.validateUser('a@b.com', 'wrong')).toBeNull();
    });

    it('returns user on correct password', async () => {
      const hash = await bcrypt.hash('pass', 10);
      mockPrisma.user.findFirst.mockResolvedValue({ id: 'u1', email: 'a@b.com', metadata: { passwordHash: hash } });
      const user = await service.validateUser('a@b.com', 'pass');
      expect(user).toHaveProperty('id', 'u1');
    });
  });

  describe('generateOtp', () => {
    it('upserts OTP record and returns message', async () => {
      (mockPrisma as any).otpVerification.upsert = jest.fn().mockResolvedValue({});
      const result = await service.generateOtp('+91999');
      expect(result.message).toContain('OTP');
      expect((mockPrisma as any).otpVerification.upsert).toHaveBeenCalled();
    });
  });

  describe('verifyOtp', () => {
    it('throws UnauthorizedException if no OTP record', async () => {
      (mockPrisma as any).otpVerification.findUnique = jest.fn().mockResolvedValue(null);
      await expect(service.verifyOtp('+91999', '123456')).rejects.toThrow(UnauthorizedException);
    });

    it('throws UnauthorizedException if expired', async () => {
      (mockPrisma as any).otpVerification.findUnique = jest.fn().mockResolvedValue({
        expiresAt: new Date(Date.now() - 1000), otpHash: 'h', attempts: 0,
      });
      await expect(service.verifyOtp('+91999', '123456')).rejects.toThrow(UnauthorizedException);
    });

    it('returns tokens on valid OTP', async () => {
      const hash = await bcrypt.hash('654321', 10);
      (mockPrisma as any).otpVerification.findUnique = jest.fn().mockResolvedValue({
        expiresAt: new Date(Date.now() + 60000), otpHash: hash, attempts: 0,
      });
      (mockPrisma as any).otpVerification.delete = jest.fn().mockResolvedValue({});
      mockPrisma.user.findFirst.mockResolvedValue({ id: 'u1', email: null, role: 'customer' });
      const result = await service.verifyOtp('+91999', '654321');
      expect(result).toHaveProperty('access_token');
    });
  });

  describe('refreshTokens', () => {
    it('returns new tokens on valid refresh token', async () => {
      mockJwt.verify.mockReturnValue({ sub: 'u1', email: 'a@b.com' });
      mockPrisma.user.findUnique.mockResolvedValue({ id: 'u1', email: 'a@b.com', role: 'customer' });
      const result = await service.refreshTokens('valid_token');
      expect(result).toHaveProperty('access_token');
    });

    it('throws on invalid refresh token', async () => {
      mockJwt.verify.mockImplementation(() => { throw new Error('invalid'); });
      await expect(service.refreshTokens('bad')).rejects.toThrow(UnauthorizedException);
    });
  });
});
'@
Write-Host "Created auth.service.spec.ts"

# ─── USER SERVICE ────────────────────────────────────────────────────────────
Set-Content -Path "$baseDir\user-service\src\user.service.spec.ts" -Encoding UTF8 -Value @'
import { Test, TestingModule } from '@nestjs/testing';
import { UserService } from './user.service';
import { PrismaService } from '@quickbite/prisma';
import { NotFoundException } from '@nestjs/common';

const mockPrisma = {
  user: { findUnique: jest.fn(), findUniqueOrThrow: jest.fn(), update: jest.fn() },
  savedAddress: { findMany: jest.fn(), create: jest.fn(), findFirst: jest.fn(), update: jest.fn() },
  customerProfile: { upsert: jest.fn() },
  customerPreferences: { findFirst: jest.fn(), upsert: jest.fn() },
};

describe('UserService', () => {
  let service: UserService;
  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [UserService, { provide: PrismaService, useValue: mockPrisma }],
    }).compile();
    service = module.get<UserService>(UserService);
    jest.clearAllMocks();
  });

  it('getProfile throws NotFoundException if user not found', async () => {
    mockPrisma.user.findUnique.mockResolvedValue(null);
    await expect(service.getProfile('u1')).rejects.toThrow(NotFoundException);
  });

  it('getProfile returns user without passwordHash', async () => {
    mockPrisma.user.findUnique.mockResolvedValue({ id: 'u1', email: 'a@b.com', passwordHash: 'secret', customerProfile: null, savedAddresses: [], customerPreferences: null });
    const result = await service.getProfile('u1');
    expect(result).not.toHaveProperty('passwordHash');
    expect(result).toHaveProperty('id', 'u1');
  });

  it('getAddresses returns list', async () => {
    mockPrisma.savedAddress.findMany.mockResolvedValue([{ id: 'a1' }]);
    const result = await service.getAddresses('u1');
    expect(result).toHaveLength(1);
  });

  it('addAddress creates address', async () => {
    mockPrisma.savedAddress.create.mockResolvedValue({ id: 'a1', userId: 'u1' });
    const result = await service.addAddress('u1', { line1: '123 Main St' });
    expect(result).toHaveProperty('id', 'a1');
  });

  it('deleteAddress throws if not owned', async () => {
    mockPrisma.savedAddress.findFirst.mockResolvedValue(null);
    await expect(service.deleteAddress('u1', 'a999')).rejects.toThrow(NotFoundException);
  });
});
'@
Write-Host "Created user.service.spec.ts"

# ─── ORDER SERVICE ────────────────────────────────────────────────────────────
Set-Content -Path "$baseDir\order-service\src\order.service.spec.ts" -Encoding UTF8 -Value @'
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
'@
Write-Host "Created order.service.spec.ts"

# ─── PAYMENT SERVICE ────────────────────────────────────────────────────────
Set-Content -Path "$baseDir\payment-service\src\payment.service.spec.ts" -Encoding UTF8 -Value @'
import { Test, TestingModule } from '@nestjs/testing';
import { PaymentService } from './payment.service';
import { PrismaService } from '@quickbite/prisma';
import { KafkaService } from '@quickbite/common';
import { NotFoundException } from '@nestjs/common';

const mockPrisma = {
  order: { findFirst: jest.fn(), updateMany: jest.fn() },
  payment: { create: jest.fn(), findFirst: jest.fn(), updateMany: jest.fn(), findMany: jest.fn() },
};
const mockKafka = { emit: jest.fn().mockResolvedValue(undefined) };

jest.mock('stripe', () => {
  return jest.fn().mockImplementation(() => ({
    paymentIntents: { create: jest.fn().mockResolvedValue({ id: 'pi_mock', client_secret: 'cs_mock' }) },
    refunds: { create: jest.fn().mockResolvedValue({ id: 'ref_mock' }) },
  }));
});

describe('PaymentService', () => {
  let service: PaymentService;
  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PaymentService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: KafkaService, useValue: mockKafka },
      ],
    }).compile();
    service = module.get<PaymentService>(PaymentService);
    jest.clearAllMocks();
  });

  it('initiatePayment throws if order not found', async () => {
    mockPrisma.order.findFirst.mockResolvedValue(null);
    await expect(service.initiatePayment('bad', {})).rejects.toThrow(NotFoundException);
  });

  it('initiatePayment returns clientSecret', async () => {
    mockPrisma.order.findFirst.mockResolvedValue({ id: 'o1', userId: 'u1', tenantId: 't1', totalAmount: 200 });
    mockPrisma.payment.create.mockResolvedValue({ id: 'pay1' });
    const result = await service.initiatePayment('o1', { methodType: 'card' });
    expect(result).toHaveProperty('clientSecret', 'cs_mock');
  });

  it('processWebhook marks payment success and emits event', async () => {
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
});
'@
Write-Host "Created payment.service.spec.ts"

# ─── DELIVERY SERVICE ────────────────────────────────────────────────────────
Set-Content -Path "$baseDir\delivery-service\src\delivery.service.spec.ts" -Encoding UTF8 -Value @'
import { Test, TestingModule } from '@nestjs/testing';
import { DeliveryService } from './delivery.service';
import { PrismaService } from '@quickbite/prisma';
import { KafkaService } from '@quickbite/common';
import { NotFoundException } from '@nestjs/common';

const mockPrisma = {
  platformTenant: { findFirst: jest.fn().mockResolvedValue({ id: 't1' }) },
  deliveryPartner: { create: jest.fn(), findMany: jest.fn(), findFirst: jest.fn(), update: jest.fn() },
  deliveryAssignment: { create: jest.fn(), findFirst: jest.fn(), update: jest.fn() },
  order: { findFirst: jest.fn(), updateMany: jest.fn() },
  $queryRaw: jest.fn().mockResolvedValue([]),
};
const mockKafka = { emit: jest.fn().mockResolvedValue(undefined) };

describe('DeliveryService', () => {
  let service: DeliveryService;
  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DeliveryService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: KafkaService, useValue: mockKafka },
      ],
    }).compile();
    service = module.get<DeliveryService>(DeliveryService);
    jest.clearAllMocks();
    mockPrisma.platformTenant.findFirst.mockResolvedValue({ id: 't1' });
  });

  it('registerPartner creates a partner record', async () => {
    mockPrisma.deliveryPartner.create.mockResolvedValue({ id: 'dp1' });
    const result = await service.registerPartner({ userId: 'u1', fullName: 'Ali Khan', phoneNumber: '+91999' });
    expect(result).toHaveProperty('partnerId', 'dp1');
  });

  it('assignPartner throws if order not found', async () => {
    mockPrisma.order.findFirst.mockResolvedValue(null);
    await expect(service.assignPartner('bad', 'dp1')).rejects.toThrow(NotFoundException);
  });

  it('assignPartner throws if partner not available', async () => {
    mockPrisma.order.findFirst.mockResolvedValue({ id: 'o1' });
    mockPrisma.deliveryPartner.findFirst.mockResolvedValue(null);
    await expect(service.assignPartner('o1', 'dp1')).rejects.toThrow(NotFoundException);
  });

  it('assignPartner creates assignment and emits Kafka event', async () => {
    mockPrisma.order.findFirst.mockResolvedValue({ id: 'o1', storeId: 's1' });
    mockPrisma.deliveryPartner.findFirst.mockResolvedValue({ id: 'dp1', firstName: 'Ali', lastName: 'Khan', phone: '+91999', status: 'available' });
    mockPrisma.deliveryAssignment.create.mockResolvedValue({ id: 'da1', estimatedDurationMin: 25, orderId: 'o1', partnerId: 'dp1' });
    mockPrisma.deliveryPartner.update.mockResolvedValue({});
    mockPrisma.order.updateMany.mockResolvedValue({});
    const result = await service.assignPartner('o1', 'dp1');
    expect(result).toHaveProperty('id', 'da1');
    expect(mockKafka.emit).toHaveBeenCalled();
  });
});
'@
Write-Host "Created delivery.service.spec.ts"

# ─── CART SERVICE ────────────────────────────────────────────────────────────
Set-Content -Path "$baseDir\cart-service\src\cart.service.spec.ts" -Encoding UTF8 -Value @'
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
'@
Write-Host "Created cart.service.spec.ts"

# ─── TRACKING SERVICE ────────────────────────────────────────────────────────
Set-Content -Path "$baseDir\tracking-service\src\tracking.service.spec.ts" -Encoding UTF8 -Value @'
import { Test, TestingModule } from '@nestjs/testing';
import { TrackingService } from './tracking.service';
import { PrismaService } from '@quickbite/prisma';
import { NotFoundException } from '@nestjs/common';

const mockPrisma = {
  order: { findFirst: jest.fn() },
  deliveryAssignment: { findFirst: jest.fn() },
  $executeRaw: jest.fn().mockResolvedValue(1),
  deliveryTracking: { findFirst: jest.fn(), findMany: jest.fn(), upsert: jest.fn() },
};

describe('TrackingService', () => {
  let service: TrackingService;
  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [TrackingService, { provide: PrismaService, useValue: mockPrisma }],
    }).compile();
    service = module.get<TrackingService>(TrackingService);
    jest.clearAllMocks();
  });

  it('getLatestLocation throws NotFoundException if no data', async () => {
    (mockPrisma as any).deliveryTracking.findFirst = jest.fn().mockResolvedValue(null);
    await expect(service.getLatestLocation('o1')).rejects.toThrow(NotFoundException);
  });

  it('getLatestLocation returns tracking data', async () => {
    (mockPrisma as any).deliveryTracking.findFirst = jest.fn().mockResolvedValue({ lat: 12.9, lng: 77.6 });
    const result = await service.getLatestLocation('o1');
    expect(result).toHaveProperty('lat', 12.9);
  });

  it('upsertLocation persists location data', async () => {
    (mockPrisma as any).deliveryTracking.upsert = jest.fn().mockResolvedValue({ orderId: 'o1', lat: 12.9, lng: 77.6 });
    const result = await service.upsertLocation({ orderId: 'o1', partnerId: 'dp1', lat: 12.9, lng: 77.6 });
    expect(result).toHaveProperty('lat', 12.9);
  });

  it('getOrderDeliveryStatus throws if order not found', async () => {
    mockPrisma.order.findFirst.mockResolvedValue(null);
    await expect(service.getOrderDeliveryStatus('bad')).rejects.toThrow(NotFoundException);
  });
});
'@
Write-Host "Created tracking.service.spec.ts"

# ─── MERCHANT SERVICE ────────────────────────────────────────────────────────
$merchantSpec = @'
import { Test, TestingModule } from '@nestjs/testing';
import { MerchantService } from './merchant.service';
import { PrismaService } from '@quickbite/prisma';

const mockPrisma = {
  merchant: { findFirst: jest.fn(), create: jest.fn(), findMany: jest.fn(), update: jest.fn() },
  store: { create: jest.fn(), findFirst: jest.fn(), findMany: jest.fn(), update: jest.fn() },
  platformTenant: { findFirst: jest.fn().mockResolvedValue({ id: 't1' }) },
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

  it('getMyMerchant returns merchant', async () => {
    mockPrisma.merchant.findFirst.mockResolvedValue({ id: 'm1' });
    const result = await service.getMyMerchant('u1');
    expect(result).toHaveProperty('id');
  });

  it('listStores returns array', async () => {
    mockPrisma.store.findMany.mockResolvedValue([{ id: 's1' }]);
    const result = await service.listStores('m1');
    expect(Array.isArray(result)).toBe(true);
  });
});
'@
Set-Content -Path "$baseDir\merchant-service\src\merchant.service.spec.ts" -Encoding UTF8 -Value $merchantSpec
Write-Host "Created merchant.service.spec.ts"

Write-Host "Core spec files created. Continuing with remaining services..."

# ─── NOTIFICATION SERVICE ─────────────────────────────────────────────────────
$notifSpec = @'
import { Test, TestingModule } from '@nestjs/testing';
import { NotificationService } from './notification.service';
import { PrismaService } from '@quickbite/prisma';

const mockPrisma = {
  platformTenant: { findFirst: jest.fn().mockResolvedValue({ id: 't1' }) },
  user: { findFirst: jest.fn() },
  notification: { create: jest.fn(), findMany: jest.fn(), updateMany: jest.fn() },
  order: { findFirst: jest.fn() },
};

jest.mock('firebase-admin/app', () => ({ initializeApp: jest.fn(), getApps: jest.fn(() => [{}]), applicationDefault: jest.fn() }));
jest.mock('firebase-admin/messaging', () => ({ getMessaging: jest.fn(() => ({ sendEachForMulticast: jest.fn().mockResolvedValue({}) })) }));
jest.mock('twilio', () => jest.fn(() => ({ messages: { create: jest.fn().mockResolvedValue({}) } })));
jest.mock('nodemailer', () => ({ createTransport: jest.fn(() => ({ sendMail: jest.fn().mockResolvedValue({}) })) }));

describe('NotificationService', () => {
  let service: NotificationService;
  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [NotificationService, { provide: PrismaService, useValue: mockPrisma }],
    }).compile();
    service = module.get<NotificationService>(NotificationService);
    jest.clearAllMocks();
  });

  it('should be defined', () => expect(service).toBeDefined());

  it('sendNotification creates notification record', async () => {
    mockPrisma.user.findFirst.mockResolvedValue({ id: 'u1', devices: [] });
    mockPrisma.notification.create.mockResolvedValue({ id: 'n1' });
    const result = await service.sendNotification({ userId: 'u1', type: 'in_app', title: 'Test', body: 'Body' });
    expect(result).toHaveProperty('id', 'n1');
  });

  it('getUserNotifications returns list', async () => {
    mockPrisma.notification.findMany.mockResolvedValue([{ id: 'n1' }]);
    const result = await service.getUserNotifications('u1');
    expect(Array.isArray(result)).toBe(true);
  });
});
'@
Set-Content -Path "$baseDir\notification-service\src\notification.service.spec.ts" -Encoding UTF8 -Value $notifSpec
Write-Host "Created notification.service.spec.ts"

# ─── SEARCH SERVICE ───────────────────────────────────────────────────────────
$searchSpec = @'
import { Test, TestingModule } from '@nestjs/testing';
import { SearchService } from './search.service';
import { PrismaService } from '@quickbite/prisma';

const mockPrisma = {
  store: { findMany: jest.fn().mockResolvedValue([{ id: 's1', name: 'Pizza Palace' }]) },
  product: { findMany: jest.fn().mockResolvedValue([{ id: 'p1', name: 'Margherita' }]) },
  $queryRaw: jest.fn().mockResolvedValue([]),
};

describe('SearchService', () => {
  let service: SearchService;
  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [SearchService, { provide: PrismaService, useValue: mockPrisma }],
    }).compile();
    service = module.get<SearchService>(SearchService);
    jest.clearAllMocks();
  });

  it('searchRestaurants returns stores by name query', async () => {
    mockPrisma.store.findMany.mockResolvedValue([{ id: 's1', name: 'Pizza Palace' }]);
    const result = await service.searchRestaurants({ q: 'pizza' });
    expect(Array.isArray(result)).toBe(true);
  });

  it('searchProducts returns products', async () => {
    mockPrisma.product.findMany.mockResolvedValue([{ id: 'p1', name: 'Margherita' }]);
    const result = await service.searchProducts({ q: 'pizza' });
    expect(result).toHaveLength(1);
  });

  it('getSuggestions returns empty for short queries', async () => {
    const result = await service.getSuggestions('a');
    expect(result).toHaveLength(0);
  });

  it('getSuggestions returns combined results', async () => {
    mockPrisma.store.findMany.mockResolvedValue([{ id: 's1', name: 'Foo' }]);
    mockPrisma.product.findMany.mockResolvedValue([{ id: 'p1', name: 'Bar' }]);
    const result = await service.getSuggestions('fo');
    expect(result.length).toBeGreaterThan(0);
  });
});
'@
Set-Content -Path "$baseDir\search-service\src\search.service.spec.ts" -Encoding UTF8 -Value $searchSpec
Write-Host "Created search.service.spec.ts"

# ─── LOYALTY SERVICE ─────────────────────────────────────────────────────────
$loyaltySpec = @'
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
'@
Set-Content -Path "$baseDir\loyalty-service\src\loyalty.service.spec.ts" -Encoding UTF8 -Value $loyaltySpec
Write-Host "Created loyalty.service.spec.ts"

# ─── WALLET SERVICE ───────────────────────────────────────────────────────────
$walletSpec = @'
import { Test, TestingModule } from '@nestjs/testing';
import { WalletService } from './wallet.service';
import { PrismaService } from '@quickbite/prisma';
import { KafkaService } from '@quickbite/common';

const mockPrisma = {
  platformTenant: { findFirst: jest.fn().mockResolvedValue({ id: 't1' }) },
  wallet: { findFirst: jest.fn(), create: jest.fn(), update: jest.fn() },
  walletTransaction: { create: jest.fn(), findMany: jest.fn() },
};
const mockKafka = { emit: jest.fn().mockResolvedValue(undefined) };

describe('WalletService', () => {
  let service: WalletService;
  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        WalletService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: KafkaService, useValue: mockKafka },
      ],
    }).compile();
    service = module.get<WalletService>(WalletService);
    jest.clearAllMocks();
  });
  it('should be defined', () => expect(service).toBeDefined());
});
'@
Set-Content -Path "$baseDir\wallet-service\src\wallet.service.spec.ts" -Encoding UTF8 -Value $walletSpec
Write-Host "Created wallet.service.spec.ts"

# ─── SUBSCRIPTION SERVICE ─────────────────────────────────────────────────────
$subSpec = @'
import { Test, TestingModule } from '@nestjs/testing';
import { SubscriptionService } from './subscription.service';
import { PrismaService } from '@quickbite/prisma';
import { KafkaService } from '@quickbite/common';
import { NotFoundException, BadRequestException } from '@nestjs/common';

const mockPrisma = {
  subscriptionPlan: { findMany: jest.fn(), findFirst: jest.fn() },
  userSubscription: { findFirst: jest.fn(), create: jest.fn(), update: jest.fn(), findMany: jest.fn() },
};
const mockKafka = { emit: jest.fn().mockResolvedValue(undefined) };

describe('SubscriptionService', () => {
  let service: SubscriptionService;
  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SubscriptionService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: KafkaService, useValue: mockKafka },
      ],
    }).compile();
    service = module.get<SubscriptionService>(SubscriptionService);
    jest.clearAllMocks();
  });

  it('getPlans returns active plans', async () => {
    (mockPrisma as any).subscriptionPlan.findMany = jest.fn().mockResolvedValue([{ id: 'p1', name: 'Gold' }]);
    const result = await service.getPlans();
    expect(result).toHaveLength(1);
  });

  it('subscribe throws if plan not found', async () => {
    (mockPrisma as any).subscriptionPlan.findFirst = jest.fn().mockResolvedValue(null);
    (mockPrisma as any).userSubscription.findFirst = jest.fn().mockResolvedValue(null);
    await expect(service.subscribe('u1', 'bad')).rejects.toThrow(NotFoundException);
  });

  it('subscribe throws if already subscribed', async () => {
    (mockPrisma as any).subscriptionPlan.findFirst = jest.fn().mockResolvedValue({ id: 'p1', durationDays: 30 });
    (mockPrisma as any).userSubscription.findFirst = jest.fn().mockResolvedValue({ id: 'sub1', status: 'active' });
    await expect(service.subscribe('u1', 'p1')).rejects.toThrow(BadRequestException);
  });

  it('subscribe creates subscription and emits event', async () => {
    (mockPrisma as any).subscriptionPlan.findFirst = jest.fn().mockResolvedValue({ id: 'p1', durationDays: 30, name: 'Gold', isActive: true });
    (mockPrisma as any).userSubscription.findFirst = jest.fn().mockResolvedValue(null);
    (mockPrisma as any).userSubscription.create = jest.fn().mockResolvedValue({ id: 'sub1' });
    const result = await service.subscribe('u1', 'p1');
    expect(result).toHaveProperty('id', 'sub1');
    expect(mockKafka.emit).toHaveBeenCalled();
  });
});
'@
Set-Content -Path "$baseDir\subscription-service\src\subscription.service.spec.ts" -Encoding UTF8 -Value $subSpec
Write-Host "Created subscription.service.spec.ts"

# ─── INVENTORY SERVICE ───────────────────────────────────────────────────────
$invSpec = @'
import { Test, TestingModule } from '@nestjs/testing';
import { InventoryService } from './inventory.service';
import { PrismaService } from '@quickbite/prisma';
import { KafkaService } from '@quickbite/common';

const mockPrisma = {
  inventoryItem: { findFirst: jest.fn(), findMany: jest.fn(), create: jest.fn(), update: jest.fn() },
};
const mockKafka = { emit: jest.fn().mockResolvedValue(undefined) };

describe('InventoryService', () => {
  let service: InventoryService;
  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        InventoryService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: KafkaService, useValue: mockKafka },
      ],
    }).compile();
    service = module.get<InventoryService>(InventoryService);
    jest.clearAllMocks();
  });
  it('should be defined', () => expect(service).toBeDefined());
});
'@
Set-Content -Path "$baseDir\inventory-service\src\inventory.service.spec.ts" -Encoding UTF8 -Value $invSpec
Write-Host "Created inventory.service.spec.ts"

# ─── ANALYTICS SERVICE ───────────────────────────────────────────────────────
$analyticsSpec = @'
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
'@
Set-Content -Path "$baseDir\analytics-service\src\analytics.service.spec.ts" -Encoding UTF8 -Value $analyticsSpec
Write-Host "Created analytics.service.spec.ts"

# ─── ADMIN SERVICE ───────────────────────────────────────────────────────────
$adminSpec = @'
import { Test, TestingModule } from '@nestjs/testing';
import { AdminService } from './admin.service';
import { PrismaService } from '@quickbite/prisma';

const mockPrisma = {
  user: { findMany: jest.fn(), update: jest.fn(), count: jest.fn() },
  order: { count: jest.fn() },
  merchant: { findMany: jest.fn(), update: jest.fn() },
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
});
'@
Set-Content -Path "$baseDir\admin-service\src\admin.service.spec.ts" -Encoding UTF8 -Value $adminSpec
Write-Host "Created admin.service.spec.ts"

# ─── CMS SERVICE ─────────────────────────────────────────────────────────────
$cmsSpec = @'
import { Test, TestingModule } from '@nestjs/testing';
import { CmsService } from './cms.service';
import { PrismaService } from '@quickbite/prisma';

const mockPrisma = {
  banner: { findMany: jest.fn().mockResolvedValue([{ id: 'b1' }]), create: jest.fn(), update: jest.fn() },
};

describe('CmsService', () => {
  let service: CmsService;
  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [CmsService, { provide: PrismaService, useValue: mockPrisma }],
    }).compile();
    service = module.get<CmsService>(CmsService);
    jest.clearAllMocks();
  });
  it('should be defined', () => expect(service).toBeDefined());
});
'@
Set-Content -Path "$baseDir\cms-service\src\cms.service.spec.ts" -Encoding UTF8 -Value $cmsSpec
Write-Host "Created cms.service.spec.ts"

# ─── REVIEW SERVICE ──────────────────────────────────────────────────────────
$reviewSpec = @'
import { Test, TestingModule } from '@nestjs/testing';
import { ReviewService } from './review.service';
import { PrismaService } from '@quickbite/prisma';

const mockPrisma = {
  review: { create: jest.fn(), findMany: jest.fn().mockResolvedValue([]), findFirst: jest.fn(), update: jest.fn() },
  platformTenant: { findFirst: jest.fn().mockResolvedValue({ id: 't1' }) },
};

describe('ReviewService', () => {
  let service: ReviewService;
  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [ReviewService, { provide: PrismaService, useValue: mockPrisma }],
    }).compile();
    service = module.get<ReviewService>(ReviewService);
    jest.clearAllMocks();
  });
  it('should be defined', () => expect(service).toBeDefined());
  it('getStoreReviews returns array', async () => {
    mockPrisma.review.findMany.mockResolvedValue([{ id: 'r1', rating: 5 }]);
    const result = await service.getStoreReviews('s1');
    expect(Array.isArray(result)).toBe(true);
  });
});
'@
Set-Content -Path "$baseDir\review-service\src\review.service.spec.ts" -Encoding UTF8 -Value $reviewSpec
Write-Host "Created review.service.spec.ts"

# ─── GROUP ORDER SERVICE ──────────────────────────────────────────────────────
$groupSpec = @'
import { Test, TestingModule } from '@nestjs/testing';
import { GroupOrderService } from './group-order.service';
import { PrismaService } from '@quickbite/prisma';
import { KafkaService } from '@quickbite/common';

const mockPrisma = {
  platformTenant: { findFirst: jest.fn().mockResolvedValue({ id: 't1' }) },
  groupOrder: { create: jest.fn(), findFirst: jest.fn(), findMany: jest.fn(), update: jest.fn() },
  groupOrderParticipant: { create: jest.fn(), findMany: jest.fn(), findFirst: jest.fn() },
};
const mockKafka = { emit: jest.fn().mockResolvedValue(undefined) };

describe('GroupOrderService', () => {
  let service: GroupOrderService;
  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        GroupOrderService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: KafkaService, useValue: mockKafka },
      ],
    }).compile();
    service = module.get<GroupOrderService>(GroupOrderService);
    jest.clearAllMocks();
  });
  it('should be defined', () => expect(service).toBeDefined());
});
'@
Set-Content -Path "$baseDir\group-order-service\src\group-order.service.spec.ts" -Encoding UTF8 -Value $groupSpec
Write-Host "Created group-order.service.spec.ts"

# ─── CATALOG SERVICE ─────────────────────────────────────────────────────────
$catalogSpec = @'
import { Test, TestingModule } from '@nestjs/testing';
import { CatalogService } from './catalog.service';
import { PrismaService } from '@quickbite/prisma';
import { NotFoundException } from '@nestjs/common';

jest.mock('ioredis', () => {
  return jest.fn().mockImplementation(() => ({
    get: jest.fn().mockResolvedValue(null),
    set: jest.fn().mockResolvedValue('OK'),
    del: jest.fn().mockResolvedValue(1),
    on: jest.fn(),
  }));
});

const mockPrisma = {
  vertical: { findMany: jest.fn().mockResolvedValue([{ id: 'v1' }]), create: jest.fn() },
  category: { findMany: jest.fn().mockResolvedValue([]), create: jest.fn() },
  product: { findMany: jest.fn().mockResolvedValue([]), findUnique: jest.fn(), create: jest.fn(), update: jest.fn() },
  addOnGroup: { findMany: jest.fn().mockResolvedValue([]), create: jest.fn() },
};

describe('CatalogService', () => {
  let service: CatalogService;
  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [CatalogService, { provide: PrismaService, useValue: mockPrisma }],
    }).compile();
    service = module.get<CatalogService>(CatalogService);
    jest.clearAllMocks();
  });

  it('getVerticals fetches from DB when cache is empty', async () => {
    mockPrisma.vertical.findMany.mockResolvedValue([{ id: 'v1', name: 'Food' }]);
    const result = await service.getVerticals();
    expect(result).toHaveLength(1);
  });

  it('getProductDetails throws NotFoundException if product missing', async () => {
    mockPrisma.product.findUnique.mockResolvedValue(null);
    await expect(service.getProductDetails('bad')).rejects.toThrow(NotFoundException);
  });
});
'@
Set-Content -Path "$baseDir\catalog-service\src\catalog.service.spec.ts" -Encoding UTF8 -Value $catalogSpec
Write-Host "Created catalog.service.spec.ts"

# ─── SUPPORT SERVICE ─────────────────────────────────────────────────────────
$supportDir = "c:\Users\HP\OneDrive\Desktop\ongoing\food delivery backend\apps\support-service\src"
$supportSpec = @'
import { Test, TestingModule } from '@nestjs/testing';
import { SupportService } from './support.service';
import { PrismaService } from '@quickbite/prisma';
import { KafkaService } from '@quickbite/common';
import { NotFoundException, ForbiddenException } from '@nestjs/common';

const mockPrisma = {
  platformTenant: { findFirst: jest.fn().mockResolvedValue({ id: 't1' }) },
  supportTicket: { create: jest.fn(), findMany: jest.fn(), findFirst: jest.fn(), update: jest.fn() },
  supportMessage: { create: jest.fn(), findMany: jest.fn() },
  faq: { findMany: jest.fn().mockResolvedValue([]) },
};
const mockKafka = { emit: jest.fn().mockResolvedValue(undefined) };

describe('SupportService', () => {
  let service: SupportService;
  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SupportService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: KafkaService, useValue: mockKafka },
      ],
    }).compile();
    service = module.get<SupportService>(SupportService);
    jest.clearAllMocks();
  });

  it('createTicket creates ticket and emits Kafka event', async () => {
    (mockPrisma as any).supportTicket.create = jest.fn().mockResolvedValue({ id: 'tkt1', ticketNumber: 'TKT-1' });
    const result = await service.createTicket('u1', { subject: 'Help', description: 'Need help' });
    expect(result).toHaveProperty('id', 'tkt1');
    expect(mockKafka.emit).toHaveBeenCalled();
  });

  it('getTicket throws NotFoundException if not found', async () => {
    (mockPrisma as any).supportTicket.findFirst = jest.fn().mockResolvedValue(null);
    await expect(service.getTicket('bad')).rejects.toThrow(NotFoundException);
  });

  it('getTicket throws ForbiddenException if not owned by user', async () => {
    (mockPrisma as any).supportTicket.findFirst = jest.fn().mockResolvedValue({ id: 'tkt1', userId: 'other', messages: [] });
    await expect(service.getTicket('tkt1', 'u1')).rejects.toThrow(ForbiddenException);
  });

  it('updateTicketStatus emits resolved event', async () => {
    (mockPrisma as any).supportTicket.findFirst = jest.fn().mockResolvedValue({ id: 'tkt1', userId: 'u1' });
    (mockPrisma as any).supportTicket.update = jest.fn().mockResolvedValue({ id: 'tkt1', status: 'resolved' });
    const result = await service.updateTicketStatus('tkt1', 'resolved', 'Fixed');
    expect(result.status).toBe('resolved');
    expect(mockKafka.emit).toHaveBeenCalled();
  });

  it('getFaqs returns faq list', async () => {
    (mockPrisma as any).faq.findMany = jest.fn().mockResolvedValue([{ id: 'f1', question: 'How?', answer: 'Yes.' }]);
    const result = await service.getFaqs();
    expect(result).toHaveLength(1);
  });
});
'@
Set-Content -Path "$supportDir\support.service.spec.ts" -Encoding UTF8 -Value $supportSpec
Write-Host "Created support.service.spec.ts"

Write-Host ""
Write-Host "All 21 test spec files created successfully!"
