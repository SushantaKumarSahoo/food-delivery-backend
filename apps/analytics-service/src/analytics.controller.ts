import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { AnalyticsService } from './analytics.service';
import { JwtAuthGuard } from '@quickbite/common';

@UseGuards(JwtAuthGuard)
@Controller('analytics')
export class AnalyticsController {
  constructor(private readonly analyticsService: AnalyticsService) {}

  @Get('orders/summary')
  getOrderSummary(
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    const fromDate = from ? new Date(from) : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const toDate = to ? new Date(to) : new Date();
    return this.analyticsService.getOrderSummary(fromDate, toDate);
  }

  @Get('merchants/:id/summary')
  getMerchantSummary(@Param('id') id: string) {
    return this.analyticsService.getMerchantSummary(id);
  }

  @Get('products/top-selling')
  getTopSellingProducts(@Query('limit') limit?: string) {
    return this.analyticsService.getTopSellingProducts(
      limit ? parseInt(limit) : 10,
    );
  }

  @Get('users/cohorts')
  getUserCohorts() {
    return this.analyticsService.getUserCohorts();
  }
}
