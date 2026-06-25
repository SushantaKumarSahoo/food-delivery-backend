import {
  Controller,
  Get,
  Post,
  Body,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { WalletService } from './wallet.service';
import { CurrentUser, JwtAuthGuard } from '@quickbite/common';

@UseGuards(JwtAuthGuard)
@Controller('wallet')
export class WalletController {
  constructor(private readonly walletService: WalletService) {}

  @Get('balance')
  getBalance(@CurrentUser() user: any) {
    return this.walletService.getBalance(user.userId);
  }

  @Post('topup')
  topUp(
    @CurrentUser() user: any,
    @Body() body: { amount: number; method: string },
  ) {
    return this.walletService.topUp(user.userId, body.amount, body.method);
  }

  @HttpCode(HttpStatus.OK)
  @Post('pay')
  pay(
    @CurrentUser() user: any,
    @Body() body: { amount: number; orderId: string },
  ) {
    return this.walletService.deduct(user.userId, body.amount, body.orderId);
  }

  @Get('transactions')
  getTransactions(@CurrentUser() user: any) {
    return this.walletService.getTransactions(user.userId);
  }
}
