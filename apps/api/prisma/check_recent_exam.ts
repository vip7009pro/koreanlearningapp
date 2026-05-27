import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const recentExam = await prisma.topikExam.findFirst({
    orderBy: { updatedAt: 'desc' },
    include: {
      sections: {
        include: {
          questions: {
            include: {
              choices: { orderBy: { orderIndex: 'asc' } }
            }
          }
        }
      }
    }
  });

  if (!recentExam) {
    console.log('No exams found.');
    return;
  }

  console.log(`Most recently updated exam: "${recentExam.title}" (ID: ${recentExam.id}) - Updated At: ${recentExam.updatedAt}`);
  
  const mcqs = recentExam.sections.flatMap(s => s.questions).filter(q => q.questionType === 'MCQ');
  console.log(`Total MCQ questions: ${mcqs.length}`);
  
  for (const q of mcqs.slice(0, 5)) {
    console.log(`\nQuestion ${q.orderIndex} (ID: ${q.id}):`);
    console.log(`  Content HTML: "${q.contentHtml}"`);
    console.log(`  Choices in DB:`);
    for (const c of q.choices) {
      console.log(`    - Order ${c.orderIndex} (ID: ${c.id}): content="${c.content}" isCorrect=${c.isCorrect}`);
    }
  }
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
