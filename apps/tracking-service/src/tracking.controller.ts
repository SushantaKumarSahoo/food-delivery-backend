import { Controller, Get, Param, UseGuards, Query } from '@nestjs/common';
import { TrackingService } from './tracking.service';
import { JwtAuthGuard } from '@quickbite/common';

@UseGuards(JwtAuthGuard)
@Controller('tracking')
export class TrackingController {
  constructor(private readonly trackingService: TrackingService) {}

  @Get('order/:orderId/latest')
  getLatestLocation(@Param('orderId') orderId: string) {
    return this.trackingService.getLatestLocation(orderId);
  }

  @Get('order/:orderId/history')
  getLocationHistory(
    @Param('orderId') orderId: string,
    @Query('limit') limit?: string,
  ) {
    return this.trackingService.getLocationHistory(orderId, limit ? parseInt(limit, 10) : 50);
  }

  @Get('order/:orderId/status')
  getOrderDeliveryStatus(@Param('orderId') orderId: string) {
    return this.trackingService.getOrderDeliveryStatus(orderId);
  }
}
