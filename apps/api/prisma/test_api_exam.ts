import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const latestExam = await prisma.topikExam.findFirst({
    orderBy: { createdAt: 'desc' }
  });

  if (!latestExam) {
    console.log('No exams found.');
    return;
  }

  const exam = await prisma.topikExam.findUnique({
    where: { id: latestExam.id },
    include: {
      sections: {
        orderBy: { orderIndex: 'asc' },
        include: {
          questions: {
            orderBy: { orderIndex: 'asc' },
            include: { choices: { orderBy: { orderIndex: 'asc' } } },
          },
        },
      },
    },
  });

  const firstMCQ = exam?.sections
    .flatMap(s => s.questions)
    .find(q => q.questionType === 'MCQ');

  console.log('Raw database record for first MCQ question:');
  console.log(JSON.stringify(firstMCQ, null, 2));
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
