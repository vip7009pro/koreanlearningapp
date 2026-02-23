import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bull';
import { AIModule } from '../ai/ai.module';
import { TopikService } from './topik.service';
import { TopikController } from './topik.controller';
import { AdminTopikController } from './topik.admin.controller';
import { AiReviewService } from './topik.ai-review.service';
import { TOPIK_QUEUE, TopikQueueProcessor } from './topik.queue';

@Module({
  imports: [AIModule, BullModule.registerQueue({ name: TOPIK_QUEUE })],
  controllers: [TopikController, AdminTopikController],
  providers: [TopikService, AiReviewService, TopikQueueProcessor],
  exports: [TopikService],
})
export class TopikModule {}
