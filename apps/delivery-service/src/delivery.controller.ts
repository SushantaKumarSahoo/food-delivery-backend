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
import { DeliveryService } from './delivery.service';
import { JwtAuthGuard } from '@quickbite/common';

@UseGuards(JwtAuthGuard)
@Controller('delivery')
export class DeliveryController {
  constructor(private readonly deliveryService: DeliveryService) {}

  @Post('partners')
  registerPartner(@Body() body: any) {
    return this.deliveryService.registerPartner(body);
  }

  @Get('partners')
  listPartners(@Query('status') status?: string) {
    return this.deliveryService.listPartners(status);
  }

  @Post('assign')
  assignPartner(@Body() body: { orderId: string; partnerId: string }) {
    return this.deliveryService.assignPartner(body.orderId, body.partnerId);
  }

  @Post('accept-broadcast')
  acceptBroadcast(@Body() body: { orderId: string; partnerId: string }) {
    return this.deliveryService.acceptBroadcastedOrder(body.orderId, body.partnerId);
  }

  @Put('assignments/:id/status')
  updateStatus(
    @Param('id') id: string,
    @Body() body: { status: string },
  ) {
    return this.deliveryService.updateDeliveryStatus(id, body.status);
  }

  @Get('assignments/:id')
  getAssignment(@Param('id') id: string) {
    return this.deliveryService.getAssignment(id);
  }

  @Get('order/:orderId/assignment')
  getOrderAssignment(@Param('orderId') orderId: string) {
    return this.deliveryService.getOrderAssignment(orderId);
  }
}
