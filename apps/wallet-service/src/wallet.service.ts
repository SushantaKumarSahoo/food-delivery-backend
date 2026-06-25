import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '@quickbite/prisma';

@Injectable()
export class WalletService {
  constructor(private readonly prisma: PrismaService) {}

  private async getOrCreateWallet(userId: string) {
    let wallet = await (this.prisma as any).wallet.findFirst({
      where: { userId },
    });
    if (!wallet) {
      const tenant = await this.prisma.platformTenant.findFirst();
      wallet = await (this.prisma as any).wallet.create({
        data: {
          userId,
          tenantId: tenant?.id || 'default-tenant',
          balance: 0,
          currency: 'INR',
        },
      });
    }
    return wallet;
  }

  async getBalance(userId: string) {
    const wallet = await this.getOrCreateWallet(userId);
    return { balance: wallet.balance, currency: wallet.currency };
  }

  async topUp(userId: string, amount: number, method: string) {
    if (amount <= 0) throw new BadRequestException('Amount must be positive');
    const wallet = await this.getOrCreateWallet(userId);

    await (this.prisma as any).wallet.update({
      where: { id: wallet.id },
      data: { balance: wallet.balance + amount },
    });

    await (this.prisma as any).walletTransaction.create({
      data: {
        walletId: wallet.id,
        userId,
        type: 'credit',
        amount,
        method,
        description: `Wallet top-up via ${method}`,
        status: 'success',
      },
    });

    return { message: 'Wallet topped up', balance: wallet.balance + amount };
  }

  async deduct(userId: string, amount: number, orderId: string) {
    const wallet = await this.getOrCreateWallet(userId);
    if (wallet.balance < amount) {
      throw new BadRequestException('Insufficient wallet balance');
    }

    await (this.prisma as any).wallet.update({
      where: { id: wallet.id },
      data: { balance: wallet.balance - amount },
    });

    await (this.prisma as any).walletTransaction.create({
      data: {
        walletId: wallet.id,
        userId,
        type: 'debit',
        amount,
        referenceId: orderId,
        description: `Payment for order ${orderId}`,
        status: 'success',
      },
    });

    return { message: 'Payment deducted', balance: wallet.balance - amount };
  }

  async credit(userId: string, amount: number, reason: string, referenceId?: string) {
    const wallet = await this.getOrCreateWallet(userId);
    await (this.prisma as any).wallet.update({
      where: { id: wallet.id },
      data: { balance: wallet.balance + amount },
    });

    await (this.prisma as any).walletTransaction.create({
      data: {
        walletId: wallet.id,
        userId,
        type: 'credit',
        amount,
        referenceId,
        description: reason,
        status: 'success',
      },
    });
  }

  async getTransactions(userId: string) {
    const wallet = await this.getOrCreateWallet(userId);
    return (this.prisma as any).walletTransaction.findMany({
      where: { walletId: wallet.id },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  async handleRefund(payload: any) {
    const { userId, amount, orderId } = payload;
    await this.credit(userId, amount, `Refund for order ${orderId}`, orderId);
  }
}
