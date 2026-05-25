import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const choices = await prisma.topikChoice.findMany({
    where: {
      content: {
        contains: '선택'
      }
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

  console.log(`Total choices containing '선택': ${choices.length}`);
  if (choices.length > 0) {
    const examMap: Record<string, number> = {};
    for (const c of choices) {
      const title = c.question?.section?.exam?.title || 'Unknown';
      examMap[title] = (examMap[title] || 0) + 1;
    }
    console.log('Affected Exams:', examMap);
    console.log('Sample choices:');
    for (const c of choices.slice(0, 5)) {
      console.log(`Exam: ${c.question?.section?.exam?.title}, Q${c.question?.orderIndex}, Content: "${c.content}"`);
    }
  }
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
