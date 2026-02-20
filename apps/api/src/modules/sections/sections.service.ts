import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateSectionDto, UpdateSectionDto } from './dto/section.dto';

@Injectable()
export class SectionsService {
  constructor(private prisma: PrismaService) {}

  async create(dto: CreateSectionDto) {
    return this.prisma.section.create({
      data: dto,
      include: { lessons: true },
    });
  }

  async findByCourse(courseId: string) {
    return this.prisma.section.findMany({
      where: { courseId },
      orderBy: { orderIndex: 'asc' },
      include: { lessons: { orderBy: { orderIndex: 'asc' } } },
    });
  }

  async findOne(id: string) {
    const section = await this.prisma.section.findUnique({
      where: { id },
      include: { lessons: { orderBy: { orderIndex: 'asc' } } },
    });
    if (!section) throw new NotFoundException('Section not found');
    return section;
  }

  async update(id: string, dto: UpdateSectionDto) {
    await this.findOne(id);
    return this.prisma.section.update({
      where: { id },
      data: dto,
      include: { lessons: true },
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.section.delete({ where: { id } });
    return { message: 'Section deleted successfully' };
  }
}
