import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { CmsService } from './cms.service';
import { JwtAuthGuard } from '@quickbite/common';

@Controller('cms')
export class CmsController {
  constructor(private readonly cmsService: CmsService) {}

  // ─── Banners ───────────────────────────────────────────────────────────────

  @Get('banners')
  getBanners(@Query('placement') placement?: string) {
    return this.cmsService.getBanners(placement);
  }

  @UseGuards(JwtAuthGuard)
  @Post('banners')
  createBanner(@Body() body: any) {
    return this.cmsService.createBanner(body);
  }

  @UseGuards(JwtAuthGuard)
  @Put('banners/:id')
  updateBanner(@Param('id') id: string, @Body() body: any) {
    return this.cmsService.updateBanner(id, body);
  }

  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  @Delete('banners/:id')
  deleteBanner(@Param('id') id: string) {
    return this.cmsService.deleteBanner(id);
  }

  // ─── Sections ──────────────────────────────────────────────────────────────

  @Get('sections')
  getSections() {
    return this.cmsService.getHomeSections();
  }

  @UseGuards(JwtAuthGuard)
  @Post('sections')
  createSection(@Body() body: any) {
    return this.cmsService.createSection(body);
  }

  @UseGuards(JwtAuthGuard)
  @Put('sections/:id')
  updateSection(@Param('id') id: string, @Body() body: any) {
    return this.cmsService.updateSection(id, body);
  }

  // ─── Promotions ────────────────────────────────────────────────────────────

  @Get('promotions/active')
  getActivePromotions() {
    return this.cmsService.getActivePromotions();
  }

  @UseGuards(JwtAuthGuard)
  @Post('promotions')
  createPromotion(@Body() body: any) {
    return this.cmsService.createPromotion(body);
  }
}
