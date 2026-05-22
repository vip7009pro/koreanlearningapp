import { PrismaClient } from '@prisma/client';

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

  console.log('Last Session Details:');
  console.log('ID:', session.id);
  console.log('User ID:', session.userId);
  console.log('Exam ID:', session.examId);
  console.log('Status:', session.status);
  console.log('ExpiresAt:', session.expiresAt);
  console.log('RemainingSeconds:', session.remainingSeconds);
  console.log('Now:', new Date());
  
  if (session.expiresAt) {
    const diff = Date.now() - session.expiresAt.getTime();
    if (diff > 0) {
      console.log('EXPIRED! Time difference:', diff, 'ms ago (' + (diff / 1000) + ' seconds)');
    } else {
      console.log('NOT EXPIRED yet. Time remaining:', -diff, 'ms (' + (-diff / 1000) + ' seconds)');
    }
  }

  console.log('Total answers recorded for this session:', session.answers.length);
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
