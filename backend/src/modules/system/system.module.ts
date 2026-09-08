import { Module } from '@nestjs/common';
import { SystemController } from './system.controller';
import { SystemService } from './system.service';
import { CommandRunner } from './command-runner';

@Module({
  controllers: [SystemController],
  providers: [CommandRunner, SystemService],
  // Export so the voice assistant can drive master volume/mute.
  exports: [SystemService],
})
export class SystemModule {}