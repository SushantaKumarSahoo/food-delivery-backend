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
