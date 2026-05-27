import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const exam = await prisma.topikExam.findFirst({
    where: { title: { contains: 'Đề 4' } },
    include: {
      sections: {
        include: {
          questions: {
            orderBy: { orderIndex: 'asc' },
            include: {
              choices: { orderBy: { orderIndex: 'asc' } }
            }
          }
        }
      }
    }
  });

  if (!exam) {
    console.log('Exam not found');
    return;
  }

  console.log(`Exam: "${exam.title}"`);
  for (const s of exam.sections) {
    console.log(`Section: ${s.type}`);
    for (const q of s.questions.slice(0, 10)) {
      if (q.questionType === 'MCQ') {
        console.log(`  Q${q.orderIndex} Choices:`);
        for (const c of q.choices) {
          console.log(`    - Choice ${c.orderIndex}: content="${c.content}"`);
        }
      }
    }
  }
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
