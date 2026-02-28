-- AlterTable
ALTER TABLE "TopikSession" ADD COLUMN "sectionTypes" "TopikSectionType"[] DEFAULT ARRAY[]::"TopikSectionType"[];
