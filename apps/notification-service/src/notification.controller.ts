import {
  Controller,
  Get,
  Post,
  Put,
  Body,
  Param,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { NotificationService } from './notification.service';
import { CurrentUser, JwtAuthGuard } from '@quickbite/common';

@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationController {
  constructor(private readonly notificationService: NotificationService) {}

  @Get()
  getNotifications(@CurrentUser() user: any) {
    return this.notificationService.getUserNotifications(user.userId);
  }

  @HttpCode(HttpStatus.OK)
  @Put(':id/read')
  markAsRead(@Param('id') id: string) {
    return this.notificationService.markAsRead(id);
  }

  @HttpCode(HttpStatus.OK)
  @Put('read-all')
  markAllAsRead(@CurrentUser() user: any) {
    return this.notificationService.markAllAsRead(user.userId);
  }

  @Post('send')
  sendNotification(@Body() body: any) {
    return this.notificationService.sendNotification(body);
  }
}
