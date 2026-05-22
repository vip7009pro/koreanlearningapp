import { PrismaClient, TopikSessionStatus, TopikQuestionType, TopikSectionType } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const session = await prisma.topikSession.findFirst({
    orderBy: { updatedAt: 'desc' },
    include: {
      exam: true,
      answers: true,
    }
  });

  if (!session) {
    console.log('No sessions found!');
    return;
  }

  console.log('Testing submit for session:', session.id);

  try {
    const sessionId = session.id;
    const remainingSeconds = session.remainingSeconds;
    const scopeTypes = (session.sectionTypes || []) as TopikSectionType[];

    const questions = await prisma.topikQuestion.findMany({
      where: {
        section: {
          examId: session.examId,
          ...(scopeTypes.length ? { type: { in: scopeTypes } } : {}),
        },
      },
      include: { choices: true, section: true },
      orderBy: [{ examSectionId: 'asc' }, { orderIndex: 'asc' }],
    });

    console.log(`Found ${questions.length} questions for exam ${session.examId}`);

    const answers = await prisma.topikAnswer.findMany({
      where: { sessionId },
    });

    console.log(`Found ${answers.length} answers saved for this session`);

    const answerByQ = new Map<string, any>();
    for (const a of answers) answerByQ.set(a.questionId, a);

    let total = 0;
    const updates: any[] = [];

    for (const q of questions) {
      const a = answerByQ.get(q.id);
      if (!a) continue;

      if (q.questionType === TopikQuestionType.MCQ) {
        const correctChoice = q.choices.find((c) => c.isCorrect);
        const isCorrect = !!correctChoice && a.selectedChoiceId === correctChoice.id;
        const score = isCorrect ? q.scoreWeight : 0;
        total += score;
        updates.push(
          prisma.topikAnswer.update({
            where: { id: a.id },
            data: { isCorrect, score },
          }),
        );
      } else if (q.questionType === TopikQuestionType.SHORT_TEXT) {
        const expected = (q.correctTextAnswer || '').trim().toLowerCase();
        const got = String(a.textAnswer || '').trim().toLowerCase();
        const isCorrect = expected.length > 0 && got === expected;
        const score = isCorrect ? q.scoreWeight : 0;
        total += score;
        updates.push(
          prisma.topikAnswer.update({
            where: { id: a.id },
            data: { isCorrect, score },
          }),
        );
      }
    }

    console.log(`Prepared ${updates.length} updates`);

    if (updates.length) {
      console.log('Running transaction...');
      await prisma.$transaction(updates);
    }

    const submittedAt = new Date();
    console.log('Updating session status to SUBMITTED...');
    const updated = await prisma.topikSession.update({
      where: { id: sessionId },
      data: {
        status: TopikSessionStatus.SUBMITTED,
        submittedAt,
        remainingSeconds,
        totalScore: total,
      },
    });

    console.log('Submission simulated successfully!', updated);
  } catch (err: any) {
    console.error('Submission failed with error:', err);
  }
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
