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
  const questions = await prisma.topikQuestion.findMany({
    where: {
      questionType: 'MCQ',
      choices: {
        some: {
          content: { in: ['1', '2', '3', '4', '①', '②', '③', '④', '(1)', '(2)', '(3)', '(4)'] }
        }
      }
    },
    include: {
      choices: { orderBy: { orderIndex: 'asc' } },
      section: { include: { exam: true } }
    }
  });

  console.log(`Found ${questions.length} questions to check:`);
  for (const q of questions) {
    console.log(`\n===========================================`);
    console.log(`Exam: ${q.section.exam.title} | Q${q.orderIndex}`);
    console.log(`Content HTML: "${q.contentHtml}"`);
    console.log(`Choices:`);
    for (const c of q.choices) {
      const isNumericOrCircled = /^\s*(?:[1-4①-④➀-➃]|[1-4]\.|\[[1-4]\]|\([1-4]\)|\(\s*[①-④➀-➃]\s*\)|[ㄱ-ㄹ]|\([ㄱ-ㄹ]\))\s*$/.test(String(c.content).trim());
      const extracted = extractSentenceFromHtml(q.contentHtml, c.orderIndex);
      console.log(`  - Choice ${c.orderIndex}: content="${c.content}" | isNumericOrCircled=${isNumericOrCircled} | extracted="${extracted}"`);
    }
  }
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
