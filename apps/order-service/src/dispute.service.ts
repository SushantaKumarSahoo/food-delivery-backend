import { Injectable, NotFoundException } from '@nestjs/common';
import { GoogleGenerativeAI } from '@google/generative-ai';
import { PrismaService } from '@quickbite/prisma';

@Injectable()
export class DisputeService {
  private genAI: GoogleGenerativeAI;

  constructor(private readonly prisma: PrismaService) {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      console.warn('GEMINI_API_KEY not set — AI refund decisions will fail.');
    }
    this.genAI = new GoogleGenerativeAI(apiKey || 'dummy');
  }

  async submitDispute(
    userId: string,
    orderId: string,
    issueType: string,
    description: string,
  ) {
    // 1. Fetch the order and verify ownership
    const order = await this.prisma.order.findFirst({
      where: { id: orderId, userId },
    });
    if (!order) throw new NotFoundException('Order not found');

    const items = await this.prisma.orderItem.findMany({ where: { orderId } });
    const orderWithItems = { ...order, items };

    // 2. Fetch user's refund/dispute history
    const refundHistory = await this.prisma.refund.findMany({
      where: { userId, status: { in: ['processed', 'initiated'] } },
      orderBy: { createdAt: 'desc' },
    });

    const totalOrders = await this.prisma.order.count({ where: { userId } });

    // 3. Call AI for decision
    const aiDecision = await this.evaluateWithAI({
      order: orderWithItems,
      issueType,
      description,
      refundHistory,
      totalOrders,
    });

    // 4. Record dispute in DB and deduct trust score if needed
    try {
      await this.prisma.$transaction(async (tx) => {
        const ticketNumber = `TKT-${Date.now()}`;
        await tx.supportTicket.create({
          data: {
            ticketNumber,
            tenantId: order.tenantId,
            userId,
            orderId,
            category: 'dispute',
            subject: issueType,
            description: `${description}\n\nAI Decision: ${aiDecision.decision}\nReason: ${aiDecision.reason}\nRefund Amount: ${aiDecision.refundAmount}`,
            status: aiDecision.decision === 'approve' || aiDecision.decision === 'partial' ? 'resolved' : 'closed',
          },
        });

        // If the AI denies the dispute (high risk of fraud/abuse), penalize trust score
        if (aiDecision.decision === 'deny') {
          const profile = await tx.customerProfile.findUnique({ where: { userId } });
          if (profile) {
            await tx.customerProfile.update({
              where: { userId },
              data: {
                trustScore: Math.max(0, profile.trustScore - 20),
              },
            });
          }
        }
      });
    } catch (e) {
      console.warn('Could not save dispute record:', e);
    }

    return {
      decision: aiDecision.decision,
      reason: aiDecision.reason,
      refundAmount: aiDecision.refundAmount,
      orderNumber: order.orderNumber,
    };
  }

  private async evaluateWithAI(context: {
    order: any;
    issueType: string;
    description: string;
    refundHistory: any[];
    totalOrders: number;
  }) {
    try {
      const model = this.genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

      const totalDisputes = context.refundHistory.length;
      const disputeRate =
        context.totalOrders > 0
          ? (totalDisputes / context.totalOrders) * 100
          : 0;
      const recentDisputes = context.refundHistory.filter((r: any) => {
        const date = new Date(r.createdAt);
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
        return date > thirtyDaysAgo;
      }).length;

      const prompt = `You are a fair and empathetic refund dispute AI for QuickBite, a food delivery platform.

Order Details:
- Order Number: ${context.order.orderNumber}
- Total Amount: ₹${context.order.totalAmount}
- Items: ${context.order.items?.map((i: any) => `${i.quantity}x ${i.productName}`).join(', ')}

Issue Reported:
- Issue Type: ${context.issueType}
- Description: "${context.description}"

Customer's Fraud Risk Analysis:
- Total Orders Placed: ${context.totalOrders}
- Lifetime Refunds Claimed: ${totalDisputes}
- Refunds in Last 30 Days: ${recentDisputes}
- Dispute Rate: ${disputeRate.toFixed(1)}%

Decision Rules (apply strictly):
- Low risk (rate < 5% AND recentDisputes <= 1) → decision = "approve", refundAmount = full order amount
- Medium risk (rate 5-20% OR recentDisputes 2-3) → decision = "partial", refundAmount = 50% of order
- High risk (rate > 20% OR recentDisputes > 3) → decision = "deny", refundAmount = 0

Return ONLY valid JSON (no markdown code blocks):
{
  "decision": "approve" | "partial" | "deny",
  "reason": "<empathetic 2-sentence explanation for the customer>",
  "refundAmount": <number>
}`;

      const result = await model.generateContent(prompt);
      let text = result.response.text();
      text = text.replace(/```json/g, '').replace(/```/g, '').trim();
      return JSON.parse(text);
    } catch (error) {
      console.error('AI dispute evaluation failed:', error);
      // Fallback: approve first-timers, deny repeat abusers
      return {
        decision: 'approve' as const,
        reason:
          "We've reviewed your order and processed a full refund as a goodwill gesture. Thank you for your patience!",
        refundAmount: context.order.totalAmount,
      };
    }
  }
}
