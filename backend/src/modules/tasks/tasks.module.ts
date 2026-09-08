import { Module } from '@nestjs/common';
import { TasksController } from './tasks.controller';
import { TasksService } from './tasks.service';

@Module({
  controllers: [TasksController],
  providers: [TasksService],
  // Exported so the voice assistant can add/list reminders via its LLM tools.
  exports: [TasksService],
})
export class TasksModule {}