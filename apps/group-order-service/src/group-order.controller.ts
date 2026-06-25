import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { GroupOrderService } from './group-order.service';
import { CurrentUser, JwtAuthGuard } from '@quickbite/common';

@UseGuards(JwtAuthGuard)
@Controller('group-orders')
export class GroupOrderController {
  constructor(private readonly groupOrderService: GroupOrderService) {}

  @Post()
  createSession(@CurrentUser() user: any, @Body() body: any) {
    return this.groupOrderService.createSession(user.userId, body);
  }

  @Get(':id')
  getSession(@Param('id') id: string) {
    return this.groupOrderService.getSession(id);
  }

  @HttpCode(HttpStatus.OK)
  @Post('join')
  joinSession(
    @CurrentUser() user: any,
    @Body() body: { inviteCode: string },
  ) {
    return this.groupOrderService.joinSession(body.inviteCode, user.userId);
  }

  @Post(':id/items')
  addItems(
    @Param('id') id: string,
    @CurrentUser() user: any,
    @Body() body: { items: any[] },
  ) {
    return this.groupOrderService.addItems(id, user.userId, body.items);
  }

  @HttpCode(HttpStatus.OK)
  @Post(':id/checkout')
  checkout(@Param('id') id: string, @CurrentUser() user: any) {
    return this.groupOrderService.checkout(id, user.userId);
  }
}
