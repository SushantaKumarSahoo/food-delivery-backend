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
import { JwtAuthGuard } from '@quickbite/common';

@Controller('catalog')
export class CatalogController {
  constructor(private readonly catalogService: CatalogService) {}

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

  // ─── Products ──────────────────────────────────────────────────────────────

  @UseGuards(JwtAuthGuard)
  @Post('products')
  createProduct(@Body() body: any) {
    return this.catalogService.createProduct(body);
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
