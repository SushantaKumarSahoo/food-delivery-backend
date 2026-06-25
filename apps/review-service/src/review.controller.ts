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
import { ReviewService } from './review.service';
import { CurrentUser, JwtAuthGuard } from '@quickbite/common';

@Controller('reviews')
export class ReviewController {
  constructor(private readonly reviewService: ReviewService) {}

  @UseGuards(JwtAuthGuard)
  @Post()
  createReview(@CurrentUser() user: any, @Body() body: any) {
    return this.reviewService.createReview(user.userId, body);
  }

  @Get('entity/:entityId')
  getReviewsForEntity(@Param('entityId') entityId: string) {
    return this.reviewService.getReviewsForEntity(entityId);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  getMyReviews(@CurrentUser() user: any) {
    return this.reviewService.getMyReviews(user.userId);
  }

  @UseGuards(JwtAuthGuard)
  @Put(':id/approve')
  approveReview(@Param('id') id: string) {
    return this.reviewService.approveReview(id);
  }

  @UseGuards(JwtAuthGuard)
  @Put(':id/reject')
  rejectReview(@Param('id') id: string) {
    return this.reviewService.rejectReview(id);
  }

  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  @Post(':id/vote')
  voteReview(
    @Param('id') id: string,
    @CurrentUser() user: any,
    @Body() body: { isHelpful: boolean },
  ) {
    return this.reviewService.voteReview(id, user.userId, body.isHelpful);
  }
}
