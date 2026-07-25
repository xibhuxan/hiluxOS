import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const DEFAULT_SETTINGS: { key: string; value: string }[] = [
  { key: 'brightness', value: '80' },
  { key: 'volume', value: '50' },
  { key: 'theme', value: 'dark' },
  { key: 'wifi_enabled', value: 'true' },
  { key: 'bluetooth_enabled', value: 'false' },
];

const DEFAULT_TASKS: { title: string; kind: string; value: string; priority: number }[] = [
  { title: 'ITV', kind: 'date', value: '12 septiembre', priority: 5 },
  { title: 'Cambio de aceite', kind: 'km', value: '800 km', priority: 3 },
  { title: 'Actualizar sistema', kind: 'version', value: 'v1.2 disponible', priority: 2 },
  { title: 'Backup pendiente', kind: 'none', value: '', priority: 1 },
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

  await prisma.task.deleteMany({});
  for (const t of DEFAULT_TASKS) {
    await prisma.task.create({ data: t });
  }
  console.log(`Seeded ${DEFAULT_TASKS.length} tasks.`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });