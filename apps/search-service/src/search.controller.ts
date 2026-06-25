import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { SearchService } from './search.service';
import { JwtAuthGuard } from '@quickbite/common';

@UseGuards(JwtAuthGuard)
@Controller('search')
export class SearchController {
  constructor(private readonly searchService: SearchService) {}

  @Get('restaurants')
  searchRestaurants(
    @Query('q') q?: string,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
    @Query('vertical') vertical?: string,
    @Query('limit') limit?: string,
  ) {
    return this.searchService.searchRestaurants({
      q,
      lat: lat ? parseFloat(lat) : undefined,
      lng: lng ? parseFloat(lng) : undefined,
      vertical,
      limit: limit ? parseInt(limit, 10) : 20,
    });
  }

  @Get('products')
  searchProducts(
    @Query('q') q: string,
    @Query('storeId') storeId?: string,
    @Query('limit') limit?: string,
  ) {
    return this.searchService.searchProducts({
      q,
      storeId,
      limit: limit ? parseInt(limit, 10) : 20,
    });
  }

  @Get('suggestions')
  getSuggestions(@Query('q') q: string) {
    return this.searchService.getSuggestions(q);
  }
}
