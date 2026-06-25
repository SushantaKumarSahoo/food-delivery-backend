import {
  Controller,
  Get,
  Post,
  Put,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import { AdminService } from './admin.service';
import { JwtAuthGuard } from '@quickbite/common';

@UseGuards(JwtAuthGuard)
@Controller('admin')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('dashboard/metrics')
  getDashboardMetrics() {
    return this.adminService.getDashboardMetrics();
  }

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

  @Get('feature-flags')
  getFeatureFlags() {
    return this.adminService.getFeatureFlags();
  }

  @Put('feature-flags/:key')
  updateFeatureFlag(
    @Param('key') key: string,
    @Body() body: { enabled: boolean },
  ) {
    return this.adminService.updateFeatureFlag(key, body.enabled);
  }

  @Get('merchants/pending')
  getPendingMerchants() {
    return this.adminService.getPendingMerchants();
  }
}
