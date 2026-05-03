"""
Media Service - Music and playlist playback implementation.
"""

from typing import Any, Dict
from .base import AudioService

class MediaService(AudioService):
    """Media Service - Music/playlist playback."""
    
    service_id: str = "media"
    service_name: str = "Media Player"
    
    def __init__(self):
        super().__init__()
        self._current_file: str = ""
        self._is_playing: bool = False
    
    def start(self) -> bool:
        self.event_bus.publish("media:init", {"status": "ready"})
        self._on_init()
        return True
    
    def stop(self) -> bool:
        self._is_playing = False
        self.event_bus.publish("media:stopped", {})
        self.running = False
        return True
    
    def status(self) -> Dict[str, Any]:
        return {
            "current_file": self._current_file,
            "is_playing": self._is_playing
        }
    
    def play_file(self, file_path: str) -> bool:
        self._current_file = file_path
        self._is_playing = True
        self.event_bus.publish("media:playback_started", {"file": file_path})
        return True

    def pause(self) -> bool:
        self._is_playing = False
        self.event_bus.publish("media:paused", {})
        return True
