"""
Base Service - Abstract base classes for all HiluxOS services.
"""

from abc import ABC, abstractmethod
from typing import Any, Dict
from core.event_bus import EventBus, get_event_bus

class BaseService(ABC):
    """Abstract Base Service for HiluxOS."""
    
    service_id: str = "base"
    service_name: str = "Base Service"
    group: str = "background"
    requires_gpio: bool = False
    requires_hardware: bool = False
    
    def __init__(self):
        self.event_bus: EventBus = get_event_bus()
        self.running: bool = False
        self._status_info: Dict[str, Any] = {}
    
    @abstractmethod
    def start(self) -> bool:
        pass
    
    @abstractmethod
    def stop(self) -> bool:
        pass
    
    @abstractmethod
    def status(self) -> Dict[str, Any]:
        pass
    
    def is_running(self) -> bool:
        return self.running
    
    def _on_init(self) -> None:
        self.running = True
        self.event_bus.publish("service:ready", {
            "service_id": self.service_id,
            "service_name": self.service_name
        })

class AudioService(BaseService):
    """Abstract Audio Service for audio-related functionality."""
    
    service_id: str = "audio"
    service_name: str = "Audio Service"
    group: str = "audio"
    
    def __init__(self):
        super().__init__()
        self.volume = 50
        self.muted = False
    
    def set_volume(self, volume: int) -> bool:
        if 0 <= volume <= 100:
            self.volume = volume
            self.event_bus.publish("audio:volume_changed", {"volume": volume})
            return True
        return False

    def toggle_mute(self) -> bool:
        self.muted = not self.muted
        self.event_bus.publish("audio:muted", {"muted": self.muted})
        return True
