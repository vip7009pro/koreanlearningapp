import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const lastExam = await prisma.topikExam.findFirst({
    orderBy: { createdAt: 'desc' },
    include: {
      sections: {
        include: {
          questions: {
            where: { questionType: 'MCQ' },
            include: {
              choices: { orderBy: { orderIndex: 'asc' } }
            }
          }
        }
      }
    }
  });

  if (!lastExam) {
    console.log('No exams found');
    return;
  }

  console.log(`Last Exam: "${lastExam.title}" (ID: ${lastExam.id}), Created At: ${lastExam.createdAt}`);
  const questions = lastExam.sections.flatMap(s => s.questions);
  console.log(`Total MCQ questions: ${questions.length}`);
  
  // Show a few questions and their choices
  for (const q of questions.slice(0, 5)) {
    console.log(`--------------------------------------------------`);
    console.log(`Q orderIndex: ${q.orderIndex}, contentHtml: "${q.contentHtml.slice(0, 80)}"`);
    console.log(`Choices:`);
    for (const c of q.choices) {
      console.log(`  - Choice ${c.orderIndex} (isCorrect: ${c.isCorrect}): "${c.content}"`);
    }
  }
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
