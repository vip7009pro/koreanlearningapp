import { PrismaService } from '../src/prisma/prisma.service';
import { AIService } from '../src/modules/ai/ai.service';
import * as fs from 'fs';

async function main() {
  const prisma = new PrismaService();
  const aiService = new AIService(prisma);
  
  console.log("Calling generateTtsAudio with local provider...");
  const buffer = await aiService.generateTtsAudio("남: 안녕하세요. 여: 반갑습니다.", "local");
  console.log("Generated audio buffer of length:", buffer.length);
  
  fs.writeFileSync('test_local_nest.wav', buffer);
  console.log("Saved test_local_nest.wav");
}

main()
  .catch(console.error);
