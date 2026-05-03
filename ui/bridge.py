"""
QML Bridge - Connects Python logic with QML interface.
Exposes services, event bus, and app manager to QML context.
"""

from typing import Any
from PySide6.QtCore import QObject, Signal, Slot, Property
from core.event_bus import get_event_bus
from core.app_manager import AppManager

class QmlBridge(QObject):
    """
    Bridge class to expose Python functionality to QML.
    """
    
    # Signals that QML can listen to
    eventReceived = Signal(str, Any)
    
    def __init__(self, app_manager: AppManager):
        super().__init__()
        self.app_manager = app_manager
        self.event_bus = get_event_bus()
        
        # Subscribe to all events to forward them to QML
        # In a real app, you might want to be more selective
        self._setup_event_forwarding()

    def _setup_event_forwarding(self):
        """Forward important events from EventBus to QML signals."""
        # For demo purposes, we'll forward some key events
        # In a more complex app, we might use a generic forwarding mechanism
        events_to_forward = [
            "service:ready",
            "radio:status",
            "radio:frequency_changed",
            "audio:volume_changed",
            "vehicle:signals:init",
            "media:playback_started",
            "bluetooth:connected"
        ]
        
        for event in events_to_forward:
            self.event_bus.subscribe(event, lambda data, e=event: self.eventReceived.emit(e, data))

    @Slot(str, Any)
    def publishEvent(self, event_name, data=None):
        """Allow QML to publish events back to Python."""
        self.event_bus.publish(event_name, data)

    @Slot(str, str)
    def switchScreen(self, screen_name):
        """Handle screen switching request from QML."""
        # This could also be handled purely in QML, but good to have here
        print(f"Switching to screen: {screen_name}")

    @Slot(str, result=Any)
    def getServiceStatus(self, service_id):
        """Get status of a service for QML."""
        status = self.app_manager.get_service_status(service_id)
        return status if status else {}

    @Slot()
    def startAll(self):
        """Start all services."""
        self.app_manager.start_all()

    # Specific helpers for services to make QML code cleaner
    def _get_internet_radio_service(self):
        """Helper to find the internet radio service."""
        from services.internet_radio import InternetRadioService
        for service in self.app_manager.services.values():
            if isinstance(service, InternetRadioService):
                return service
        return None

    @Slot(str, result=Any)
    def searchRadioStations(self, query):
        """Search stations and return list to QML."""
        radio = self._get_internet_radio_service()
        if radio:
            return radio.search_stations(query)
        return []

    @Slot(str, str)
    def playRadioUrl(self, url, name):
        """Play a specific URL from search results."""
        radio = self._get_internet_radio_service()
        if radio:
            radio.play_url(url, name)

    @Slot()
    def stopInternetRadio(self):
        """Stop internet radio playback."""
        radio = self._get_internet_radio_service()
        if radio:
            radio.stop()

    @Slot(int)
    def setVolume(self, volume):
        """Set global system volume and notify all services."""
        # Update all audio-capable services (Radio, Media, etc.)
        from services.base import AudioService
        for service in self.app_manager.services.values():
            if isinstance(service, AudioService):
                service.set_volume(volume)
        
        # Update the actual OS volume using SystemAudioService
        from services.system_audio import SystemAudioService
        for service in self.app_manager.services.values():
            if isinstance(service, SystemAudioService):
                service.set_system_volume(volume)
        
        # Publish a global volume event for the UI to sync
        self.event_bus.publish("audio:volume_changed", {"volume": volume})
