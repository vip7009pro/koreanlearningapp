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

  for (const exam of exams) {
    console.log(`\n===========================================`);
    console.log(`Exam: "${exam.title}" (ID: ${exam.id})`);
    const mcqs = exam.sections.flatMap(s => s.questions);
    
    // Group questions by choice patterns
    let totalMCQ = mcqs.length;
    let numericChoicesCount = 0;
    let emptyChoicesCount = 0;
    let placeholderChoicesCount = 0; // like "Lựa chọn X", "Đáp án X", "선택 X"
    let realSentenceChoicesCount = 0;

    for (const q of mcqs) {
      const choices = q.choices;
      if (choices.length === 0) continue;
      
      const firstChoice = choices[0].content.trim();
      const isNumeric = ['1', '2', '3', '4', '①', '②', '③', '④'].includes(firstChoice);
      const isPlaceholder = firstChoice.includes('Đáp án') || firstChoice.includes('Lựa chọn') || firstChoice.includes('선택');
      const isEmpty = firstChoice === '';

      if (isNumeric) numericChoicesCount++;
      else if (isPlaceholder) placeholderChoicesCount++;
      else if (isEmpty) emptyChoicesCount++;
      else realSentenceChoicesCount++;
    }

    console.log(`  Total MCQ questions: ${totalMCQ}`);
    console.log(`  Questions with numeric choices: ${numericChoicesCount}`);
    console.log(`  Questions with placeholder choices ("Đáp án", "Lựa chọn", "선택"): ${placeholderChoicesCount}`);
    console.log(`  Questions with empty choices: ${emptyChoicesCount}`);
    console.log(`  Questions with real Korean sentence choices: ${realSentenceChoicesCount}`);
    
    if (placeholderChoicesCount > 0 || numericChoicesCount > 0) {
      console.log(`  Samples of non-real choices:`);
      const samples = mcqs.filter(q => {
        const first = q.choices[0]?.content.trim() || '';
        return ['1', '2', '3', '4', '①', '②', '③', '④'].includes(first) || 
               first.includes('Đáp án') || first.includes('Lựa chọn') || first.includes('선택');
      }).slice(0, 3);
      for (const q of samples) {
        console.log(`    Q${q.orderIndex} (ID: ${q.id}): contentHtml="${q.contentHtml.substring(0, 60)}..."`);
        console.log(`      Choices: ${q.choices.map(c => `[${c.orderIndex}]: "${c.content}"`).join(', ')}`);
      }
    }
  }
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
