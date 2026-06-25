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
