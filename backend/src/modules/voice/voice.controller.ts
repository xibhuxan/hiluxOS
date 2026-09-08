import { Body, Controller, Delete, Get, Post, Res } from '@nestjs/common';
import type { Response } from 'express';
import { VoiceService } from './voice.service';
import { VoiceCommandDto, VoiceSpeakDto } from './dto/voice.dto';

/**
 * Voice assistant REST surface (mounted under /voice). The UI can drive the
 * assistant by text (typed command or test) or by audio (PCM from the mic),
 * read the conversation history, and request TTS audio for a reply.
 */
@Controller('voice')
export class VoiceController {
  constructor(private readonly voice: VoiceService) {}

  /** Full assistant state: status, ASR/TTS availability, conversation. */
  @Get()
  state() {
    return this.voice.getState();
  }

  /** The recent conversation history. */
  @Get('history')
  history() {
    return { history: this.voice.getHistory() };
  }

  /** Clear the conversation history. */
  @Delete('history')
  clearHistory() {
    this.voice.clearHistory();
    return { ok: true };
  }

  /**
   * Run a text command through the intent pipeline. Body: `{ text }`.
   * Returns the resulting conversation turn.
   */
  @Post('command')
  command(@Body() dto: VoiceCommandDto) {
    return this.voice.handleTextCommand(dto.text);
  }

  /**
   * Run a spoken command. Body: raw 16-bit mono PCM (16 kHz), content-type
   * application/octet-stream. The driver transcribes it and the pipeline runs.
   */
  @Post('listen')
  listen(@Body() pcm: Buffer) {
    return this.voice.handleAudioCommand(pcm ?? Buffer.alloc(0));
  }

  /**
   * Synthesise text to speech. Returns a WAV audio body the UI can play.
   */
  @Post('speak')
  async speak(@Body() dto: VoiceSpeakDto, @Res() res: Response) {
    const wav = await this.voice.speak(dto.text);
    res.setHeader('Content-Type', 'audio/wav');
    res.setHeader('Content-Length', String(wav.length));
    res.send(wav);
  }
}
