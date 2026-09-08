import { IsString, MaxLength, MinLength } from 'class-validator';

/**
 * A text command for the assistant (already transcribed, e.g. typed on the
 * on-screen keyboard or sent by a test). The /voice/command endpoint runs the
 * same intent pipeline as a spoken command.
 */
export class VoiceCommandDto {
  /** The utterance in Spanish, e.g. "llévame a Bilbao". */
  @IsString()
  @MinLength(1)
  @MaxLength(300)
  text!: string;
}

/** A text-to-speech request. */
export class VoiceSpeakDto {
  /** The Spanish text to synthesise. */
  @IsString()
  @MinLength(1)
  @MaxLength(500)
  text!: string;
}
