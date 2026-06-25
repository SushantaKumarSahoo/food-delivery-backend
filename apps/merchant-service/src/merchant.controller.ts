import {
  Controller,
  Post,
  Get,
  Put,
  Body,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import { MerchantService } from './merchant.service';
import { CurrentUser, JwtAuthGuard } from '@quickbite/common';

@Controller('merchants')
export class MerchantController {
  constructor(private readonly merchantService: MerchantService) {}

  @UseGuards(JwtAuthGuard)
  @Post('onboard')
  onboardMerchant(@CurrentUser() user: any, @Body() body: any) {
    return this.merchantService.onboardMerchant(
      body.tenantId || 'default-tenant',
      user.userId,
      body,
    );
  }

  @Get()
  listMerchants(@Query('status') status?: string) {
    return this.merchantService.listMerchants(status);
  }

  @Get(':id')
  getMerchant(@Param('id') id: string) {
    return this.merchantService.getMerchant(id);
  }

  @UseGuards(JwtAuthGuard)
  @Put(':id')
  updateMerchant(@Param('id') id: string, @Body() body: any) {
    return this.merchantService.updateMerchant(id, body);
  }

  @UseGuards(JwtAuthGuard)
  @Put(':id/approve')
  approveMerchant(@Param('id') id: string) {
    return this.merchantService.approveMerchant(id);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/stores')
  createStore(@Param('id') merchantId: string, @Body() body: any) {
    return this.merchantService.createStore(merchantId, body);
  }

  @Get(':id/stores')
  getStores(@Param('id') merchantId: string) {
    return this.merchantService.getStoresByMerchant(merchantId);
  }

  @UseGuards(JwtAuthGuard)
  @Put(':id/stores/:storeId')
  updateStore(
    @Param('id') merchantId: string,
    @Param('storeId') storeId: string,
    @Body() body: any,
  ) {
    return this.merchantService.updateStore(merchantId, storeId, body);
  }

  @Get(':id/stores/:storeId/hours')
  getStoreHours(@Param('storeId') storeId: string) {
    return this.merchantService.getStoreHours(storeId);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/stores/:storeId/hours')
  setStoreHours(
    @Param('storeId') storeId: string,
    @Body() body: { hours: any[] },
  ) {
    return this.merchantService.setStoreHours(storeId, body.hours);
  }
}
