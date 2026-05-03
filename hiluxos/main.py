#!/usr/bin/env python3
"""
HiluxOS - Automotive Infotainment System
Main entry point for the application.
"""

import sys
import logging
from pathlib import Path

from PySide6.QtWidgets import QApplication

# Add project root to path for imports
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def main():
    """Main entry point."""
    # Initialize Qt application
    app = QApplication(sys.argv)
    app.setApplicationName("HiluxOS")
    app.setOrganizationName("HiluxOS")
    
    # Import after Qt is initialized
    from core.event_bus import EventBus, set_event_bus
    from core.app_manager import AppManager
    from ui.main_window import MainWindow
    from ui.screens.home_screen import HomeScreen
    from ui.screens.radio_screen import RadioScreen
    from services.base_service import RadioService
    
    # Create global event bus
    event_bus = EventBus()
    set_event_bus(event_bus)
    
    # Create app manager
    app_manager = AppManager()
    
    # Load HAL (Hardware Abstraction Layer)
    app_manager.load_hal()
    
    # Initialize HAL components
    hal_gpio = app_manager.get_hal_gpio()
    hal_power = app_manager.get_hal_power()
    hal_signals = app_manager.get_hal_signals()
    
    # Initialize HAL signals
    if hal_signals:
        hal_signals.init_signals(gpio_controller=hal_gpio)
        hal_signals.on_init()
    
    # Create MainWindow
    window = MainWindow(event_bus=event_bus, app_manager=app_manager)
    
    # Create screens
    home_screen = HomeScreen(event_bus=event_bus, app_manager=app_manager)
    radio_screen = RadioScreen(
        event_bus=event_bus,
        app_manager=app_manager,
        radio_service=RadioService()
    )
    
    # Add screens to window
    window.add_screen("home", home_screen, "Home")
    window.add_screen("radio", radio_screen, "Radio")
    
    # Set initial screen
    window.switch_screen("home")
    
    # Load demo presets for radio
    demo_presets = {
        "Station 1": 100.0,
        "Station 2": 96.5,
        "Station 3": 104.5,
        "Station 4": 89.3,
        "Station 5": 107.5,
    }
    
    # Subscribe to service ready events for demo
    def on_radio_ready(data):
        if data.get("service_id") == "radio":
            radio_screen.load_presets(demo_presets)
            logger.info("Demo presets loaded")
    
    event_bus.subscribe("service:ready", on_radio_ready)
    
    # Start all services
    logger.info("Starting HiluxOS...")
    app_manager.start_all()
    
    # Demo: Simulate ignition on after startup
    def on_all_started():
        if hal_signals:
            hal_signals.simulate_ignition_on()
            hal_signals.set_speed(45.0)
            logger.info("Demo: Ignition ON, speed set to 45 km/h")
    
    event_bus.subscribe("service:ready", on_all_started)
    
    # Run application
    try:
        sys.exit(app.exec())
    except Exception as e:
        logger.error(f"Application error: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    logger.info("HiluxOS shutdown complete")
    return 0


if __name__ == "__main__":
    sys.exit(main())