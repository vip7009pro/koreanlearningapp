import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const choices = await prisma.topikChoice.findMany({
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

  const sequenceChoices = choices.filter(c => {
    const trimmed = c.content.trim();
    if (trimmed === '1' || trimmed === '2' || trimmed === '3' || trimmed === '4') return true;
    if (trimmed === '(1)' || trimmed === '(2)' || trimmed === '(3)' || trimmed === '(4)') return true;
    if (trimmed === '①' || trimmed === '②' || trimmed === '③' || trimmed === '④') return true;
    if (trimmed === '➀' || trimmed === '➁' || trimmed === '➂' || trimmed === '➃') return true;
    return false;
  });

  console.log(`Total sequence-holding choices: ${sequenceChoices.length}`);
  const grouped: Record<string, string[]> = {};
  for (const c of sequenceChoices) {
    const examTitle = c.question.section.exam.title;
    const qIndex = `Q${c.question.orderIndex} (Section ${c.question.section.orderIndex} - ${c.question.section.type})`;
    if (!grouped[examTitle]) grouped[examTitle] = [];
    if (!grouped[examTitle].includes(qIndex)) grouped[examTitle].push(qIndex);
  }

  for (const [exam, qs] of Object.entries(grouped)) {
    console.log(`- ${exam}:`);
    for (const q of qs) {
      console.log(`  * ${q}`);
    }
  }
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
