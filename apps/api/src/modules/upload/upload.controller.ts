import { Controller, Post, Get, Delete, Param, UseGuards, UseInterceptors, UploadedFile, Res } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiConsumes, ApiBody } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { UserRole } from '@prisma/client';
import { diskStorage } from 'multer';
import { extname } from 'path';
import { Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { UploadService } from './upload.service';
import { Roles } from '../../common/decorators/roles.decorator';
import { RolesGuard } from '../../common/guards/roles.guard';
import * as fs from 'fs';
import * as path from 'path';

@ApiTags('upload')
@Controller('upload')
export class UploadController {
  constructor(private uploadService: UploadService) {}

  @Post('audio')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: './uploads/audio',
        filename: (_req, file, cb) => {
          const name = `${uuidv4()}${extname(file.originalname)}`;
          cb(null, name);
        },
      }),
      fileFilter: (_req, file, cb) => {
        if (file.mimetype.startsWith('audio/')) {
          cb(null, true);
        } else {
          cb(new Error('Only audio files are allowed'), false);
        }
      },
    }),
  )
  @ApiConsumes('multipart/form-data')
  @ApiBody({ schema: { type: 'object', properties: { file: { type: 'string', format: 'binary' } } } })
  @ApiOperation({ summary: 'Upload audio file (Admin only)' })
  uploadAudio(@UploadedFile() file: Express.Multer.File) {
    return {
      filename: file.filename,
      url: this.uploadService.getFileUrl(`audio/${file.filename}`),
      size: file.size,
      mimetype: file.mimetype,
    };
  }

  @Post('image')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: './uploads/images',
        filename: (_req, file, cb) => {
          const name = `${uuidv4()}${extname(file.originalname)}`;
          cb(null, name);
        },
      }),
      fileFilter: (_req, file, cb) => {
        if (file.mimetype.startsWith('image/')) {
          cb(null, true);
        } else {
          cb(new Error('Only image files are allowed'), false);
        }
      },
    }),
  )
  @ApiConsumes('multipart/form-data')
  @ApiBody({ schema: { type: 'object', properties: { file: { type: 'string', format: 'binary' } } } })
  @ApiOperation({ summary: 'Upload image file (Admin only)' })
  uploadImage(@UploadedFile() file: Express.Multer.File) {
    return {
      filename: file.filename,
      url: this.uploadService.getFileUrl(`images/${file.filename}`),
      size: file.size,
      mimetype: file.mimetype,
    };
  }

  @Post('avatar')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: './uploads/avatars',
        filename: (_req, file, cb) => {
          const name = `${uuidv4()}${extname(file.originalname)}`;
          cb(null, name);
        },
      }),
      fileFilter: (_req, file, cb) => {
        if (file.mimetype.startsWith('image/')) {
          cb(null, true);
        } else {
          cb(new Error('Only image files are allowed'), false);
        }
      },
    }),
  )
  @ApiConsumes('multipart/form-data')
  @ApiBody({ schema: { type: 'object', properties: { file: { type: 'string', format: 'binary' } } } })
  @ApiOperation({ summary: 'Upload avatar image (Authenticated user)' })
  uploadAvatar(@UploadedFile() file: Express.Multer.File) {
    return {
      filename: file.filename,
      url: this.uploadService.getFileUrl(`avatars/${file.filename}`),
      size: file.size,
      mimetype: file.mimetype,
    };
  }

  @Get('files/:folder/:filename')
  @ApiOperation({ summary: 'Get uploaded file' })
  getFile(@Param('folder') folder: string, @Param('filename') filename: string, @Res() res: Response) {
    const filePath = path.join(this.uploadService.getUploadDir(), folder, filename);
    if (fs.existsSync(filePath)) {
      return res.sendFile(path.resolve(filePath));
    }
    return res.status(404).json({ message: 'File not found' });
  }

  @Delete('files/:folder/:filename')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Delete uploaded file (Admin only)' })
  async deleteFile(@Param('folder') folder: string, @Param('filename') filename: string) {
    const deleted = await this.uploadService.deleteFile(`${folder}/${filename}`);
    return { deleted };
  }
}
