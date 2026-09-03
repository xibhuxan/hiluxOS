-- AlterTable
ALTER TABLE "history" ADD COLUMN     "trackId" TEXT;

-- CreateTable
CREATE TABLE "tracks" (
    "id" TEXT NOT NULL,
    "path" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "artist" TEXT,
    "album" TEXT,
    "genre" TEXT,
    "durationSec" DOUBLE PRECISION NOT NULL,
    "trackNo" INTEGER,
    "year" INTEGER,
    "bitrate" INTEGER,
    "codec" TEXT,
    "sizeBytes" BIGINT NOT NULL,
    "mtimeMs" BIGINT NOT NULL,
    "playCount" INTEGER NOT NULL DEFAULT 0,
    "lastPlayedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "tracks_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "tracks_path_key" ON "tracks"("path");

-- CreateIndex
CREATE INDEX "tracks_artist_idx" ON "tracks"("artist");

-- CreateIndex
CREATE INDEX "tracks_album_idx" ON "tracks"("album");

-- AddForeignKey
ALTER TABLE "history" ADD CONSTRAINT "history_trackId_fkey" FOREIGN KEY ("trackId") REFERENCES "tracks"("id") ON DELETE SET NULL ON UPDATE CASCADE;
