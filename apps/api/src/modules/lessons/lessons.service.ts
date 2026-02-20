import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateLessonDto, UpdateLessonDto } from './dto/lesson.dto';

@Injectable()
export class LessonsService {
  constructor(private prisma: PrismaService) {}

  async create(dto: CreateLessonDto) {
    return this.prisma.lesson.create({ data: dto });
  }

  async findBySection(sectionId: string) {
    return this.prisma.lesson.findMany({
      where: { sectionId },
      orderBy: { orderIndex: 'asc' },
    });
  }

  async findOne(id: string) {
    const lesson = await this.prisma.lesson.findUnique({
      where: { id },
      include: {
        vocabularies: true,
        grammars: true,
        dialogues: { orderBy: { orderIndex: 'asc' } },
        quizzes: { include: { questions: { include: { options: true } } } },
      },
    });
    if (!lesson) throw new NotFoundException('Lesson not found');
    return lesson;
  }

  async update(id: string, dto: UpdateLessonDto) {
    await this.findOne(id);
    return this.prisma.lesson.update({ where: { id }, data: dto });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.lesson.delete({ where: { id } });
    return { message: 'Lesson deleted successfully' };
  }
}
