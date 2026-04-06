import { BadRequestException, Injectable, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';

@Injectable()
export class TtsService {
  constructor(private configService: ConfigService) {}

  private get apiKey() {
    return this.configService.get<string>('GOOGLE_TTS_API_KEY')?.trim() || '';
  }

  private get voiceName() {
    return this.configService.get<string>('GOOGLE_TTS_VOICE_NAME')?.trim() || 'ko-KR-Neural2-A';
  }

  private get speakingRate() {
    const rate = Number.parseFloat(this.configService.get<string>('GOOGLE_TTS_SPEAKING_RATE') || '1');
    return Number.isFinite(rate) && rate > 0 ? rate : 1;
  }

  private get pitch() {
    const value = Number.parseFloat(this.configService.get<string>('GOOGLE_TTS_PITCH') || '0');
    return Number.isFinite(value) ? value : 0;
  }

  async synthesizeKoreanSpeech(text: string): Promise<Buffer> {
    const normalizedText = String(text || '').replace(/\s+/g, ' ').trim();

    if (!normalizedText) {
      throw new BadRequestException('Text is required');
    }

    if (normalizedText.length > 5000) {
      throw new BadRequestException('Text is too long for TTS');
    }

    if (!this.apiKey) {
      throw new ServiceUnavailableException('GOOGLE_TTS_API_KEY is not configured');
    }

    try {
      const response = await axios.post(
        `https://texttospeech.googleapis.com/v1/text:synthesize?key=${encodeURIComponent(this.apiKey)}`,
        {
          input: { text: normalizedText },
          voice: {
            languageCode: 'ko-KR',
            name: this.voiceName,
          },
          audioConfig: {
            audioEncoding: 'MP3',
            speakingRate: this.speakingRate,
            pitch: this.pitch,
          },
        },
        {
          timeout: 20000,
        },
      );

      const audioContent = response.data?.audioContent;
      if (!audioContent || typeof audioContent !== 'string') {
        throw new Error('Invalid audioContent');
      }

      return Buffer.from(audioContent, 'base64');
    } catch (error) {
      throw new ServiceUnavailableException('Unable to synthesize Korean speech');
    }
  }
}
