#!/usr/bin/env python3
"""
HiluxOS - Automotive Infotainment System
Main entry point for the application.
"""

import sys
import logging
from pathlib import Path

from PySide6.QtWidgets import QApplication
from PySide6.QtCore import Qt

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
    try:
        # Initialize Qt application
        app = QApplication(sys.argv)
        app.setApplicationName("HiluxOS")
        app.setOrganizationName("HiluxOS")
        app.setStyle("Fusion")  # Use Fusion style for compatibility
        
        # Import after Qt is initialized
        from core.event_bus import EventBus, set_event_bus
        from core.app_manager import AppManager
        
        # Create global event bus
        event_bus = EventBus()
        set_event_bus(event_bus)
        
        # Create app manager
        app_manager = AppManager()
        
        # Load HAL (Hardware Abstraction Layer)
        app_manager.load_hal()
        
        # Discover and load modules
        app_manager.discover_modules()
        
        # Initialize HAL components
        hal_gpio = app_manager.get_hal_gpio()
        hal_power = app_manager.get_hal_power()
        hal_signals = app_manager.get_hal_signals()
        
        # Initialize HAL signals
        if hal_signals:
            hal_signals.init_signals(gpio_controller=hal_gpio)
            hal_signals.on_init()

        # --- QML INTEGRATION ---
        from PySide6.QtQml import QQmlApplicationEngine
        from ui.bridge import QmlBridge
        
        # Create bridge
        bridge = QmlBridge(app_manager)
        
        # Initialize QML engine
        engine = QQmlApplicationEngine()
        
        # Expose bridge to QML
        engine.rootContext().setContextProperty("bridge", bridge)
        
        # Load main QML file
        qml_file = Path(__file__).parent / "ui" / "Main.qml"
        engine.load(str(qml_file))
        
        if not engine.rootObjects():
            logger.error("Could not load QML engine")
            sys.exit(-1)
        
        # Start all services
        logger.info("Starting HiluxOS Services...")
        app_manager.start_all()
        
        # Demo: Simulate ignition on after startup
        def on_all_started():
            if hal_signals:
                hal_signals.simulate_ignition_on()
                hal_signals.set_speed(45.0)
                logger.info("Demo: Ignition ON, speed set to 45 km/h")
        
        event_bus.subscribe("service:ready", on_all_started)
        
        # Run application
        logger.info("HiluxOS ready - QML application starting")
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