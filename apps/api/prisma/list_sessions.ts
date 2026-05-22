import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const sessions = await prisma.topikSession.findMany({
    orderBy: { updatedAt: 'desc' },
    take: 10,
    include: {
      user: {
        select: {
          id: true,
          email: true,
          displayName: true,
        }
      },
      exam: {
        select: {
          id: true,
          title: true,
        }
      }
    }
  });

  console.log('Last 10 TOPIK sessions:');
  for (const s of sessions) {
    console.log(`- ID: ${s.id}`);
    console.log(`  User: ${s.user.displayName} (${s.user.email})`);
    console.log(`  Exam: ${s.exam.title}`);
    console.log(`  Status: ${s.status}`);
    console.log(`  ExpiresAt: ${s.expiresAt}`);
    console.log(`  Updated: ${s.updatedAt}`);
    console.log('------------------------------------');
  }
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
