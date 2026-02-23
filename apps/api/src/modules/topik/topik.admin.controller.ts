import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { UserRole } from '@prisma/client';
import { Roles } from '../../common/decorators/roles.decorator';
import { RolesGuard } from '../../common/guards/roles.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { TopikService } from './topik.service';
import {
  CreateTopikExamDto,
  CreateTopikQuestionDto,
  CreateTopikSectionDto,
  ImportTopikExamDto,
  UpdateTopikExamDto,
  UpdateTopikQuestionDto,
  UpdateTopikSectionDto,
} from './dto/topik.dto';

@ApiTags('topik-admin')
@Controller('topik/admin')
export class AdminTopikController {
  constructor(private readonly topikService: TopikService) {}

  @Post('exams')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create TOPIK exam (Admin)' })
  createExam(@CurrentUser('email') email: string, @Body() dto: CreateTopikExamDto) {
    return this.topikService.adminCreateExam({ ...dto, createdBy: email });
  }

  @Get('exams')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'List all exams (Admin)' })
  listExams() {
    return this.topikService.adminListExams();
  }

  @Get('exams/:id')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get exam full detail (Admin)' })
  getExam(@Param('id') id: string) {
    return this.topikService.adminGetExam(id);
  }

  @Patch('exams/:id')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update exam (Admin)' })
  updateExam(@Param('id') id: string, @Body() dto: UpdateTopikExamDto) {
    return this.topikService.adminUpdateExam(id, dto);
  }

  @Post('exams/:id/publish')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Publish exam (Admin)' })
  publish(@Param('id') id: string) {
    return this.topikService.adminPublishExam(id, true);
  }

  @Post('exams/:id/unpublish')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Unpublish exam (Admin)' })
  unpublish(@Param('id') id: string) {
    return this.topikService.adminPublishExam(id, false);
  }

  @Delete('exams/:id')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Delete exam (Admin)' })
  removeExam(@Param('id') id: string) {
    return this.topikService.adminRemoveExam(id);
  }

  @Post('sections')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create section (Admin)' })
  createSection(@Body() dto: CreateTopikSectionDto) {
    return this.topikService.adminCreateSection(dto);
  }

  @Patch('sections/:id')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update section (Admin)' })
  updateSection(@Param('id') id: string, @Body() dto: UpdateTopikSectionDto) {
    return this.topikService.adminUpdateSection(id, dto as any);
  }

  @Post('questions')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create question (Admin)' })
  createQuestion(@Body() dto: CreateTopikQuestionDto) {
    return this.topikService.adminCreateQuestion(dto);
  }

  @Patch('questions/:id')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update question (Admin)' })
  updateQuestion(@Param('id') id: string, @Body() dto: UpdateTopikQuestionDto) {
    return this.topikService.adminUpdateQuestion(id, dto as any);
  }

  @Post('import')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Import exam from JSON (Admin)' })
  importExam(@CurrentUser('email') email: string, @Body() dto: ImportTopikExamDto) {
    return this.topikService.adminImportExam(dto.payload, email);
  }
}
