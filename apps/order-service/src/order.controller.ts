import {
  Controller,
  Post,
  Get,
  Put,
  Body,
  Param,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { OrderService } from './order.service';
import { CurrentUser, JwtAuthGuard } from '@quickbite/common';

@UseGuards(JwtAuthGuard)
@Controller('orders')
export class OrderController {
  constructor(private readonly orderService: OrderService) {}

  @Post()
  createOrder(@CurrentUser() user: any, @Body() body: any) {
    return this.orderService.createOrder(user.userId, body);
  }

  @Get()
  getMyOrders(@CurrentUser() user: any) {
    return this.orderService.getUserOrders(user.userId);
  }

  @Get(':id')
  getOrder(@Param('id') id: string) {
    return this.orderService.getOrder(id);
  }

  @Put(':id/status')
  updateStatus(@Param('id') id: string, @Body() body: { status: string }) {
    return this.orderService.updateOrderStatus(id, body.status);
  }

  @HttpCode(HttpStatus.OK)
  @Post(':id/cancel')
  cancelOrder(@Param('id') id: string, @Body() body: { reason?: string }) {
    return this.orderService.cancelOrder(id, body.reason);
  }

  @Get(':id/events')
  getOrderEvents(@Param('id') id: string) {
    return this.orderService.getOrderEvents(id);
  }
}
