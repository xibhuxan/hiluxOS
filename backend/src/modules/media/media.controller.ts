import {
  Body,
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  Post,
  Query,
  Res,
} from "@nestjs/common";
import type { Response } from "express";
import { MediaArtService } from "./media-art.service";
import { MediaService } from "./media.service";
import { MediaLibraryService } from "./media-library.service";
import { MediaFoldersService } from "./media-folders.service";
import { CreateMediaFolderDto } from "./dto/create-media-folder.dto";

@Controller("media")
export class MediaController {
  constructor(
    private readonly media: MediaService,
    private readonly library: MediaLibraryService,
    private readonly art: MediaArtService,
    private readonly folders: MediaFoldersService,
  ) {}

  /** List the library. `?search=` free-text filters title/artist/album/genre. */
  @Get("tracks")
  list(@Query("search") search?: string) {
    return this.media.list(search);
  }

  /** List configured library folders (with the on-disk `exists` flag). */
  @Get("folders")
  listFolders() {
    return this.folders.list();
  }

  /**
   * One level of the filesystem for the client's folder picker: the
   * subdirectories of `?path=` (the filesystem root when omitted).
   */
  @Get("folders/browse")
  browse(@Query("path") dirPath?: string) {
    return this.folders.browse(dirPath);
  }

  /**
   * Add a library folder. The path must be absolute; it does not need to
   * exist on disk yet (missing folders are shown with a warning client-side
   * and skipped by the scanner until they reappear).
   */
  @Post("folders")
  addFolder(@Body() dto: CreateMediaFolderDto) {
    return this.folders.add(dto);
  }

  /**
   * Remove a folder. Its tracks are purged from the index (files on disk
   * are never touched).
   */
  @Delete("folders/:id")
  async removeFolder(@Param("id") id: string) {
    return this.folders.remove(id);
  }

  /** Rescan the configured folders (incremental). */
  @Post("library/scan")
  scan() {
    return this.library.scan();
  }

  /**
   * Stream a track's file. `res.sendFile` handles Range requests, which is
   * what makes seeking work in the player.
   */
  @Get("stream/:id")
  async stream(@Param("id") id: string, @Res() res: Response) {
    let file: string;
    try {
      file = await this.media.getFilePath(id);
    } catch {
      throw new NotFoundException("Track not found");
    }
    // Absolute path — no `root` needed (root is for relative paths and would
    // make sendFile reject an absolute path).
    res.sendFile(file, { acceptRanges: true });
  }

  /** Record a play (playCount++, History kind "media"). */
  @Post("tracks/:id/play")
  play(@Param("id") id: string) {
    return this.media.recordPlay(id);
  }

  /**
   * Album art for a track: folder cover.jpg or ffmpeg-extracted embedded
   * art (cached under MEDIA_DIR/.hiluxos-art). 404 when there is none —
   * the client then keeps its music-note placeholder. Raw @Res (like the
   * stream endpoint) → headers must be set manually.
   */
  @Get("tracks/:id/art")
  async trackArt(@Param("id") id: string, @Res() res: Response) {
    let file: string | null;
    try {
      file = await this.art.getArtPath(id);
    } catch {
      throw new NotFoundException("Track not found");
    }
    if (file == null) throw new NotFoundException("No art");
    // The art is stable per track id — let the browser cache it for a week.
    // dotfiles: 'allow' because the extraction cache (.hiluxos-art) is a
    // hidden folder — send's default 'ignore' would 404 on it.
    res.set("Cache-Control", "public, max-age=604800");
    res.sendFile(file, { dotfiles: "allow" });
  }

  /** Remove a track from the index (file stays on disk). */
  @Delete("tracks/:id")
  remove(@Param("id") id: string) {
    return this.media.remove(id);
  }
}
