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
import { CatalogService } from './catalog.service';
import { AiService } from './ai.service';
import { JwtAuthGuard } from '@quickbite/common';

@Controller('catalog')
export class CatalogController {
  constructor(
    private readonly catalogService: CatalogService,
    private readonly aiService: AiService,
  ) {}

  // ─── Verticals ─────────────────────────────────────────────────────────────

  @UseGuards(JwtAuthGuard)
  @Post('verticals')
  createVertical(@Body() body: any) {
    return this.catalogService.createVertical(body);
  }

  @Get('verticals')
  getVerticals() {
    return this.catalogService.getVerticals();
  }

  // ─── Categories ────────────────────────────────────────────────────────────

  @UseGuards(JwtAuthGuard)
  @Post('categories')
  createCategory(@Body() body: any) {
    return this.catalogService.createCategory(body);
  }

  @Get('verticals/:verticalId/categories')
  getCategories(@Param('verticalId') verticalId: string) {
    return this.catalogService.getCategoriesByVertical(verticalId);
  }

  // ─── AI Integration ────────────────────────────────────────────────────────

  @Post('ai-import')
  @UseGuards(JwtAuthGuard)
  async importMenuViaAI(@Body() body: { imageBase64: string }) {
    const items = await this.aiService.parseMenuImage(body.imageBase64);
    return items;
  }

  @Post('ai-order')
  @UseGuards(JwtAuthGuard)
  async aiOrder(@Body() body: { prompt: string; storeId: string }) {
    const products = await this.catalogService.getProductsByStore(body.storeId);
    const cartItems = await this.aiService.parseOrderRequest(body.prompt, products);
    return cartItems;
  }

  // ─── Products ──────────────────────────────────────────────────────────────

  @UseGuards(JwtAuthGuard)
  @Post('products')
  createProduct(@Body() body: any) {
    return this.catalogService.createProduct(body);
  }

  @Post('stores/:storeId/products/batch')
  @UseGuards(JwtAuthGuard)
  async batchCreateProducts(
    @Param('storeId') storeId: string,
    @Body() body: { items: any[] },
  ) {
    return this.catalogService.batchCreateProducts(storeId, body.items);
  }

  @Get('stores/:storeId/products')
  getProductsByStore(@Param('storeId') storeId: string) {
    return this.catalogService.getProductsByStore(storeId);
  }

  @Get('products/:id')
  getProductDetails(@Param('id') id: string) {
    return this.catalogService.getProductDetails(id);
  }

  @UseGuards(JwtAuthGuard)
  @Put('products/:id')
  updateProduct(@Param('id') id: string, @Body() body: any) {
    return this.catalogService.updateProduct(id, body);
  }

  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  @Delete('products/:id')
  deleteProduct(@Param('id') id: string) {
    return this.catalogService.deleteProduct(id);
  }

  @UseGuards(JwtAuthGuard)
  @Put('products/:id/availability')
  toggleAvailability(
    @Param('id') id: string,
    @Body() body: { isAvailable: boolean },
  ) {
    return this.catalogService.toggleAvailability(id, body.isAvailable);
  }

  // ─── Modifiers ─────────────────────────────────────────────────────────────

  @Get('products/:id/modifiers')
  getModifierGroups(@Param('id') productId: string) {
    return this.catalogService.getModifierGroups(productId);
  }

  @UseGuards(JwtAuthGuard)
  @Post('products/:id/modifiers')
  createModifierGroup(@Param('id') productId: string, @Body() body: any) {
    return this.catalogService.createModifierGroup(productId, body);
  }
}
