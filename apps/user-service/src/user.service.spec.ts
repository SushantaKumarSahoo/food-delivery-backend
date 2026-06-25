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
