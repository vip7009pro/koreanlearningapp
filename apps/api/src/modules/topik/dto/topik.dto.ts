import {
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  Min,
  ValidateNested,
  Allow,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  TopikExamStatus,
  TopikLevel,
  TopikQuestionType,
  TopikSectionType,
} from '@prisma/client';
import { Type } from 'class-transformer';

export class TopikExamQueryDto {
  @ApiPropertyOptional({ enum: TopikLevel })
  @IsOptional()
  @IsEnum(TopikLevel)
  topikLevel?: TopikLevel;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(1990)
  @Max(2100)
  year?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  level?: string;

  @ApiPropertyOptional({ enum: TopikSectionType, isArray: true })
  @IsOptional()
  @IsArray()
  @IsEnum(TopikSectionType, { each: true })
  types?: TopikSectionType[];
}

export class CreateTopikExamDto {
  @ApiProperty() @IsString() @IsNotEmpty() title: string;
  @ApiProperty() @IsInt() @Min(1990) @Max(2100) year: number;
  @ApiProperty({ enum: TopikLevel }) @IsEnum(TopikLevel) topikLevel: TopikLevel;
  @ApiPropertyOptional() @IsOptional() @IsString() level?: string;
  @ApiProperty() @IsInt() @Min(1) @Max(600) durationMinutes: number;
  @ApiProperty() @IsInt() @Min(1) @Max(500) totalQuestions: number;
  @ApiPropertyOptional({ enum: TopikExamStatus })
  @IsOptional()
  @IsEnum(TopikExamStatus)
  status?: TopikExamStatus;
}

export class UpdateTopikExamDto {
  @ApiPropertyOptional() @IsOptional() @IsString() title?: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1990) @Max(2100) year?: number;
  @ApiPropertyOptional({ enum: TopikLevel })
  @IsOptional()
  @IsEnum(TopikLevel)
  topikLevel?: TopikLevel;
  @ApiPropertyOptional() @IsOptional() @IsString() level?: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) @Max(600) durationMinutes?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) @Max(500) totalQuestions?: number;
  @ApiPropertyOptional({ enum: TopikExamStatus })
  @IsOptional()
  @IsEnum(TopikExamStatus)
  status?: TopikExamStatus;
}

export class CreateTopikSectionDto {
  @ApiProperty() @IsUUID() examId: string;
  @ApiProperty({ enum: TopikSectionType }) @IsEnum(TopikSectionType) type: TopikSectionType;
  @ApiProperty() @IsInt() @Min(1) @Max(200) orderIndex: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) @Max(300) durationMinutes?: number;
  @ApiPropertyOptional({ description: 'Max score for this section (official TOPIK uses 100)' })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(300)
  maxScore?: number;
}

export class UpdateTopikSectionDto {
  @ApiPropertyOptional({ enum: TopikSectionType })
  @IsOptional()
  @IsEnum(TopikSectionType)
  type?: TopikSectionType;

  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) @Max(200) orderIndex?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) @Max(300) durationMinutes?: number;
  @ApiPropertyOptional({ description: 'Max score for this section (official TOPIK uses 100)' })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(300)
  maxScore?: number;
}

export class CreateTopikChoiceInput {
  @ApiProperty() @IsInt() @Min(1) @Max(20) orderIndex: number;
  @ApiProperty() @IsString() @IsNotEmpty() content: string;
  @ApiProperty() @IsBoolean() isCorrect: boolean;
}

export class CreateTopikQuestionDto {
  @ApiProperty() @IsUUID() examSectionId: string;
  @ApiProperty({ enum: TopikQuestionType }) @IsEnum(TopikQuestionType) questionType: TopikQuestionType;
  @ApiProperty() @IsInt() @Min(1) @Max(500) orderIndex: number;
  @ApiProperty() @IsString() @IsNotEmpty() contentHtml: string;
  @ApiPropertyOptional() @IsOptional() @IsString() audioUrl?: string;
  @ApiPropertyOptional({ description: 'Listening script for TTS/review when audioUrl is empty' })
  @IsOptional()
  @IsString()
  listeningScript?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() correctTextAnswer?: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) @Max(100) scoreWeight?: number;
  @ApiPropertyOptional() @IsOptional() @IsString() explanation?: string;

  @ApiPropertyOptional({ type: [CreateTopikChoiceInput] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateTopikChoiceInput)
  choices?: CreateTopikChoiceInput[];
}

export class UpdateTopikQuestionDto {
  @ApiPropertyOptional({ enum: TopikQuestionType })
  @IsOptional()
  @IsEnum(TopikQuestionType)
  questionType?: TopikQuestionType;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) @Max(500) orderIndex?: number;
  @ApiPropertyOptional() @IsOptional() @IsString() contentHtml?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() audioUrl?: string;
  @ApiPropertyOptional({ description: 'Listening script for TTS/review when audioUrl is empty' })
  @IsOptional()
  @IsString()
  listeningScript?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() correctTextAnswer?: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) @Max(100) scoreWeight?: number;
  @ApiPropertyOptional() @IsOptional() @IsString() explanation?: string;
}

export class StartTopikSessionDto {
  @ApiProperty() @IsUUID() examId: string;
}

export class SaveTopikAnswerDto {
  @ApiProperty() @IsUUID() questionId: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() selectedChoiceId?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() textAnswer?: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) @Max(500) currentQuestionIndex?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) @Max(86400) remainingSeconds?: number;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() flagged?: boolean;
}

export class SubmitTopikSessionDto {
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) @Max(86400) remainingSeconds?: number;
}

export class ImportTopikExamDto {
  @ApiProperty({ description: 'Exam payload (normalized) for import' })
  @Allow()
  payload: any;
}
