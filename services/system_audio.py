"""
System Audio Service - Controls the actual OS master volume.
Supports ALSA (amixer) and PulseAudio/PipeWire (pactl).
"""

import subprocess
import logging
from .base import BaseService

logger = logging.getLogger(__name__)

class SystemAudioService(BaseService):
    """Service to link HiluxOS volume with OS master volume."""
    
    service_id = "system_audio"
    service_name = "System Audio Control"
    group = "background"
    
    def __init__(self):
        super().__init__()
        self._audio_backend = self._detect_backend()
        logger.info(f"System Audio Backend detected: {self._audio_backend}")

    def _detect_backend(self) -> str:
        """Detect if using pactl (PulseAudio/PipeWire) or amixer (ALSA)."""
        try:
            subprocess.run(["pactl", "info"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return "pactl"
        except FileNotFoundError:
            try:
                subprocess.run(["amixer", "scontrols"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                return "amixer"
            except FileNotFoundError:
                return "mock"

    def start(self) -> bool:
        self._on_init()
        return True

    def stop(self) -> bool:
        self.running = False
        return True

    def status(self) -> dict:
        return {"backend": self._audio_backend, "running": self.running}

    def set_system_volume(self, volume: int):
        """Execute shell commands to set system volume."""
        if not (0 <= volume <= 100):
            return

        try:
            if self._audio_backend == "pactl":
                # PulseAudio / PipeWire (Modern Linux / SteamDeck / PC)
                subprocess.run(["pactl", "set-sink-volume", "@DEFAULT_SINK@", f"{volume}%"], check=True)
            elif self._audio_backend == "amixer":
                # ALSA (Raspberry Pi / Legacy Linux)
                # Note: 'Master' is the common control name, might need config later
                subprocess.run(["amixer", "sset", "Master", f"{volume}%"], check=True)
            else:
                logger.debug(f"Mock Audio: Setting system volume to {volume}%")
        except Exception as e:
            logger.error(f"Failed to set system volume: {e}")
