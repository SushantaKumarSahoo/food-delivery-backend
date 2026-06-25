import { Controller, Get, Post, Body, Param, UseGuards, HttpCode, HttpStatus } from '@nestjs/common';
import { SubscriptionService } from './subscription.service';
import { CurrentUser, JwtAuthGuard } from '@quickbite/common';

@UseGuards(JwtAuthGuard)
@Controller('subscriptions')
export class SubscriptionController {
  constructor(private readonly subscriptionService: SubscriptionService) {}

  @Get('plans')
  getPlans() {
    return this.subscriptionService.getPlans();
  }

  @Get('me')
  getUserSubscription(@CurrentUser() user: any) {
    return this.subscriptionService.getUserSubscription(user.userId);
  }

  @Post('subscribe')
  subscribe(@CurrentUser() user: any, @Body() body: { planId: string }) {
    return this.subscriptionService.subscribe(user.userId, body.planId);
  }

  @HttpCode(HttpStatus.OK)
  @Post('cancel')
  cancel(@CurrentUser() user: any) {
    return this.subscriptionService.cancelSubscription(user.userId);
  }

  @Get('perks')
  getPerks(@CurrentUser() user: any) {
    return this.subscriptionService.getPerks(user.userId);
  }
}
