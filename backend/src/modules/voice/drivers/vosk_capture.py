#!/usr/bin/env python3
"""Real-microphone capture + Vosk transcription helper for hiluxOS.

Records a short window from the default input device (sounddevice/PortAudio)
at 16 kHz mono 16-bit and feeds it to a Vosk recogniser. Prints the recognised
Spanish text on stdout (empty when nothing intelligible was heard).

Usage: vosk_capture.py <model_dir> [seconds]

Runs under the project venv (VOICE_PYTHON) which has `vosk` + `sounddevice`.
Invoked by VoskVoiceDriver.transcribe(). Kept dependency-light and quiet so it
can be spawned per utterance; on the Pi this can become a long-lived streaming
process without changing the Node contract.
"""
import sys
import json
import queue
import time


def main() -> int:
    try:
        import vosk  # noqa: F401  (import here so --help works without the lib)
        import sounddevice as sd
        from vosk import Model, KaldiRecognizer, SetLogLevel
    except Exception:
        # ASR stack not installed → print nothing and exit cleanly.
        return 0

    model_dir = sys.argv[1] if len(sys.argv) > 1 else "/opt/hiluxos/models/vosk-es"
    seconds = float(sys.argv[2]) if len(sys.argv) > 2 else 4.0

    SetLogLevel(-1)  # silence Kaldi/Vosk logs
    rec = KaldiRecognizer(Model(model_dir), 16000)
    rec.SetWords(True)

    q: "queue.Queue[bytes]" = queue.Queue()

    def _cb(indata, frames, t, status):  # noqa: ANN001 - sounddevice callback
        q.put(bytes(indata))

    try:
        with sd.RawInputStream(
            samplerate=16000, blocksize=4000, dtype="int16", channels=1, callback=_cb
        ):
            end = time.time() + seconds
            while time.time() < end:
                try:
                    rec.AcceptWaveform(q.get(timeout=0.3))
                except queue.Empty:
                    continue
    except Exception:
        return 0

    text = json.loads(rec.FinalResult()).get("text", "")
    sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
