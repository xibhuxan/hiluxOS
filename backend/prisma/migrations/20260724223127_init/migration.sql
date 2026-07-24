-- CreateTable
CREATE TABLE "settings" (
    "key" TEXT NOT NULL,
    "value" TEXT NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "settings_pkey" PRIMARY KEY ("key")
);

-- CreateTable
CREATE TABLE "radio_stations" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "favicon" TEXT,
    "country" TEXT,
    "codec" TEXT,
    "bitrate" INTEGER,
    "tags" TEXT[],
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "radio_stations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "favorites" (
    "id" TEXT NOT NULL,
    "stationId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "favorites_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "history" (
    "id" TEXT NOT NULL,
    "stationId" TEXT,
    "kind" TEXT NOT NULL DEFAULT 'radio',
    "title" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "playedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "history_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "event_log" (
    "id" BIGSERIAL NOT NULL,
    "event" TEXT NOT NULL,
    "payload" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "event_log_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "radio_stations_url_key" ON "radio_stations"("url");

-- CreateIndex
CREATE UNIQUE INDEX "favorites_stationId_key" ON "favorites"("stationId");

-- CreateIndex
CREATE INDEX "history_playedAt_idx" ON "history"("playedAt");

-- CreateIndex
CREATE INDEX "event_log_event_idx" ON "event_log"("event");

-- CreateIndex
CREATE INDEX "event_log_createdAt_idx" ON "event_log"("createdAt");

-- AddForeignKey
ALTER TABLE "favorites" ADD CONSTRAINT "favorites_stationId_fkey" FOREIGN KEY ("stationId") REFERENCES "radio_stations"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "history" ADD CONSTRAINT "history_stationId_fkey" FOREIGN KEY ("stationId") REFERENCES "radio_stations"("id") ON DELETE SET NULL ON UPDATE CASCADE;
