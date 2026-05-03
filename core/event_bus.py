"""
Event Bus - Simple publish/subscribe implementation for event-driven communication.
Used for decoupling UI from services and enabling inter-service communication.
"""

import threading
from typing import Callable, Any, Dict
from collections import defaultdict


class EventBus:
    """Thread-safe event bus for publish/subscribe pattern."""
    
    def __init__(self):
        self._subscribers: Dict[str, list] = defaultdict(list)
        self._lock = threading.Lock()
    
    def subscribe(self, event_name: str, callback: Callable[[Any], None]) -> None:
        """Subscribe to an event.
        
        Args:
            event_name: Name of the event to subscribe to
            callback: Function to call when event is published (event_name -> data)
        """
        with self._lock:
            self._subscribers[event_name].append(callback)
    
    def publish(self, event_name: str, data: Any = None) -> None:
        """Publish an event to all subscribers.
        
        Args:
            event_name: Name of the event to publish
            data: Data to send with the event
        """
        with self._lock:
            callbacks = self._subscribers[event_name]
        
        # Call callbacks with thread safety
        for callback in callbacks:
            try:
                callback(data)
            except Exception as e:
                # Log error in production, skip for now
                pass
    
    def unsubscribe(self, event_name: str, callback: Callable[[Any], None]) -> None:
        """Remove a subscriber.
        
        Args:
            event_name: Event to unsubscribe from
            callback: Callback to remove
        """
        with self._lock:
            if event_name in self._subscribers:
                self._subscribers[event_name].remove(callback)
    
    def get_subscriber_count(self, event_name: str) -> int:
        """Get number of subscribers for an event."""
        return len(self._subscribers.get(event_name, []))


# Global event bus instance - used by default across the application
_global_event_bus = EventBus()


def get_event_bus() -> EventBus:
    """Get the global event bus instance."""
    return _global_event_bus


def set_event_bus(bus: EventBus) -> None:
    """Set a custom event bus instance."""
    global _global_event_bus
    _global_event_bus = bus