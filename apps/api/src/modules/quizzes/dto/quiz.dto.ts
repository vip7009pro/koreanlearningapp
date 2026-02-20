import { IsString, IsEnum, IsOptional, IsNotEmpty, IsUUID, IsArray, ValidateNested, IsBoolean } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { QuizType, QuestionType } from '@prisma/client';
import { Type } from 'class-transformer';

export class CreateQuizDto {
  @ApiProperty() @IsUUID() lessonId: string;
  @ApiProperty({ example: 'Greetings Quiz' }) @IsString() @IsNotEmpty() title: string;
  @ApiProperty({ enum: QuizType }) @IsEnum(QuizType) quizType: QuizType;
}

export class UpdateQuizDto {
  @ApiPropertyOptional() @IsOptional() @IsString() title?: string;
  @ApiPropertyOptional({ enum: QuizType }) @IsOptional() @IsEnum(QuizType) quizType?: QuizType;
}

export class OptionInput {
  @ApiProperty({ example: '안녕하세요' }) @IsString() text: string;
  @ApiProperty({ example: true }) @IsBoolean() isCorrect: boolean;
}

export class CreateQuestionDto {
  @ApiProperty() @IsUUID() quizId: string;
  @ApiProperty({ enum: QuestionType }) @IsEnum(QuestionType) questionType: QuestionType;
  @ApiProperty({ example: 'How do you say "Hello" in Korean?' }) @IsString() @IsNotEmpty() questionText: string;
  @ApiPropertyOptional() @IsOptional() @IsString() audioUrl?: string;
  @ApiProperty({ example: '안녕하세요' }) @IsString() @IsNotEmpty() correctAnswer: string;
  @ApiPropertyOptional({ type: [OptionInput] }) @IsOptional() @IsArray() @ValidateNested({ each: true }) @Type(() => OptionInput)
  options?: OptionInput[];
}

export class UpdateQuestionDto {
  @ApiPropertyOptional() @IsOptional() @IsString() questionText?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() correctAnswer?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() audioUrl?: string;
  @ApiPropertyOptional({ enum: QuestionType }) @IsOptional() @IsEnum(QuestionType) questionType?: QuestionType;
}

export class QuizAnswerInput {
  @ApiProperty() @IsString() questionId: string;
  @ApiProperty() @IsString() answer: string;
}

export class SubmitQuizDto {
  @ApiProperty({ type: [QuizAnswerInput] }) @IsArray() @ValidateNested({ each: true }) @Type(() => QuizAnswerInput)
  answers: QuizAnswerInput[];
}
