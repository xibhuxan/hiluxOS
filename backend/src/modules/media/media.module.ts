import { Module } from '@nestjs/common';
import { MediaController } from './media.controller';
import { MediaArtService } from './media-art.service';
import { MediaService } from './media.service';
import { MediaLibraryService } from './media-library.service';
import { MediaFoldersService } from './media-folders.service';
import { CommandRunner } from '../system/command-runner';

@Module({
  // CommandRunner is provided here too so the module is self-contained (the
  // SystemModule also exports it, but Media must not depend on System).
  providers: [
    MediaService,
    MediaLibraryService,
    MediaArtService,
    MediaFoldersService,
    CommandRunner,
  ],
  controllers: [MediaController],
  exports: [MediaService, MediaFoldersService],
})
export class MediaModule {}
