import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const exams = await prisma.topikExam.findMany({
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

  console.log(`Total exams found: ${exams.length}`);
  for (const exam of exams) {
    const mcqs = exam.sections.flatMap(s => s.questions);
    let numericCount = 0;
    let totalChoices = 0;
    for (const q of mcqs) {
      totalChoices += q.choices.length;
      for (const c of q.choices) {
        if (['1', '2', '3', '4', '①', '②', '③', '④'].includes(c.content.trim())) {
          numericCount++;
        }
      }
    }
    console.log(`Exam "${exam.title}" (ID: ${exam.id}) - Total MCQ: ${mcqs.length}, Total Choices: ${totalChoices}, Numeric Choices: ${numericCount}`);
  }
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
