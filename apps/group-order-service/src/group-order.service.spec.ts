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
