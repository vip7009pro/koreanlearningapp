import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';
import { BullModule } from '@nestjs/bull';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { CoursesModule } from './modules/courses/courses.module';
import { SectionsModule } from './modules/sections/sections.module';
import { LessonsModule } from './modules/lessons/lessons.module';
import { VocabularyModule } from './modules/vocabulary/vocabulary.module';
import { GrammarModule } from './modules/grammar/grammar.module';
import { DialoguesModule } from './modules/dialogues/dialogues.module';
import { QuizzesModule } from './modules/quizzes/quizzes.module';
import { ProgressModule } from './modules/progress/progress.module';
import { ReviewsModule } from './modules/reviews/reviews.module';
import { AIModule } from './modules/ai/ai.module';
import { GamificationModule } from './modules/gamification/gamification.module';
import { SubscriptionsModule } from './modules/subscriptions/subscriptions.module';
import { AnalyticsModule } from './modules/analytics/analytics.module';
import { UploadModule } from './modules/upload/upload.module';
import { WebsocketModule } from './modules/websocket/websocket.module';
import { HealthModule } from './modules/health/health.module';
import { TopikModule } from './modules/topik/topik.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ScheduleModule.forRoot(),
    BullModule.forRoot({
      redis: {
        host: process.env.REDIS_HOST || 'localhost',
        port: parseInt(process.env.REDIS_PORT || '6379', 10),
      },
    }),
    PrismaModule,
    AuthModule,
    UsersModule,
    CoursesModule,
    SectionsModule,
    LessonsModule,
    VocabularyModule,
    GrammarModule,
    DialoguesModule,
    QuizzesModule,
    ProgressModule,
    ReviewsModule,
    AIModule,
    GamificationModule,
    SubscriptionsModule,
    AnalyticsModule,
    UploadModule,
    WebsocketModule,
    HealthModule,
    TopikModule,
  ],
})
export class AppModule {}
