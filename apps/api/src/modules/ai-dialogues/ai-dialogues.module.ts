import { Module } from '@nestjs/common';
import { AIDialoguesService } from './ai-dialogues.service';
import { AIDialoguesController } from './ai-dialogues.controller';
import { AIModule } from '../ai/ai.module';

@Module({
  imports: [AIModule],
  controllers: [AIDialoguesController],
  providers: [AIDialoguesService],
  exports: [AIDialoguesService],
})
export class AIDialoguesModule {}
