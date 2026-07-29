-- CreateTable
CREATE TABLE "update_log" (
    "id" BIGSERIAL NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'idle',
    "fromVersion" TEXT,
    "toVersion" TEXT,
    "bundleUrl" TEXT,
    "error" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "update_log_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "update_log_status_idx" ON "update_log"("status");

-- CreateIndex
CREATE INDEX "update_log_createdAt_idx" ON "update_log"("createdAt");
