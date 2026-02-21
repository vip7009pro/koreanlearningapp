import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateDialogueDto, UpdateDialogueDto } from './dto/dialogue.dto';

@Injectable()
export class DialoguesService {
  constructor(private prisma: PrismaService) {}

  async create(dto: CreateDialogueDto) { return this.prisma.dialogue.create({ data: dto }); }

  async findByLesson(lessonId: string) {
    return this.prisma.dialogue.findMany({ where: { lessonId }, orderBy: { orderIndex: 'asc' } });
  }

  async findOne(id: string) {
    const d = await this.prisma.dialogue.findUnique({ where: { id } });
    if (!d) throw new NotFoundException('Dialogue not found');
    return d;
  }

  async update(id: string, dto: UpdateDialogueDto) {
    await this.findOne(id);
    return this.prisma.dialogue.update({ where: { id }, data: dto });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.dialogue.delete({ where: { id } });
    return { message: 'Dialogue deleted successfully' };
  }

  async removeMany(ids: string[]) {
    const safeIds = Array.from(new Set((ids || []).filter((x) => typeof x === 'string' && x.trim())));
    if (safeIds.length === 0) return { deleted: 0 };

    const res = await this.prisma.dialogue.deleteMany({ where: { id: { in: safeIds } } });
    return { deleted: res.count };
  }
}
