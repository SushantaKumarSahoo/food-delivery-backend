import {
  Controller, Get, Post, Put, Delete,
  Body, Param, Query, UseGuards, HttpCode, HttpStatus,
} from '@nestjs/common';
import { AdminService } from './admin.service';
import { JwtAuthGuard } from '@quickbite/common';

@UseGuards(JwtAuthGuard)
@Controller('admin')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  // ─── Dashboard ─────────────────────────────────────────────────────────────

  @Get('dashboard/metrics')
  getDashboardMetrics() {
    return this.adminService.getDashboardMetrics();
  }

  // ─── Platform Config ───────────────────────────────────────────────────────

  @Get('config')
  getPlatformConfig() {
    return this.adminService.getPlatformConfig();
  }

  @Put('config')
  updatePlatformConfig(@Body() data: { platformFee?: number; enableDeliveryBatching?: boolean }) {
    return this.adminService.updatePlatformConfig(data);
  }

  // ─── Users ─────────────────────────────────────────────────────────────────

  @Put('users/:id/ban')
  banUser(@Param('id') id: string, @Body() body: { reason: string }) {
    return this.adminService.banUser(id, body.reason);
  }

  @Get('users')
  getAdminUsers() {
    return this.adminService.getAdminUsers();
  }

  @Get('roles')
  getAdminRoles() {
    return this.adminService.getAdminRoles();
  }

  @Post('users')
  createAdminUser(@Body() body: any) {
    return this.adminService.createAdminUser(body);
  }

  // ─── Feature Flags ─────────────────────────────────────────────────────────

  @Get('feature-flags')
  getFeatureFlags() {
    return this.adminService.getFeatureFlags();
  }

  @Put('feature-flags/:key')
  updateFeatureFlag(@Param('key') key: string, @Body() body: { enabled: boolean }) {
    return this.adminService.updateFeatureFlag(key, body.enabled);
  }

  // ─── Merchants ─────────────────────────────────────────────────────────────

  @Get('merchants/pending')
  getPendingMerchants() {
    return this.adminService.getPendingMerchants();
  }

  // ─── Offers / Promo Campaigns ──────────────────────────────────────────────

  @Get('offers')
  getAllOffers() {
    return this.adminService.getAllOffers();
  }

  @Post('offers')
  createOffer(@Body() body: any) {
    return this.adminService.createOffer(body);
  }

  @Put('offers/:id')
  updateOffer(@Param('id') id: string, @Body() body: any) {
    return this.adminService.updateOffer(id, body);
  }

  @HttpCode(HttpStatus.OK)
  @Delete('offers/:id')
  deactivateOffer(@Param('id') id: string) {
    return this.adminService.deactivateOffer(id);
  }

  // ─── Gift Cards ────────────────────────────────────────────────────────────

  @Get('gift-cards')
  getGiftCards() {
    return this.adminService.getGiftCards();
  }

  @Post('gift-cards')
  createGiftCard(@Body() body: { value: number; recipientEmail?: string; expiresAt?: string }) {
    return this.adminService.createGiftCard(body);
  }
}

// ─── Public routes (no auth needed for customers) ─────────────────────────────

import { Controller as PublicController, Get as PGet, Post as PPost, Body as PBody, Query as PQuery, UseGuards as PUseGuards } from '@nestjs/common';
import { CurrentUser, JwtAuthGuard as PublicJwtGuard } from '@quickbite/common';

@PublicController('offers')
export class OffersPublicController {
  constructor(private readonly adminService: AdminService) {}

  // Customers fetch active offers — no auth required
  @PGet()
  getActiveOffers() {
    return this.adminService.getOffers();
  }

  // Customer validates a coupon code before checkout
  @PUseGuards(PublicJwtGuard)
  @PPost('validate')
  validateCoupon(
    @CurrentUser() user: any,
    @PBody() body: { code: string; orderAmount: number },
  ) {
    return this.adminService.validateCoupon(body.code, user.userId, body.orderAmount);
  }

  // Customer redeems gift card
  @PUseGuards(PublicJwtGuard)
  @PPost('redeem-gift-card')
  redeemGiftCard(
    @CurrentUser() user: any,
    @PBody() body: { code: string },
  ) {
    return this.adminService.redeemGiftCard(body.code, user.userId);
  }
}
