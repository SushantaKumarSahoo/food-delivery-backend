import {
  Controller,
  Post,
  Get,
  Body,
  Param,
  UseGuards,
  HttpCode,
  HttpStatus,
  Headers,
  Req,
  Logger,
} from '@nestjs/common';
import { Request } from 'express';
import { PaymentService } from './payment.service';
import { JwtAuthGuard } from '@quickbite/common';

@Controller('payments')
export class PaymentController {
  private readonly logger = new Logger(PaymentController.name);

  constructor(private readonly paymentService: PaymentService) {}

  // Client calls this to get payment_session_id for the Flutter SDK
  @UseGuards(JwtAuthGuard)
  @Post(':orderId/initiate')
  initiatePayment(@Param('orderId') orderId: string, @Body() body: any) {
    return this.paymentService.initiatePayment(orderId, body);
  }

  // Cashfree webhook — no auth guard, verified by signature
  @HttpCode(HttpStatus.OK)
  @Post('webhook')
  async processWebhook(
    @Req() req: Request,
    @Headers('x-webhook-signature') signature: string,
    @Headers('x-webhook-timestamp') timestamp: string,
  ) {
    const rawBody =
      typeof req.body === 'string' ? req.body : JSON.stringify(req.body);
    return this.paymentService.processWebhook(rawBody, signature, timestamp);
  }

  // Verify payment status directly from Cashfree (call after SDK callback)
  @UseGuards(JwtAuthGuard)
  @Get('verify/:cfOrderId')
  verifyPayment(@Param('cfOrderId') cfOrderId: string) {
    return this.paymentService.verifyPayment(cfOrderId);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/refund')
  refundPayment(@Param('id') id: string, @Body() body: { reason?: string }) {
    return this.paymentService.refundPayment(id, body.reason);
  }

  @UseGuards(JwtAuthGuard)
  @Get(':id')
  getPaymentStatus(@Param('id') id: string) {
    return this.paymentService.getPaymentStatus(id);
  }

  @UseGuards(JwtAuthGuard)
  @Get('order/:orderId')
  getOrderPayments(@Param('orderId') orderId: string) {
    return this.paymentService.getOrderPayments(orderId);
  }
}
