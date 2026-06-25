import { Controller, Get, Post, Body, Param, Query, UseGuards } from '@nestjs/common';
import { InventoryService } from './inventory.service';
import { JwtAuthGuard } from '@quickbite/common';

@UseGuards(JwtAuthGuard)
@Controller('inventory')
export class InventoryController {
  constructor(private readonly inventoryService: InventoryService) {}

  @Get('product/:productId')
  getStockLevel(@Param('productId') productId: string) {
    return this.inventoryService.getStockLevel(productId);
  }

  @Post('product/:productId/adjust')
  adjustStock(
    @Param('productId') productId: string,
    @Body() body: { delta: number; reason: string },
  ) {
    return this.inventoryService.adjustStock(productId, body.delta, body.reason);
  }

  @Get('store/:storeId/low-stock')
  getLowStock(
    @Param('storeId') storeId: string,
    @Query('threshold') threshold?: string,
  ) {
    return this.inventoryService.getLowStockItems(
      storeId,
      threshold ? parseInt(threshold) : 5,
    );
  }
}
