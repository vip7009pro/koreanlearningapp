-- CreateEnum
CREATE TYPE "TopikLevel" AS ENUM ('TOPIK_I', 'TOPIK_II');

-- CreateEnum
CREATE TYPE "TopikExamStatus" AS ENUM ('DRAFT', 'PUBLISHED', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "TopikSectionType" AS ENUM ('LISTENING', 'READING', 'WRITING');

-- CreateEnum
CREATE TYPE "TopikQuestionType" AS ENUM ('MCQ', 'SHORT_TEXT', 'ESSAY');

-- CreateEnum
CREATE TYPE "TopikSessionStatus" AS ENUM ('IN_PROGRESS', 'SUBMITTED', 'EXPIRED');

-- CreateTable
CREATE TABLE "TopikExam" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "year" INTEGER NOT NULL,
    "topikLevel" "TopikLevel" NOT NULL,
    "level" TEXT,
    "durationMinutes" INTEGER NOT NULL,
    "totalQuestions" INTEGER NOT NULL,
    "status" "TopikExamStatus" NOT NULL DEFAULT 'DRAFT',
    "createdBy" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TopikExam_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TopikExamSection" (
    "id" TEXT NOT NULL,
    "examId" TEXT NOT NULL,
    "type" "TopikSectionType" NOT NULL,
    "orderIndex" INTEGER NOT NULL,
    "durationMinutes" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TopikExamSection_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TopikQuestion" (
    "id" TEXT NOT NULL,
    "examSectionId" TEXT NOT NULL,
    "questionType" "TopikQuestionType" NOT NULL,
    "orderIndex" INTEGER NOT NULL,
    "contentHtml" TEXT NOT NULL,
    "audioUrl" TEXT,
    "scoreWeight" INTEGER NOT NULL DEFAULT 1,
    "explanation" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TopikQuestion_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TopikChoice" (
    "id" TEXT NOT NULL,
    "questionId" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "isCorrect" BOOLEAN NOT NULL DEFAULT false,
    "orderIndex" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "TopikChoice_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TopikSession" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "examId" TEXT NOT NULL,
    "status" "TopikSessionStatus" NOT NULL DEFAULT 'IN_PROGRESS',
    "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "submittedAt" TIMESTAMP(3),
    "expiresAt" TIMESTAMP(3),
    "remainingSeconds" INTEGER NOT NULL,
    "currentQuestionIndex" INTEGER NOT NULL DEFAULT 0,
    "totalScore" INTEGER,
    "bestScoreSnapshot" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TopikSession_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TopikAnswer" (
    "id" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "questionId" TEXT NOT NULL,
    "selectedChoiceId" TEXT,
    "textAnswer" TEXT,
    "isCorrect" BOOLEAN,
    "score" INTEGER,
    "flagged" BOOLEAN NOT NULL DEFAULT false,
    "aiScore" INTEGER,
    "aiFeedback" JSONB,
    "aiReviewedAt" TIMESTAMP(3),
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "TopikAnswer_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "TopikExam_topikLevel_idx" ON "TopikExam"("topikLevel");

-- CreateIndex
CREATE INDEX "TopikExam_year_idx" ON "TopikExam"("year");

-- CreateIndex
CREATE INDEX "TopikExam_status_idx" ON "TopikExam"("status");

-- CreateIndex
CREATE INDEX "TopikExamSection_examId_idx" ON "TopikExamSection"("examId");

-- CreateIndex
CREATE UNIQUE INDEX "TopikExamSection_examId_orderIndex_key" ON "TopikExamSection"("examId", "orderIndex");

-- CreateIndex
CREATE INDEX "TopikQuestion_examSectionId_idx" ON "TopikQuestion"("examSectionId");

-- CreateIndex
CREATE UNIQUE INDEX "TopikQuestion_examSectionId_orderIndex_key" ON "TopikQuestion"("examSectionId", "orderIndex");

-- CreateIndex
CREATE INDEX "TopikChoice_questionId_idx" ON "TopikChoice"("questionId");

-- CreateIndex
CREATE UNIQUE INDEX "TopikChoice_questionId_orderIndex_key" ON "TopikChoice"("questionId", "orderIndex");

-- CreateIndex
CREATE INDEX "TopikSession_userId_idx" ON "TopikSession"("userId");

-- CreateIndex
CREATE INDEX "TopikSession_examId_idx" ON "TopikSession"("examId");

-- CreateIndex
CREATE INDEX "TopikSession_status_idx" ON "TopikSession"("status");

-- CreateIndex
CREATE INDEX "TopikAnswer_sessionId_idx" ON "TopikAnswer"("sessionId");

-- CreateIndex
CREATE INDEX "TopikAnswer_questionId_idx" ON "TopikAnswer"("questionId");

-- CreateIndex
CREATE UNIQUE INDEX "TopikAnswer_sessionId_questionId_key" ON "TopikAnswer"("sessionId", "questionId");

-- AddForeignKey
ALTER TABLE "TopikExamSection" ADD CONSTRAINT "TopikExamSection_examId_fkey" FOREIGN KEY ("examId") REFERENCES "TopikExam"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TopikQuestion" ADD CONSTRAINT "TopikQuestion_examSectionId_fkey" FOREIGN KEY ("examSectionId") REFERENCES "TopikExamSection"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TopikChoice" ADD CONSTRAINT "TopikChoice_questionId_fkey" FOREIGN KEY ("questionId") REFERENCES "TopikQuestion"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TopikSession" ADD CONSTRAINT "TopikSession_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TopikSession" ADD CONSTRAINT "TopikSession_examId_fkey" FOREIGN KEY ("examId") REFERENCES "TopikExam"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TopikAnswer" ADD CONSTRAINT "TopikAnswer_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "TopikSession"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TopikAnswer" ADD CONSTRAINT "TopikAnswer_questionId_fkey" FOREIGN KEY ("questionId") REFERENCES "TopikQuestion"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TopikAnswer" ADD CONSTRAINT "TopikAnswer_selectedChoiceId_fkey" FOREIGN KEY ("selectedChoiceId") REFERENCES "TopikChoice"("id") ON DELETE SET NULL ON UPDATE CASCADE;
