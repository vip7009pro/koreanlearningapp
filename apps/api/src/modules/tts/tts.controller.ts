import { Body, Controller, Post, Res, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiProduces, ApiTags } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { Response } from 'express';
import { KoreanTtsDto } from './tts.dto';
import { TtsService } from './tts.service';

@ApiTags('tts')
@Controller('tts')
@UseGuards(AuthGuard('jwt'))
@ApiBearerAuth()
export class TtsController {
  constructor(private ttsService: TtsService) {}

  @Post('korean')
  @ApiOperation({ summary: 'Synthesize natural Korean speech as MP3' })
  @ApiProduces('audio/mpeg')
  async synthesizeKoreanSpeech(@Body() dto: KoreanTtsDto, @Res({ passthrough: true }) res: Response) {
    res.setHeader('Content-Type', 'audio/mpeg');
    res.setHeader('Cache-Control', 'no-store');
    return this.ttsService.synthesizeKoreanSpeech(dto.text);
  }
}
