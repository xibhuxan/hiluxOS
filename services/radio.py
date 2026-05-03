"""
Radio Service - FM/AM radio tuner implementation.
"""

from typing import Any, Dict, Optional
from .base import AudioService

class RadioService(AudioService):
    """Radio Service - FM/AM radio tuner."""
    
    service_id: str = "radio"
    service_name: str = "Radio"
    
    def __init__(self):
        super().__init__()
        self.frequency: Optional[float] = None
        self.stations: Dict[str, float] = {}
        self.current_station: str = ""
    
    def start(self) -> bool:
        self.event_bus.publish("radio:init", {"status": "ready"})
        self._on_init()
        return True
    
    def stop(self) -> bool:
        self.frequency = None
        self.event_bus.publish("radio:stopped", {})
        self.running = False
        return True
    
    def status(self) -> Dict[str, Any]:
        return {
            "frequency": self.frequency,
            "current_station": self.current_station,
            "stations_available": len(self.stations)
        }
    
    def tune_frequency(self, frequency: float) -> bool:
        if 87.5 <= frequency <= 108.0:
            self.frequency = frequency
            self.current_station = f"FM {frequency:.1f} MHz"
            self.event_bus.publish("radio:frequency_changed", {"frequency": frequency})
            return True
        return False

    def play_station(self, name: str) -> bool:
        if name in self.stations:
            return self.tune_frequency(self.stations[name])
        return False
