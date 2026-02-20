import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { AppModule } from './app.module';
import cookieParser from 'cookie-parser';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.setGlobalPrefix('api');
  app.use(cookieParser());
  app.enableCors({
    origin: ['http://localhost:5173', 'http://localhost:3001'],
    credentials: true,
  });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  const config = new DocumentBuilder()
    .setTitle('Korean Learning Platform API')
    .setDescription('API for the Korean Learning Platform')
    .setVersion('1.0')
    .addBearerAuth()
    .addTag('auth', 'Authentication endpoints')
    .addTag('users', 'User management')
    .addTag('courses', 'Course management')
    .addTag('sections', 'Section management')
    .addTag('lessons', 'Lesson management')
    .addTag('vocabulary', 'Vocabulary management')
    .addTag('grammar', 'Grammar management')
    .addTag('dialogues', 'Dialogue management')
    .addTag('quizzes', 'Quiz management')
    .addTag('progress', 'User progress tracking')
    .addTag('reviews', 'Spaced repetition reviews')
    .addTag('ai', 'AI practice module')
    .addTag('gamification', 'Gamification features')
    .addTag('subscriptions', 'Subscription management')
    .addTag('analytics', 'Analytics tracking')
    .addTag('upload', 'File upload')
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);

  const port = process.env.PORT || 3000;
  await app.listen(port);
  console.log(`🚀 API running on http://localhost:${port}`);
  console.log(`📚 Swagger docs at http://localhost:${port}/api/docs`);
}

bootstrap();
