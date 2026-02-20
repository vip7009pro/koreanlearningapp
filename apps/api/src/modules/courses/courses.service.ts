import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateCourseDto, UpdateCourseDto } from './dto/course.dto';

@Injectable()
export class CoursesService {
  constructor(private prisma: PrismaService) {}

  async create(dto: CreateCourseDto) {
    return this.prisma.course.create({ data: dto });
  }

  async findAll(page = 1, limit = 20, level?: string, isPremium?: boolean) {
    const skip = (page - 1) * limit;
    const where: Record<string, unknown> = {};
    if (level) where.level = level;
    if (isPremium !== undefined) where.isPremium = isPremium;

    const [data, total] = await Promise.all([
      this.prisma.course.findMany({
        skip,
        take: limit,
        where,
        orderBy: { createdAt: 'desc' },
        include: {
          sections: {
            orderBy: { orderIndex: 'asc' },
            include: {
              lessons: { orderBy: { orderIndex: 'asc' } },
            },
          },
        },
      }),
      this.prisma.course.count({ where }),
    ]);

    return { data, total, page, limit, totalPages: Math.ceil(total / limit) };
  }

  async findOne(id: string) {
    const course = await this.prisma.course.findUnique({
      where: { id },
      include: {
        sections: {
          orderBy: { orderIndex: 'asc' },
          include: {
            lessons: { orderBy: { orderIndex: 'asc' } },
          },
        },
      },
    });
    if (!course) throw new NotFoundException('Course not found');
    return course;
  }

  async update(id: string, dto: UpdateCourseDto) {
    await this.findOne(id);
    return this.prisma.course.update({ where: { id }, data: dto });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.course.delete({ where: { id } });
    return { message: 'Course deleted successfully' };
  }

  async publish(id: string) {
    await this.findOne(id);
    return this.prisma.course.update({
      where: { id },
      data: { published: true },
    });
  }

  async unpublish(id: string) {
    await this.findOne(id);
    return this.prisma.course.update({
      where: { id },
      data: { published: false },
    });
  }
}
