"""
Internet Radio Service - Global search and robust streaming.
"""

import vlc
import logging
import time
import threading
import requests
from typing import Dict, List, Any, Optional
from .base import AudioService

logger = logging.getLogger(__name__)

class InternetRadioService(AudioService):
    """Service to search and play internet radio stations worldwide."""
    
    service_id = "internet_radio"
    service_name = "Internet Radio"
    
    def __init__(self):
        super().__init__()
        self._instance = vlc.Instance("--no-video --quiet --network-caching=5000")
        self._player = self._instance.media_player_new()
        self._current_station_name: str = "No Station"
        self._favorites: List[Dict] = []
        
        # API de Radio Browser (balanceo de carga automático)
        self._api_url = "https://de1.api.radio-browser.info/json"

        # Hilo de monitorización
        self._monitor_thread = threading.Thread(target=self._monitor_playback, daemon=True)
        self._monitor_thread.start()

    def _monitor_playback(self):
        last_state = None
        while True:
            try:
                if self._player:
                    state = self._player.get_state()
                    is_playing = (state == vlc.State.Playing)
                    if is_playing != last_state:
                        self.event_bus.publish("radio:status", {
                            "station": self._current_station_name,
                            "playing": is_playing
                        })
                        last_state = is_playing
            except: pass
            time.sleep(0.5)

    def search_stations(self, query: str) -> List[Dict]:
        """Search stations worldwide using the Radio Browser API."""
        try:
            url = f"{self._api_url}/stations/byname/{query}"
            response = requests.get(url, params={"limit": 20}, timeout=5)
            if response.status_code == 200:
                return response.json()
        except Exception as e:
            logger.error(f"Search error: {e}")
        return []

    def play_url(self, url: str, name: str) -> bool:
        try:
            self._player.stop()
            media = self._instance.media_new(url)
            self._player.set_media(media)
            self._player.play()
            self._current_station_name = name
            return True
        except Exception as e:
            logger.error(f"Play error: {e}")
            return False

    def start(self) -> bool:
        self._on_init()
        return True

    def stop(self) -> bool:
        self._player.stop()
        return True

    def status(self) -> dict:
        return {"station": self._current_station_name, "playing": self._player.is_playing()}

    def set_volume(self, volume: int) -> bool:
        super().set_volume(volume)
        if self._player:
            self._player.audio_set_volume(volume)
            return True
        return False
