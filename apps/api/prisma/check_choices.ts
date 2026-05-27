import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const questions = await prisma.topikQuestion.findMany({
    where: {
      questionType: 'MCQ',
      choices: {
        some: {
          content: { in: ['1', '2', '3', '4'] }
        }
      }
    },
    take: 5,
    include: {
      choices: { orderBy: { orderIndex: 'asc' } },
      section: { include: { exam: true } }
    }
  });

  console.log(`Found ${questions.length} questions with numeric choices.`);
  for (const q of questions) {
    console.log(`\n===========================================`);
    console.log(`Exam: ${q.section.exam.title}, Q${q.orderIndex}`);
    console.log(`Content HTML: "${q.contentHtml}"`);
    console.log(`Choices:`);
    for (const c of q.choices) {
      console.log(`  - Choice ${c.orderIndex}: content="${c.content}"`);
    }
  }
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
