import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const exams = await prisma.topikExam.findMany({
    include: {
      sections: {
        include: {
          questions: {
            include: {
              choices: true
            }
          }
        }
      }
    }
  });

  console.log('Exam Choices Overview:');
  for (const exam of exams) {
    let totalMCQ = 0;
    let sequenceChoicesCount = 0;
    let sentenceChoicesCount = 0;

    for (const section of exam.sections) {
      for (const q of section.questions) {
        if (q.questionType === 'MCQ') {
          totalMCQ++;
          for (const c of q.choices) {
            const isSeq = /^\s*(?:[1-4①-④➀-➃]|[1-4]\.|\[[1-4]\]|\([1-4]\)|\(\s*[①-④➀-➃]\s*\)|[ㄱ-ㄹ]|\([ㄱ-ㄹ]\))\s*$/.test(String(c.content).trim());
            if (isSeq) {
              sequenceChoicesCount++;
            } else {
              sentenceChoicesCount++;
            }
          }
        }
      }
    }

    console.log(`Exam: "${exam.title}" (ID: ${exam.id})`);
    console.log(`  - Total MCQ questions: ${totalMCQ}`);
    console.log(`  - Choices that are sequence numbers: ${sequenceChoicesCount}`);
    console.log(`  - Choices that are full sentences: ${sentenceChoicesCount}`);
  }
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
