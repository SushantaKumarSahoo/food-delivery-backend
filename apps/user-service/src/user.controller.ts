import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { UserService } from './user.service';
import { CurrentUser, JwtAuthGuard } from '@quickbite/common';

@UseGuards(JwtAuthGuard)
@Controller('users')
export class UserController {
  constructor(private readonly userService: UserService) {}

  @Get('profile')
  getProfile(@CurrentUser() user: any) {
    return this.userService.getProfile(user.userId);
  }

  @Get('me')
  getMe(@CurrentUser() user: any) {
    return this.userService.getProfile(user.userId);
  }

  @Put('profile')
  updateProfile(@CurrentUser() user: any, @Body() body: any) {
    return this.userService.updateProfile(user.userId, body);
  }

  @Get('addresses')
  getAddresses(@CurrentUser() user: any) {
    return this.userService.getAddresses(user.userId);
  }

  @Post('addresses')
  addAddress(@CurrentUser() user: any, @Body() body: any) {
    return this.userService.addAddress(user.userId, body);
  }

  @Put('addresses/:id')
  updateAddress(
    @CurrentUser() user: any,
    @Param('id') id: string,
    @Body() body: any,
  ) {
    return this.userService.updateAddress(user.userId, id, body);
  }

  @Delete('addresses/:id')
  deleteAddress(@CurrentUser() user: any, @Param('id') id: string) {
    return this.userService.deleteAddress(user.userId, id);
  }

  @Get('preferences')
  getPreferences(@CurrentUser() user: any) {
    return this.userService.getPreferences(user.userId);
  }

  @Put('preferences')
  updatePreferences(@CurrentUser() user: any, @Body() body: any) {
    return this.userService.updatePreferences(user.userId, body);
  }

  @HttpCode(HttpStatus.OK)
  @Delete('account')
  deleteAccount(@CurrentUser() user: any) {
    return this.userService.deleteAccount(user.userId);
  }

  @Put('device-token')
  saveDeviceToken(
    @CurrentUser() user: any,
    @Body() body: { fcmToken: string },
  ) {
    return this.userService.saveDeviceToken(user.userId, body.fcmToken);
  }

  @Get('wallet')
  getWallet(@CurrentUser() user: any) {
    return this.userService.getWallet(user.userId);
  }

  @HttpCode(HttpStatus.OK)
  @Post('wallet/redeem')
  redeemCoins(@CurrentUser() user: any, @Body() body: { coins: number }) {
    return this.userService.redeemCoins(user.userId, body.coins || 50);
  }

  @HttpCode(HttpStatus.OK)
  @Post('wallet/add')
  addCoins(@CurrentUser() user: any, @Body() body: { coins: number }) {
    return this.userService.addCoins(user.userId, body.coins || 10);
  }
}
