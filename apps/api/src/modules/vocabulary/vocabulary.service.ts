import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateVocabularyDto, UpdateVocabularyDto } from './dto/vocabulary.dto';

@Injectable()
export class VocabularyService {
  constructor(private prisma: PrismaService) {}

  async create(dto: CreateVocabularyDto) {
    return this.prisma.vocabulary.create({ data: dto });
  }

  async createMany(items: CreateVocabularyDto[]) {
    return this.prisma.vocabulary.createMany({ data: items });
  }

  async findByLesson(lessonId: string, page = 1, limit = 50) {
    const skip = (page - 1) * limit;
    const [data, total] = await Promise.all([
      this.prisma.vocabulary.findMany({
        where: { lessonId },
        skip,
        take: limit,
        orderBy: { createdAt: 'asc' },
      }),
      this.prisma.vocabulary.count({ where: { lessonId } }),
    ]);
    return { data, total, page, limit, totalPages: Math.ceil(total / limit) };
  }

  async findOne(id: string) {
    const vocab = await this.prisma.vocabulary.findUnique({ where: { id } });
    if (!vocab) throw new NotFoundException('Vocabulary not found');
    return vocab;
  }

  async update(id: string, dto: UpdateVocabularyDto) {
    await this.findOne(id);
    return this.prisma.vocabulary.update({ where: { id }, data: dto });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.vocabulary.delete({ where: { id } });
    return { message: 'Vocabulary deleted successfully' };
  }
}
