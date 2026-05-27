import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const emptyChoices = await prisma.topikChoice.findMany({
    where: {
      content: ''
    },
    include: {
      question: {
        include: {
          section: {
            include: {
              exam: true
            }
          }
        }
      }
    }
  });

  console.log(`Total choices with empty content: ${emptyChoices.length}`);
  if (emptyChoices.length > 0) {
    const examMap: Record<string, number> = {};
    for (const c of emptyChoices) {
      const title = c.question?.section?.exam?.title || 'Unknown';
      examMap[title] = (examMap[title] || 0) + 1;
    }
    console.log('Affected Exams:', examMap);
  }
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
