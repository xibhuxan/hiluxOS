import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { PrismaService } from "../../prisma/prisma.service";

/** How a MediaFolder row is exposed over the API. */
export interface MediaFolderDto {
  id: string;
  /** Absolute path, as configured (normalized). */
  path: string;
  /** Display name: the folder's basename. */
  label: string;
  /** Whether the path currently exists on disk (missing → client marker). */
  exists: boolean;
}

/** How a browse entry (a subdirectory) is exposed over the API. */
export interface FolderEntryDto {
  name: string;
  path: string;
}

/** One level of the filesystem for the client's folder picker. */
export interface FolderBrowseDto {
  /** The directory being listed (absolute, resolved). */
  path: string;
  /** Parent directory, or null at the filesystem root. */
  parent: string | null;
  /** The user's home directory (quick-access chip client-side). */
  home: string;
  /** False when the directory exists but cannot be listed (EACCES). */
  readable: boolean;
  /** Subdirectories, sorted case-insensitively. */
  dirs: FolderEntryDto[];
}

/**
 * Manages the user-configured library folders (the media rail's roots).
 *
 * - The table is seeded with the legacy MEDIA_DIR on first use, so existing
 *   single-folder installs keep working untouched.
 * - A folder does NOT need to exist on disk: missing folders are kept (the
 *   client shows a warning marker) and the scanner skips them until they
 *   reappear — a USB stick being unplugged, say.
 * - Removing a folder purges its tracks from the index (the files on disk
 *   are never touched).
 */
@Injectable()
export class MediaFoldersService {
  private readonly logger = new Logger(MediaFoldersService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  private get mediaDir(): string {
    return this.config.get<string>("MEDIA_DIR") ?? "";
  }

  /** List configured folders (oldest first — stable rail order). */
  async list(): Promise<MediaFolderDto[]> {
    await this.ensureSeeded();
    const rows = await this.prisma.mediaFolder.findMany({
      orderBy: { createdAt: "asc" },
    });
    return rows.map((r) => this.mapFolder(r));
  }

  /**
   * The paths the library scanner should walk. Falls back to the legacy
   * single MEDIA_DIR when no folder is configured; throws when neither
   * exists (same error the scanner used to raise).
   */
  async scanRoots(): Promise<string[]> {
    await this.ensureSeeded();
    const rows = await this.prisma.mediaFolder.findMany();
    if (rows.length > 0) return rows.map((r) => r.path);
    const dir = this.mediaDir;
    if (dir) return [dir];
    throw new Error("MEDIA_DIR is not configured");
  }

  /**
   * The legacy single-folder root (MEDIA_DIR), empty when unset. Used by
   * MediaService as the relPath fallback when no folder is configured.
   */
  legacyRoots(): string[] {
    const dir = this.mediaDir;
    return dir ? [dir] : [];
  }

  /** Insert MEDIA_DIR as the initial folder when the table is empty. */
  private async ensureSeeded() {
    const dir = this.mediaDir;
    if (!dir) return;
    const count = await this.prisma.mediaFolder.count();
    if (count === 0) {
      await this.prisma.mediaFolder
        .create({ data: { path: dir } })
        .catch(() => undefined);
    }
  }

  /**
   * Add a folder. The path must be absolute (and not the filesystem root);
   * it does not need to exist on disk yet.
   */
  async add(input: { path: string }): Promise<MediaFolderDto> {
    const raw = (input.path ?? "").trim();
    if (!raw) throw new BadRequestException("Path is required");
    if (!path.isAbsolute(raw)) {
      throw new BadRequestException("Path must be absolute");
    }
    const resolved = path.resolve(raw);
    if (resolved === path.parse(resolved).root) {
      throw new BadRequestException("Refusing to index the filesystem root");
    }
    const existing = await this.prisma.mediaFolder.findUnique({
      where: { path: resolved },
    });
    if (existing) throw new ConflictException("Folder already configured");
    const row = await this.prisma.mediaFolder.create({
      data: { path: resolved },
    });
    this.logger.log(`Media folder added: ${resolved}`);
    return this.mapFolder(row);
  }

  /**
   * Browse one level of the filesystem for the folder picker: the
   * subdirectories of [dirPath] (the filesystem root when omitted).
   *
   * Only directories are returned (files are useless as library roots);
   * hidden dot-directories are skipped (picker noise). Symlinked dirs are
   * included when they resolve to a directory (broken links are skipped).
   * A directory that exists but cannot be listed (permissions) yields
   * `readable: false` instead of an error, so the picker can still go up.
   */
  async browse(dirPath?: string): Promise<FolderBrowseDto> {
    const root = path.parse(process.cwd()).root;
    const dir = dirPath && dirPath.trim() ? path.resolve(dirPath.trim()) : root;

    let stat: fs.Stats;
    try {
      stat = await fs.promises.stat(dir);
    } catch {
      throw new BadRequestException("Path not found");
    }
    if (!stat.isDirectory()) {
      throw new BadRequestException("Path is not a directory");
    }

    let entries: fs.Dirent[];
    try {
      entries = await fs.promises.readdir(dir, { withFileTypes: true });
    } catch {
      return {
        path: dir,
        parent: this.parentOf(dir),
        home: os.homedir(),
        readable: false,
        dirs: [],
      };
    }

    const dirs: FolderEntryDto[] = [];
    for (const e of entries) {
      if (e.name.startsWith(".")) continue;
      if (e.isDirectory()) {
        dirs.push({ name: e.name, path: path.join(dir, e.name) });
        continue;
      }
      if (e.isSymbolicLink()) {
        try {
          const target = await fs.promises.stat(path.join(dir, e.name));
          if (target.isDirectory()) {
            dirs.push({ name: e.name, path: path.join(dir, e.name) });
          }
        } catch {
          // Broken symlink — skip it.
        }
      }
    }
    dirs.sort((a, b) =>
      a.name.toLowerCase().localeCompare(b.name.toLowerCase()),
    );

    return {
      path: dir,
      parent: this.parentOf(dir),
      home: os.homedir(),
      readable: true,
      dirs,
    };
  }

  /** dirname(), null at the filesystem root (dirname('/') === '/'). */
  private parentOf(dir: string): string | null {
    const parent = path.dirname(dir);
    return parent === dir ? null : parent;
  }

  /**
   * Remove a folder and purge its tracks from the index — the same
   * semantics as a scan that no longer sees them.
   */
  async remove(id: string): Promise<{ removed: boolean; tracks: number }> {
    const folder = await this.prisma.mediaFolder.findUnique({ where: { id } });
    if (!folder) throw new NotFoundException("Folder not found");
    const tracks = await this.prisma.track.deleteMany({
      // path.sep suffix so '/music' does not match '/musicx/a.mp3'.
      where: { path: { startsWith: folder.path + path.sep } },
    });
    await this.prisma.mediaFolder.delete({ where: { id } });
    this.logger.log(
      `Media folder removed: ${folder.path} (${tracks.count} tracks purged)`,
    );
    return { removed: true, tracks: tracks.count };
  }

  /** DTO mapping: label = basename, exists = live fs check. */
  private mapFolder(r: { id: string; path: string }): MediaFolderDto {
    let exists = false;
    try {
      exists = fs.existsSync(r.path) && fs.statSync(r.path).isDirectory();
    } catch {
      exists = false;
    }
    return { id: r.id, path: r.path, label: path.basename(r.path), exists };
  }
}
