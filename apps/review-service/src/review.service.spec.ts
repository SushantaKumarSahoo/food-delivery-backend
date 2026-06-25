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
  it('getReviewsForEntity returns array', async () => {
    mockPrisma.review.findMany.mockResolvedValue([{ id: 'r1', rating: 5 }]);
    const result = await service.getReviewsForEntity('s1');
    expect(Array.isArray(result)).toBe(true);
  });
});
