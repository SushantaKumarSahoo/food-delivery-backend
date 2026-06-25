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
