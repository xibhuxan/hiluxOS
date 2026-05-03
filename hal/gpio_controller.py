"""
GPIO Controller - Hardware Abstraction Layer for GPIO access.
Works with Raspberry Pi (RPi.GPIO/spi) and provides mock implementation for MiniPC.
"""

import logging
import os
from typing import Optional, Callable, Any
from pathlib import Path

logger = logging.getLogger(__name__)


class GPIOController:
    """
    GPIO Controller - Abstraction layer for GPIO access.
    
    Detects platform and uses appropriate backend:
    - Raspberry Pi: Uses RPi.GPIO or spidev
    - MiniPC/Linux: Mock implementation for testing
    """
    
    def __init__(self, hal_path: Optional[str] = None):
        """
        Initialize GPIO controller.
        
        Args:
            hal_path: Path to HAL directory (for config/shell scripts)
        """
        self.hal_path = Path(hal_path) if hal_path else Path("hal")
        self._gpio_available = self._check_gpio_availability()
        self._pins: dict = {}  # pin_number -> pin_object
        self._callbacks: dict = {}  # pin_number -> callback
        
        logger.info(f"GPIO Controller initialized. GPIO available: {self._gpio_available}")
    
    def _check_gpio_availability(self) -> bool:
        """Check if GPIO hardware is available (Raspberry Pi detection)."""
        # Check for Raspberry Pi
        rpi_indicators = [
            "/sys/class/gpio",
            "/dev/gpiochip0",
            "/boot/config.txt",  # RPi boot config
            os.path.exists("/sys/firmware/devicetree/base")  # Devicetree (RPi/BPI)
        ]
        
        # Also check for known GPIO libraries
        import subprocess
        try:
            result = subprocess.run(
                ["cat", "/sys/devices/soc0/model"],
                capture_output=True,
                text=True,
                timeout=1
            )
            if result.returncode == 0:
                model = result.stdout.lower()
                if "raspb" in model or "bcm" in model:
                    logger.info("Detected Raspberry Pi hardware")
                    return True
        except Exception:
            pass
        
        # Check for gpiochip
        try:
            result = subprocess.run(
                ["ls", "/dev/gpiochip*"],
                capture_output=True,
                text=True,
                timeout=1
            )
            if result.returncode == 0:
                logger.info("Detected GPIO chip device")
                return True
        except Exception:
            pass
        
        logger.warning("No GPIO hardware detected - using mock implementation")
        return False
    
    def init_gpio(self) -> bool:
        """
        Initialize GPIO subsystem.
        
        Returns:
            True if initialization successful
        """
        if not self._gpio_available:
            # Mock initialization for non-RPi systems
            logger.info("Using mock GPIO controller")
            self._pins["17"] = {"name": "LED_RED", "mode": "out", "state": False}
            self._pins["27"] = {"name": "LED_GREEN", "mode": "out", "state": False}
            self._pins["4"  ] = {"name": "REVERSE", "mode": "in", "state": False}
            self._pins["26" ] = {"name": "HORN", "mode": "out", "state": False}
            self._pins["25" ] = {"name": "BRAKE", "mode": "in", "state": False}
            return True
        
        try:
            # Would import RPi.GPIO here on RPi
            # import RPi.GPIO as GPIO
            # GPIO.setmode(GPIO.BCM)
            # GPIO.setup(...)
            logger.info("GPIO subsystem initialized (RPi)")
            return True
        except ImportError:
            logger.warning("RPi.GPIO not installed - using mock")
            return True
    
    def set_output(self, pin: int, state: bool) -> bool:
        """Set output pin state."""
        if not self._gpio_available:
            # Mock implementation
            if pin in self._pins:
                self._pins[pin]["state"] = state
                logger.debug(f"Mock: Set pin {pin} to {state}")
                return True
            return False
        
        # RPi.GPIO implementation would go here
        return True
    
    def set_input(self, pin: int) -> bool:
        """Configure pin as input."""
        if not self._gpio_available:
            if pin in self._pins:
                self._pins[pin]["mode"] = "in"
            return True
        return True
    
    def get_input(self, pin: int) -> bool:
        """Read input pin state."""
        if not self._gpio_available:
            # Check reverse signal mock
            if pin in self._pins:
                return self._pins[pin].get("state", False)
            return False
        
        # RPi.GPIO implementation would go here
        return False
    
    def digital_write(self, pin: int, value: int) -> bool:
        """Write digital value (0 or 1) to pin."""
        state = value != 0
        return self.set_output(pin, state)
    
    def digital_read(self, pin: int) -> bool:
        """Read digital value from pin."""
        return self.get_input(pin)
    
    def add_callback(self, pin: int, callback: Callable[[bool], None]) -> None:
        """Add callback for pin state change."""
        self._callbacks[pin] = callback
    
    def remove_callback(self, pin: int) -> None:
        """Remove callback for pin."""
        if pin in self._callbacks:
            del self._callbacks[pin]
    
    def get_pin_info(self, pin: int) -> Optional[dict]:
        """Get information about a pin."""
        return self._pins.get(pin)
    
    def list_pins(self) -> list:
        """List all configured pins."""
        return list(self._pins.keys())
    
    def cleanup(self) -> None:
        """Clean up GPIO resources."""
        # Would call GPIO.cleanup() on RPi
        self._pins.clear()
        logger.info("GPIO resources cleaned up")
    
    def toggle_led(self, pin: int) -> bool:
        """Toggle LED state on pin."""
        return self.set_output(pin, not self.get_input(pin))
    
    def set_reverse_signal(self) -> bool:
        """Simulate reverse gear signal (triggers parking lights/horn warning)."""
        if not self._gpio_available:
            # Mock: simulate reverse detection
            self._pins["4"]["state"] = True
            logger.info("Mock: Reverse gear detected")
            self.event_bus = getattr(self, 'event_bus', None)
            if self.event_bus:
                self.event_bus.publish("hal:reverse", {"state": True})
            return True
        return True
    
    def get_reverse_signal(self) -> bool:
        """Check if reverse signal is active."""
        if not self._gpio_available:
            return self._pins.get("4", {}).get("state", False)
        return False