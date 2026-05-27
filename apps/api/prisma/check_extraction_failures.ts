import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

function extractSentenceFromHtml(html: string, orderIndex: number): string | null {
  if (!html) return null;
  const text = html.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();

  const getMarkers = (idx: number) => {
    const circled1 = String.fromCharCode(9311 + idx); // ①, ②
    const circled2 = String.fromCharCode(10111 + idx); // ➀, ➁
    return [
      `(${idx})`,
      `[${idx}]`,
      `${idx}.`,
      circled1,
      circled2,
      `( ${circled1} )`,
      `( ${circled2} )`,
      `(${circled1})`,
      `(${circled2})`,
      idx === 1 ? '(ㄱ)' : idx === 2 ? '(ㄴ)' : idx === 3 ? '(ㄷ)' : idx === 4 ? '(ㄹ)' : '',
      idx === 1 ? 'ㄱ' : idx === 2 ? 'ㄴ' : idx === 3 ? 'ㄷ' : idx === 4 ? 'ㄹ' : '',
    ].filter(Boolean);
  };

  const markersCurrent = getMarkers(orderIndex);
  const markersNext = getMarkers(orderIndex + 1);

  let startIdx = -1;
  for (const marker of markersCurrent) {
    const pos = text.indexOf(marker);
    if (pos !== -1) {
      startIdx = pos + marker.length;
      break;
    }
  }

  if (startIdx === -1) return null;

  let endIdx = text.length;
  for (const marker of markersNext) {
    const pos = text.indexOf(marker, startIdx);
    if (pos !== -1) {
      endIdx = pos;
      break;
    }
  }

  let sentence = text.slice(startIdx, endIdx).trim();
  sentence = sentence.replace(/^\s*\)\s*/, '').replace(/\s*\(\s*$/, '');
  sentence = sentence.replace(/^\s*\]\s*/, '').replace(/\s*\[\s*$/, '');
  sentence = sentence.replace(/^[:.-\s]+/, '').replace(/[:.-\s]+$/, '').trim();

  return sentence || null;
}

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

  console.log(`Checking ${exams.length} exams for extraction failures...`);
  let failures = 0;

  for (const exam of exams) {
    const mcqs = exam.sections.flatMap(s => s.questions);
    for (const q of mcqs) {
      for (const c of q.choices) {
        const isNumericOrCircled = ['1', '2', '3', '4', '①', '②', '③', '④', '➀', '➁', '➂', '➃'].includes(c.content.trim());
        if (isNumericOrCircled) {
          const extracted = extractSentenceFromHtml(q.contentHtml, c.orderIndex);
          if (!extracted) {
            failures++;
            console.log(`\nFailure in Exam: "${exam.title}" (ID: ${exam.id})`);
            console.log(`Question Order Index: ${q.orderIndex}`);
            console.log(`Content HTML: "${q.contentHtml}"`);
            console.log(`Choice content in DB: "${c.content}" (orderIndex: ${c.orderIndex})`);
          }
        }
      }
    }
  }

  console.log(`\nTotal extraction failures found: ${failures}`);
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
