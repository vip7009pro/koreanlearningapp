import { Controller, Get, Post, Patch, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { UserRole } from '@prisma/client';
import { DialoguesService } from './dialogues.service';
import { CreateDialogueDto, UpdateDialogueDto } from './dto/dialogue.dto';
import { Roles } from '../../common/decorators/roles.decorator';
import { RolesGuard } from '../../common/guards/roles.guard';

@ApiTags('dialogues')
@Controller('dialogues')
export class DialoguesController {
  constructor(private dialoguesService: DialoguesService) {}

  @Post()
  @UseGuards(AuthGuard('jwt'), RolesGuard) @Roles(UserRole.ADMIN) @ApiBearerAuth()
  @ApiOperation({ summary: 'Create dialogue (Admin only)' })
  create(@Body() dto: CreateDialogueDto) { return this.dialoguesService.create(dto); }

  @Get()
  @ApiOperation({ summary: 'Get dialogues by lesson' })
  @ApiQuery({ name: 'lessonId', required: true })
  findByLesson(@Query('lessonId') lessonId: string) { return this.dialoguesService.findByLesson(lessonId); }

  @Get(':id')
  @ApiOperation({ summary: 'Get dialogue by ID' })
  findOne(@Param('id') id: string) { return this.dialoguesService.findOne(id); }

  @Patch(':id')
  @UseGuards(AuthGuard('jwt'), RolesGuard) @Roles(UserRole.ADMIN) @ApiBearerAuth()
  @ApiOperation({ summary: 'Update dialogue (Admin only)' })
  update(@Param('id') id: string, @Body() dto: UpdateDialogueDto) { return this.dialoguesService.update(id, dto); }

  @Delete(':id')
  @UseGuards(AuthGuard('jwt'), RolesGuard) @Roles(UserRole.ADMIN) @ApiBearerAuth()
  @ApiOperation({ summary: 'Delete dialogue (Admin only)' })
  remove(@Param('id') id: string) { return this.dialoguesService.remove(id); }
}
