import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ServiceUnavailableException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { PlanType } from '@prisma/client';
import axios from 'axios';
import { GoogleAuth } from 'google-auth-library';

type GooglePlayVerifyInput = {
  productId: string;
  purchaseToken: string;
  packageName?: string;
  orderId?: string;
  planType?: PlanType;
};

@Injectable()
export class SubscriptionsService {
  private readonly logger = new Logger(SubscriptionsService.name);

  constructor(private prisma: PrismaService) {}

  private get monthlyProductId(): string {
    return process.env.GOOGLE_PLAY_MONTHLY_PRODUCT_ID || 'premium_monthly';
  }

  private get annualProductId(): string {
    return process.env.GOOGLE_PLAY_ANNUAL_PRODUCT_ID || 'premium_annual2';
  }

  private get packageName(): string {
    return process.env.GOOGLE_PLAY_PACKAGE_NAME || 'com.hnp.korean_learning_app';
  }

  private get serviceAccountJson() {
    const raw = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON;
    if (!raw) return null;

    try {
      return JSON.parse(raw);
    } catch (error) {
      throw new ServiceUnavailableException('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON is invalid JSON');
    }
  }

  private resolvePlanTypeFromProductId(productId: string): PlanType {
    const normalized = String(productId || '').trim();
    if (!normalized) {
      throw new BadRequestException('productId is required');
    }

    if (normalized === this.monthlyProductId) {
      return 'PREMIUM';
    }

    if (normalized === this.annualProductId) {
      return 'LIFETIME';
    }

    throw new BadRequestException(`Unknown Google Play productId: ${normalized}`);
  }

  private resolveProductIdFromPlanType(planType: PlanType): string {
    switch (planType) {
      case 'PREMIUM':
        return this.monthlyProductId;
      case 'LIFETIME':
        return this.annualProductId;
      default:
        return '';
    }
  }

  private getPlanDurationMs(planType: PlanType): number {
    return planType === 'PREMIUM'
      ? 30 * 24 * 60 * 60 * 1000
      : 365 * 24 * 60 * 60 * 1000;
  }

  private async getGooglePlayAccessToken(): Promise<string> {
    const credentials = this.serviceAccountJson;
    const keyFile = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_KEY_FILE;

    if (!credentials && !keyFile) {
      throw new ServiceUnavailableException(
        'Google Play service account is not configured. Set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON or GOOGLE_PLAY_SERVICE_ACCOUNT_KEY_FILE.',
      );
    }

    const auth = new GoogleAuth({
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
      ...(credentials ? { credentials } : {}),
      ...(keyFile ? { keyFile } : {}),
    });

    const client = await auth.getClient();
    const token = await client.getAccessToken();
    if (!token?.token) {
      throw new ServiceUnavailableException('Unable to obtain Google Play access token');
    }

    return token.token;
  }

  private async verifyGooglePlayPurchase(packageName: string, purchaseToken: string): Promise<any> {
    const accessToken = await this.getGooglePlayAccessToken();
    const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/subscriptionsv2/tokens/${purchaseToken}`;

    try {
      const response = await axios.get(url, {
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
        timeout: 30000,
      });

      return response.data;
    } catch (error) {
      this.logger.error(
        {
          packageName,
          error: error instanceof Error ? error.message : String(error),
        },
        'Google Play subscription verification failed',
      );
      throw new BadRequestException('Không thể xác minh giao dịch Google Play');
    }
  }

  async getCurrentSubscription(userId: string) {
    return this.prisma.subscription.findFirst({
      where: { userId, status: 'ACTIVE' },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getSubscriptionHistory(userId: string) {
    return this.prisma.subscription.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Mock payment + subscription creation.
   * In production, integrate with actual payment provider (Stripe, PayPal, etc.)
   */
  async subscribe(userId: string, planType: PlanType) {
    // Cancel any existing active subscriptions
    await this.prisma.subscription.updateMany({
      where: { userId, status: 'ACTIVE' },
      data: { status: 'CANCELLED' },
    });

    const endDate = planType === 'LIFETIME'
      ? null
      : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 days

    const subscription = await this.prisma.subscription.create({
      data: {
        userId,
        planType,
        startDate: new Date(),
        endDate,
        status: 'ACTIVE',
      },
    });

    return {
      subscription,
      payment: {
        status: 'SUCCESS',
        amount: this.getPlanPrice(planType),
        currency: 'VND',
        transactionId: `MOCK_${Date.now()}`,
      },
    };
  }

  async verifyGooglePlaySubscription(userId: string, input: GooglePlayVerifyInput) {
    const packageName = String(input.packageName || this.packageName).trim();
    if (!packageName) {
      throw new ServiceUnavailableException('GOOGLE_PLAY_PACKAGE_NAME is not configured');
    }

    const purchaseToken = String(input.purchaseToken || '').trim();
    if (!purchaseToken) {
      throw new BadRequestException('purchaseToken is required');
    }

    const productId = String(input.productId || '').trim();
    const verifiedResponse = await this.verifyGooglePlayPurchase(packageName, purchaseToken);
    const lineItem = verifiedResponse?.lineItems?.[0] || {};
    const expectedProductId = input.planType ? this.resolveProductIdFromPlanType(input.planType) : '';
    const verifiedProductId = String(lineItem.productId || productId || expectedProductId).trim();
    const planType = input.planType || this.resolvePlanTypeFromProductId(verifiedProductId);
    const expirySource = lineItem.expiryTime || verifiedResponse?.expiryTime || null;
    const expiryDate = expirySource ? new Date(expirySource) : null;
    const endDate = expiryDate && !Number.isNaN(expiryDate.getTime())
      ? expiryDate
      : new Date(Date.now() + this.getPlanDurationMs(planType));

    await this.prisma.subscription.updateMany({
      where: { userId, status: 'ACTIVE' },
      data: { status: 'CANCELLED' },
    });

    const subscription = await this.prisma.subscription.create({
      data: {
        userId,
        planType,
        startDate: new Date(),
        endDate,
        status: 'ACTIVE',
      },
    });

    return {
      verified: true,
      provider: 'google_play',
      packageName,
      productId: verifiedProductId,
      orderId: verifiedResponse?.latestOrderId || input.orderId || null,
      expiryDate: endDate.toISOString(),
      subscription,
    };
  }

  async cancelSubscription(userId: string) {
    const sub = await this.prisma.subscription.findFirst({
      where: { userId, status: 'ACTIVE' },
    });
    if (!sub) throw new NotFoundException('No active subscription found');

    return this.prisma.subscription.update({
      where: { id: sub.id },
      data: { status: 'CANCELLED' },
    });
  }

  async checkPremium(userId: string): Promise<boolean> {
    const sub = await this.prisma.subscription.findFirst({
      where: { userId, status: 'ACTIVE', planType: { in: ['PREMIUM', 'LIFETIME'] } },
    });
    if (!sub) return false;
    if (sub.endDate && new Date(sub.endDate) < new Date()) return false;
    return true;
  }

  getPlans() {
    return [
      { type: 'FREE', price: 0, currency: 'VND', features: ['5 bài học miễn phí', 'Từ vựng cơ bản', 'Bài kiểm tra giới hạn'] },
      {
        type: 'PREMIUM',
        price: 199000,
        currency: 'VND',
        duration: '30 ngày',
        androidProductId: this.monthlyProductId,
        features: ['Toàn bộ bài học', 'AI Writing Practice', 'Không giới hạn bài kiểm tra', 'Ôn tập SRS', 'Tải về học offline'],
      },
      {
        type: 'LIFETIME',
        price: 1990000,
        currency: 'VND',
        duration: '12 tháng',
        androidProductId: this.annualProductId,
        features: ['Tất cả tính năng Premium', 'Cập nhật nội dung miễn phí trong thời hạn gói', 'Ưu tiên hỗ trợ'],
      },
    ];
  }

  private getPlanPrice(planType: PlanType): number {
    switch (planType) {
      case 'FREE': return 0;
      case 'PREMIUM': return 199000;
      case 'LIFETIME': return 1990000;
      default: return 0;
    }
  }
}
