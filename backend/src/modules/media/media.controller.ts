import {
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  Post,
  Query,
  Res,
} from '@nestjs/common';
import type { Response } from 'express';
import { MediaService } from './media.service';
import { MediaLibraryService } from './media-library.service';

@Controller('media')
export class MediaController {
  constructor(
    private readonly media: MediaService,
    private readonly library: MediaLibraryService,
  ) {}

  /** List the library. `?search=` free-text filters title/artist/album/genre. */
  @Get('tracks')
  list(@Query('search') search?: string) {
    return this.media.list(search);
  }

  /** Rescan MEDIA_DIR (incremental). */
  @Post('library/scan')
  scan() {
    return this.library.scan();
  }

  /**
   * Stream a track's file. `res.sendFile` handles Range requests, which is
   * what makes seeking work in the player.
   */
  @Get('stream/:id')
  async stream(@Param('id') id: string, @Res() res: Response) {
    let file: string;
    try {
      file = await this.media.getFilePath(id);
    } catch {
      throw new NotFoundException('Track not found');
    }
    // Absolute path — no `root` needed (root is for relative paths and would
    // make sendFile reject an absolute path).
    res.sendFile(file, { acceptRanges: true });
  }

  /** Record a play (playCount++, History kind "media"). */
  @Post('tracks/:id/play')
  play(@Param('id') id: string) {
    return this.media.recordPlay(id);
  }

  /** Remove a track from the index (file stays on disk). */
  @Delete('tracks/:id')
  remove(@Param('id') id: string) {
    return this.media.remove(id);
  }
}
