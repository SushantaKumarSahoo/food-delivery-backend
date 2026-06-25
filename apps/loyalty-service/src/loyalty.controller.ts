import {
  Controller,
  Get,
  Post,
  Body,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { LoyaltyService } from './loyalty.service';
import { CurrentUser, JwtAuthGuard } from '@quickbite/common';

@UseGuards(JwtAuthGuard)
@Controller('loyalty')
export class LoyaltyController {
  constructor(private readonly loyaltyService: LoyaltyService) {}

  @Get('points')
  getPoints(@CurrentUser() user: any) {
    return this.loyaltyService.getPointsBalance(user.userId);
  }

  @Get('tier')
  getTier(@CurrentUser() user: any) {
    return this.loyaltyService.getUserTier(user.userId);
  }

  @HttpCode(HttpStatus.OK)
  @Post('redeem')
  redeemPoints(
    @CurrentUser() user: any,
    @Body() body: { points: number },
  ) {
    return this.loyaltyService.redeemPoints(user.userId, body.points);
  }

  @Get('coupons')
  getCoupons(@CurrentUser() user: any) {
    return this.loyaltyService.getAvailableCoupons(user.userId);
  }

  @HttpCode(HttpStatus.OK)
  @Post('coupons/validate')
  validateCoupon(@Body() body: { code: string }) {
    return this.loyaltyService.validateCoupon(body.code);
  }
}
