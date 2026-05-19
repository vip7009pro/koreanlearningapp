import { Injectable, NotFoundException, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateVocabularyDto, UpdateVocabularyDto } from './dto/vocabulary.dto';

@Injectable()
export class VocabularyService implements OnModuleInit {
  constructor(private prisma: PrismaService) {}

  async onModuleInit() {
    try {
      const count = await this.prisma.specializedCategory.count();
      if (count === 0) {
        await this.prisma.specializedCategory.createMany({
          data: [
            { name: 'IT', displayName: 'Công nghệ thông tin (IT)' },
            { name: 'BUSINESS', displayName: 'Văn phòng / Kinh doanh' },
            { name: 'EPS', displayName: 'Sản xuất chế tạo (EPS)' },
            { name: 'CONSTRUCTION', displayName: 'Xây dựng' },
          ],
        });
      }
    } catch (e) {
      // Prevent crash if db is not ready/migrated yet
      console.error('Failed to seed categories in VocabularyService:', e);
    }
  }

  async create(dto: CreateVocabularyDto) {
    return this.prisma.vocabulary.create({ data: dto });
  }

  async createMany(items: CreateVocabularyDto[]) {
    return this.prisma.vocabulary.createMany({ data: items });
  }

  async findByLesson(lessonId: string, page = 1, limit = 1000) {
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

  async findByCategory(category: string, page = 1, limit = 1000) {
    const skip = (page - 1) * limit;
    const [data, total] = await Promise.all([
      this.prisma.vocabulary.findMany({
        where: { category },
        skip,
        take: limit,
        orderBy: { createdAt: 'asc' },
      }),
      this.prisma.vocabulary.count({ where: { category } }),
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

  async removeMany(ids: string[]) {
    const safeIds = Array.from(new Set((ids || []).filter((x) => typeof x === 'string' && x.trim())));
    if (safeIds.length === 0) return { deleted: 0 };

    const res = await this.prisma.vocabulary.deleteMany({ where: { id: { in: safeIds } } });
    return { deleted: res.count };
  }

  // Categories CRUD
  async findAllCategories() {
    return this.prisma.specializedCategory.findMany({
      orderBy: { name: 'asc' },
    });
  }

  async createCategory(dto: { name: string; displayName: string }) {
    const normalizedName = String(dto.name || '').trim().toUpperCase();
    if (!normalizedName) throw new Error('Category name is required');
    return this.prisma.specializedCategory.upsert({
      where: { name: normalizedName },
      update: { displayName: dto.displayName },
      create: { name: normalizedName, displayName: dto.displayName },
    });
  }

  async deleteCategory(id: string) {
    const cat = await this.prisma.specializedCategory.findUnique({
      where: { id },
    });
    if (!cat) throw new NotFoundException('Category not found');

    // Run in a transaction: delete all vocabulary items mapped to this category, then delete the category itself
    await this.prisma.$transaction([
      this.prisma.vocabulary.deleteMany({ where: { category: cat.name } }),
      this.prisma.specializedCategory.delete({ where: { id } }),
    ]);

    return { message: 'Category and all associated vocabularies deleted successfully' };
  }
}
