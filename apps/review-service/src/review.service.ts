import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '@quickbite/prisma';

@Injectable()
export class ReviewService {
  constructor(private readonly prisma: PrismaService) {}

  async createReview(userId: string, data: any) {
    const tenant = await this.prisma.platformTenant.findFirst();
    return this.prisma.review.create({
      data: {
        userId,
        tenantId: tenant!.id,
        orderId: data.orderId,
        reviewType: data.reviewType || 'store',
        entityId: data.entityId,
        overallRating: data.overallRating,
        foodQualityRating: data.foodRating || 5,
        deliveryRating: data.deliveryRating,
        body: data.body,
        status: 'pending',
      },
    });
  }

  async getReviewsForEntity(entityId: string) {
    return this.prisma.review.findMany({
      where: { entityId, status: 'approved' },
      orderBy: { createdAt: 'desc' },
      include: { media: true },
    });
  }

  async getMyReviews(userId: string) {
    return this.prisma.review.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async approveReview(reviewId: string) {
    const review = await this.prisma.review.findFirst({ where: { id: reviewId } });
    if (!review) throw new NotFoundException('Review not found');
    return this.prisma.review.update({
      where: { id: reviewId },
      data: { status: 'approved' },
    });
  }

  async rejectReview(reviewId: string) {
    const review = await this.prisma.review.findFirst({ where: { id: reviewId } });
    if (!review) throw new NotFoundException('Review not found');
    return this.prisma.review.update({
      where: { id: reviewId },
      data: { status: 'rejected' },
    });
  }

  async voteReview(reviewId: string, userId: string, isHelpful: boolean) {
    return (this.prisma as any).reviewVote.upsert({
      where: { reviewId_userId: { reviewId, userId } },
      update: { isHelpful },
      create: { reviewId, userId, isHelpful },
    });
  }
}
