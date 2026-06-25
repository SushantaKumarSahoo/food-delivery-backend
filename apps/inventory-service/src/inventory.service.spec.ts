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
