import { Controller, Get, Post, Body, Query, Param, Patch, Delete, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { UserRole } from '@prisma/client';
import { VocabularyService } from './vocabulary.service';
import { CreateVocabularyDto, UpdateVocabularyDto } from './dto/vocabulary.dto';
import { Roles } from '../../common/decorators/roles.decorator';
import { RolesGuard } from '../../common/guards/roles.guard';

@ApiTags('vocabulary')
@Controller('vocabulary')
export class VocabularyController {
  constructor(private vocabularyService: VocabularyService) {}

  @Post()
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create vocabulary (Admin only)' })
  create(@Body() dto: CreateVocabularyDto) {
    return this.vocabularyService.create(dto);
  }

  @Post('bulk')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create multiple vocabulary items (Admin only)' })
  createMany(@Body() items: CreateVocabularyDto[]) {
    return this.vocabularyService.createMany(items);
  }

  @Get()
  @ApiOperation({ summary: 'Get vocabulary by lesson' })
  @ApiQuery({ name: 'lessonId', required: true })
  @ApiQuery({ name: 'page', required: false })
  @ApiQuery({ name: 'limit', required: false })
  findByLesson(
    @Query('lessonId') lessonId: string,
    @Query('page') page = 1,
    @Query('limit') limit = 200,
  ) {
    return this.vocabularyService.findByLesson(lessonId, page, limit);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get vocabulary by ID' })
  findOne(@Param('id') id: string) {
    return this.vocabularyService.findOne(id);
  }

  @Patch(':id')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update vocabulary (Admin only)' })
  update(@Param('id') id: string, @Body() dto: UpdateVocabularyDto) {
    return this.vocabularyService.update(id, dto);
  }

  @Delete(':id')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Delete vocabulary (Admin only)' })
  remove(@Param('id') id: string) {
    return this.vocabularyService.remove(id);
  }

  @Post('bulk-delete')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Bulk delete vocabulary (Admin only)' })
  bulkDelete(@Body() body: { ids: string[] }) {
    return this.vocabularyService.removeMany(body?.ids || []);
  }
}
