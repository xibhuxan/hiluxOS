import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const DEFAULT_SETTINGS: { key: string; value: string }[] = [
  { key: 'brightness', value: '80' },
  { key: 'volume', value: '50' },
  { key: 'theme', value: 'dark' },
  { key: 'wifi_enabled', value: 'true' },
  { key: 'bluetooth_enabled', value: 'false' },
];

async function main() {
  for (const s of DEFAULT_SETTINGS) {
    await prisma.setting.upsert({
      where: { key: s.key },
      update: {},
      create: s,
    });
  }
  console.log(`Seeded ${DEFAULT_SETTINGS.length} settings.`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });