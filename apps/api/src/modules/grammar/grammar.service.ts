import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateGrammarDto, UpdateGrammarDto } from './dto/grammar.dto';

@Injectable()
export class GrammarService {
  constructor(private prisma: PrismaService) {}

  async create(dto: CreateGrammarDto) {
    return this.prisma.grammar.create({ data: dto });
  }

  async findByLesson(lessonId: string) {
    return this.prisma.grammar.findMany({
      where: { lessonId },
      orderBy: { createdAt: 'asc' },
    });
  }

  async findOne(id: string) {
    const grammar = await this.prisma.grammar.findUnique({ where: { id } });
    if (!grammar) throw new NotFoundException('Grammar not found');
    return grammar;
  }

  async update(id: string, dto: UpdateGrammarDto) {
    await this.findOne(id);
    return this.prisma.grammar.update({ where: { id }, data: dto });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.grammar.delete({ where: { id } });
    return { message: 'Grammar deleted successfully' };
  }

  async removeMany(ids: string[]) {
    const safeIds = Array.from(new Set((ids || []).filter((x) => typeof x === 'string' && x.trim())));
    if (safeIds.length === 0) return { deleted: 0 };

    const res = await this.prisma.grammar.deleteMany({ where: { id: { in: safeIds } } });
    return { deleted: res.count };
  }
}
