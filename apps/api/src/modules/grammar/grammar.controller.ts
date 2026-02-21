import { Controller, Get, Post, Body, Query, Param, Patch, Delete, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { UserRole } from '@prisma/client';
import { GrammarService } from './grammar.service';
import { CreateGrammarDto, UpdateGrammarDto } from './dto/grammar.dto';
import { Roles } from '../../common/decorators/roles.decorator';
import { RolesGuard } from '../../common/guards/roles.guard';

@ApiTags('grammar')
@Controller('grammar')
export class GrammarController {
  constructor(private grammarService: GrammarService) {}

  @Post()
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create grammar (Admin only)' })
  create(@Body() dto: CreateGrammarDto) { return this.grammarService.create(dto); }

  @Get()
  @ApiOperation({ summary: 'Get grammar by lesson' })
  @ApiQuery({ name: 'lessonId', required: true })
  findByLesson(@Query('lessonId') lessonId: string) { return this.grammarService.findByLesson(lessonId); }

  @Get(':id')
  @ApiOperation({ summary: 'Get grammar by ID' })
  findOne(@Param('id') id: string) { return this.grammarService.findOne(id); }

  @Patch(':id')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update grammar (Admin only)' })
  update(@Param('id') id: string, @Body() dto: UpdateGrammarDto) { return this.grammarService.update(id, dto); }

  @Delete(':id')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Delete grammar (Admin only)' })
  remove(@Param('id') id: string) { return this.grammarService.remove(id); }

  @Post('bulk-delete')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Bulk delete grammar (Admin only)' })
  bulkDelete(@Body() body: { ids: string[] }) {
    return this.grammarService.removeMany(body?.ids || []);
  }
}
