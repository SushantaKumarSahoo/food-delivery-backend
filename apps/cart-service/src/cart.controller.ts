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
import { CartService } from './cart.service';
import { CurrentUser, JwtAuthGuard } from '@quickbite/common';

@UseGuards(JwtAuthGuard)
@Controller('cart')
export class CartController {
  constructor(private readonly cartService: CartService) {}

  @Get()
  getCart(@CurrentUser() user: any) {
    return this.cartService.getCart(user.userId);
  }

  @Get('summary')
  getCartSummary(@CurrentUser() user: any) {
    return this.cartService.getCartSummary(user.userId);
  }

  @Post('items')
  addItem(@CurrentUser() user: any, @Body() body: any) {
    return this.cartService.addItem(user.userId, body);
  }

  @Put('items/:id')
  updateItem(@Param('id') id: string, @Body() body: { quantity: number }) {
    return this.cartService.updateItem(id, body.quantity);
  }

  @Delete('items/:id')
  removeItem(@Param('id') id: string) {
    return this.cartService.removeItem(id);
  }

  @HttpCode(HttpStatus.OK)
  @Delete()
  clearCart(@CurrentUser() user: any) {
    return this.cartService.clearCart(user.userId);
  }

  @Post('apply-coupon')
  applyCoupon(@CurrentUser() user: any, @Body() body: { code: string }) {
    return this.cartService.applyCoupon(user.userId, body.code);
  }
}
