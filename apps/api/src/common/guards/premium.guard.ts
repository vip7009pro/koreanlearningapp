import { Injectable, CanActivate, ExecutionContext, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class PremiumGuard implements CanActivate {
  constructor(private prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const user = request.user;

    if (!user) {
      return false;
    }

    if (user.role === 'ADMIN') {
      return true;
    }

    const subscription = await this.prisma.subscription.findFirst({
      where: {
        userId: user.id,
        status: 'ACTIVE',
        planType: { in: ['PREMIUM', 'LIFETIME'] },
      },
    });

    if (!subscription) {
      throw new ForbiddenException('Premium subscription required');
    }

    if (subscription.planType === 'PREMIUM' && subscription.endDate) {
      if (new Date(subscription.endDate) < new Date()) {
        throw new ForbiddenException('Subscription expired');
      }
    }

    return true;
  }
}
