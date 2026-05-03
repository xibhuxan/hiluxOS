"""
Vehicle Signals - Hardware Abstraction Layer for vehicle state monitoring.
Simulates/receives signals: reverse gear, brake, turn indicators, door locks, etc.
"""

import logging
import time
from typing import Optional, Dict, Callable, Any
from pathlib import Path

logger = logging.getLogger(__name__)


class VehicleSignals:
    """
    Vehicle Signals - Abstraction layer for vehicle state signals.
    
    Signals monitored:
    - Reverse gear (triggers parking lights, horn warning)
    - Brake pedal (triggers parking camera, brake lights)
    - Turn indicators (turn signal state)
    - Door locks (lock/unlock status)
    - Ignition state (engine on/off)
    - Speed (vehicle speed)
    """
    
    def __init__(self, hal_path: Optional[str] = None):
        """
        Initialize Vehicle Signals.
        
        Args:
            hal_path: Path to HAL directory for config
        """
        self.hal_path = Path(hal_path) if hal_path else Path("hal")
        self._signal_states: Dict[str, Any] = {}
        self._callbacks: Dict[str, list] = {}
        self._gpio_controller = None
        
        # Default GPIO pins for Raspberry Pi
        self._default_gpio_pins = {
            "reverse": 4,
            "brake": 25,
            "horn": 26,
            "parking_light": 17,
            "parking_light_2": 27,
        }
        
        logger.info("Vehicle Signals initialized")
    
    def init_signals(self, gpio_controller=None) -> None:
        """
        Initialize signal monitoring.
        
        Args:
            gpio_controller: Optional GPIO controller instance
        """
        self._gpio_controller = gpio_controller
        
        # Register default signals
        self._register_signal("reverse", False)
        self._register_signal("brake", False)
        self._register_signal("horn", False)
        self._register_signal("parking_light", False)
        self._register_signal("parking_light_2", False)
        
        logger.info("Vehicle signals initialized")
    
    def _register_signal(self, name: str, initial_state: Any = None) -> None:
        """Register a vehicle signal."""
        if name not in self._signal_states:
            self._signal_states[name] = initial_state or {}
            self._signal_states[name]["name"] = name
            self._signal_states[name]["last_update"] = time.time()
            
            # Add default callback for important signals
            if name in ["reverse", "brake", "horn"]:
                if name not in self._callbacks:
                    self._callbacks[name] = []
    
    def set_signal(self, name: str, value: Any) -> bool:
        """
        Set a signal state.
        
        Args:
            name: Signal name (e.g., "reverse", "brake")
            value: Signal state (True/False/numeric/etc.)
        
        Returns:
            True if signal set successfully
        """
        if name in self._signal_states:
            self._signal_states[name]["value"] = value
            self._signal_states[name]["last_update"] = time.time()
            
            # Trigger callbacks
            self._notify_callbacks(name, value)
            
            logger.debug(f"Signal {name} set to {value}")
            return True
        
        return False
    
    def get_signal(self, name: str) -> Optional[Any]:
        """
        Get signal state.
        
        Args:
            name: Signal name
        
        Returns:
            Signal state or None
        """
        if name in self._signal_states:
            state = self._signal_states[name].get("value")
            return state if state is not None else False
        return None
    
    def _notify_callbacks(self, name: str, value: Any) -> None:
        """
        Notify all callbacks for a signal change.
        
        Args:
            name: Signal name
            value: New value
        """
        if name in self._callbacks:
            for callback in self._callbacks[name]:
                try:
                    # Callback receives (name, value) tuple
                    callback(name, value)
                except Exception as e:
                    logger.error(f"Signal callback error for {name}: {e}")
    
    def add_signal_callback(self, name: str, callback: Callable[[str, Any], None]) -> None:
        """
        Add callback for signal changes.
        
        Args:
            name: Signal name to subscribe to
            callback: Function(name, value) called on change
        """
        if name not in self._callbacks:
            self._callbacks[name] = []
        self._callbacks[name].append(callback)
    
    def add_all_callbacks(self, callback: Callable[[str, Any], None]) -> None:
        """
        Add single callback for all signals.
        
        Args:
            callback: Function(name, value) called for all signal changes
        """
        for name in self._signal_states:
            if name not in self._callbacks:
                self._callbacks[name] = []
            self._callbacks[name].append(callback)
    
    def get_signal_names(self) -> list:
        """Get list of all registered signal names."""
        return list(self._signal_states.keys())
    
    def get_all_signals(self) -> Dict[str, Any]:
        """Get all signal states."""
        return {
            name: self.get_signal(name)
            for name in self._signal_states
        }
    
    def on_init(self) -> None:
        """Initialize vehicle signals hook."""
        if self._gpio_controller:
            # Subscribe to GPIO events
            if "reverse" in self._gpio_controller.list_pins():
                self._gpio_controller.add_callback("reverse", lambda n, v: self.set_signal(n, v))
        
        # Publish initialization event
        try:
            self.event_bus = getattr(self, 'event_bus', None)
            if self.event_bus:
                self.event_bus.publish("vehicle:signals:init", {"status": "ready"})
        except Exception:
            pass
    
    def handle_gpio_event(self, pin_name: str, state: bool) -> None:
        """
        Handle GPIO event from controller.
        
        Args:
            pin_name: GPIO pin name (e.g., "reverse", "brake")
            state: GPIO state
        """
        # Map pin name to signal name
        signal_name = pin_name if pin_name in self._signal_states else None
        
        if signal_name:
            self.set_signal(signal_name, state)
    
    def simulate_ignition_on(self) -> bool:
        """Simulate ignition being turned on."""
        try:
            self._signal_states["ignition"] = {"value": True}
            logger.info("Ignition ON")
            return True
        except Exception as e:
            logger.error(f"Ignition ON error: {e}")
            return False
    
    def simulate_ignition_off(self) -> bool:
        """Simulate ignition being turned off."""
        try:
            self._signal_states["ignition"] = {"value": False}
            logger.info("Ignition OFF")
            return True
        except Exception as e:
            logger.error(f"Ignition OFF error: {e}")
            return False
    
    def simulate_reverse(self) -> bool:
        """Simulate reverse gear being engaged."""
        try:
            self.set_signal("reverse", True)
            self.set_signal("parking_light", True)
            self.set_signal("parking_light_2", True)
            logger.info("Reverse gear engaged")
            return True
        except Exception as e:
            logger.error(f"Reverse simulation error: {e}")
            return False
    
    def simulate_brake(self) -> bool:
        """Simulate brake being pressed."""
        try:
            self.set_signal("brake", True)
            self.set_signal("parking_light", False)
            logger.info("Brake pressed")
            return True
        except Exception as e:
            logger.error(f"Brake simulation error: {e}")
            return False
    
    def set_speed(self, speed: float) -> bool:
        """
        Set vehicle speed.
        
        Args:
            speed: Speed in km/h
        
        Returns:
            True if set successfully
        """
        try:
            self._signal_states["speed"] = {"value": speed}
            logger.debug(f"Vehicle speed: {speed} km/h")
            return True
        except Exception as e:
            logger.error(f"Speed set error: {e}")
            return False
    
    def get_speed(self) -> Optional[float]:
        """
        Get vehicle speed.
        
        Returns:
            Speed in km/h or None
        """
        return self._signal_states.get("speed", {}).get("value", 0.0)
    
    def get_ignition_state(self) -> Optional[bool]:
        """
        Get ignition state.
        
        Returns:
            True if ignition on, False if off
        """
        return self._signal_states.get("ignition", {}).get("value", False)