import { Injectable } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';

@Injectable()
export class UploadService {
  private readonly uploadDir = process.env.UPLOAD_DIR || './uploads';

  constructor() {
    if (!fs.existsSync(this.uploadDir)) {
      fs.mkdirSync(this.uploadDir, { recursive: true });
    }
    const audioDir = path.join(this.uploadDir, 'audio');
    const imageDir = path.join(this.uploadDir, 'images');
    if (!fs.existsSync(audioDir)) fs.mkdirSync(audioDir, { recursive: true });
    if (!fs.existsSync(imageDir)) fs.mkdirSync(imageDir, { recursive: true });
  }

  getFileUrl(filename: string): string {
    return `/api/upload/files/${filename}`;
  }

  async deleteFile(filename: string): Promise<boolean> {
    const filePath = path.join(this.uploadDir, filename);
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
      return true;
    }
    return false;
  }

  getUploadDir(): string {
    return this.uploadDir;
  }
}
