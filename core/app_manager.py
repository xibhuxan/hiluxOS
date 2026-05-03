"""
App Manager - Central manager for loading, initializing, and controlling services.
Handles module discovery, service lifecycle management, and event bus integration.
"""

import os
import json
import importlib
import logging
from typing import Dict, Optional, Type, Any
from pathlib import Path

from .event_bus import EventBus, get_event_bus


logger = logging.getLogger(__name__)


class BaseService:
    """Base class for all services in HiluxOS."""
    
    service_type: str = "base"
    requires_gpio: bool = False
    
    def __init__(self):
        self.event_bus: EventBus = get_event_bus()
        self.running = False
        self._init_called = False
    
    def _on_init(self) -> None:
        """Hook called after service initialization."""
        pass
    
    def start(self) -> bool:
        """Start the service. Override in subclasses."""
        return False
    
    def stop(self) -> bool:
        """Stop the service. Override in subclasses."""
        return False
    
    def status(self) -> Dict[str, Any]:
        """Get service status. Override in subclasses."""
        return {"running": self.running}
    
    def is_running(self) -> bool:
        """Check if service is running."""
        return self.running
    
    def on_init(self) -> None:
        """Initialize the service."""
        self._init_called = True
        self._on_init()


class AppManager:
    """
    Application Manager - Orchestrates the entire HiluxOS application.
    
    Responsibilities:
    - Load and initialize services
    - Manage module lifecycle
    - Connect UI to services via EventBus
    - Handle hardware abstraction layer
    """
    
    def __init__(self, hal_path: Optional[str] = None):
        """
        Initialize the AppManager.
        
        Args:
            hal_path: Path to HAL (Hardware Abstraction Layer) directory.
                      Auto-detects HAL if not provided.
        """
        self.event_bus = get_event_bus()
        self.hal_path = Path(hal_path) if hal_path else self._find_hal_path()
        
        # Service registry
        self.services: Dict[str, BaseService] = {}
        
        # Module registry
        self.modules: Dict[str, dict] = {}
        
        # Service groups (categories of services to start together)
        self.service_groups: Dict[str, list] = {
            "startup": [],      # Services to start on app launch
            "background": [],   # Services to run in background
            "audio": [],        # Audio-related services
            "media": [],        # Media-related services
            "vehicle": []       # Vehicle-related services
        }
        
        # Current service group being processed
        self._active_group: Optional[str] = None
        
        # HAL instances
        self.gpio_controller = None
        self.power_manager = None
        self.vehicle_signals = None
    
    def _find_hal_path(self) -> Path:
        """Auto-detect HAL path from project structure."""
        possible_paths = [
            Path(__file__).parent.parent / "hal",
            Path("/usr/share/hiluxos/hal"),
            Path.home() / ".hiluxos" / "hal",
        ]
        for path in possible_paths:
            if path.exists():
                return path
        return Path("hal")  # Default to relative path
    
    def load_hal(self) -> None:
        """Load Hardware Abstraction Layer components."""
        hal_dir = self.hal_path
        
        if not hal_dir.exists():
            logger.warning(f"HAL directory not found: {hal_dir}")
            return
        
        # Import HAL modules
        try:
            from hal.gpio_controller import GPIOController
            from hal.power_manager import PowerManager
            from hal.vehicle_signals import VehicleSignals
            
            self.gpio_controller = GPIOController(hal_dir)
            self.power_manager = PowerManager(hal_dir)
            self.vehicle_signals = VehicleSignals(hal_dir)
            
            logger.info(f"HAL loaded from: {hal_dir}")
            
        except ImportError as e:
            logger.warning(f"Could not load HAL components: {e}")
    
    def load_module(self, module_name: str, module_path: str) -> bool:
        """
        Load a module dynamically.
        
        Args:
            module_name: Name of the module (without extension)
            module_path: Path to the module directory
        
        Returns:
            True if module loaded successfully, False otherwise
        """
        module_dir = Path(module_path)
        
        if not module_dir.exists():
            logger.error(f"Module directory not found: {module_dir}")
            return False
        
        # Load manifest
        manifest_path = module_dir / "manifest.json"
        if not manifest_path.exists():
            logger.error(f"Missing manifest.json in module: {module_dir}")
            return False
        
        try:
            with open(manifest_path, 'r') as f:
                manifest = json.load(f)
        except json.JSONDecodeError as e:
            logger.error(f"Invalid manifest.json in {module_dir}: {e}")
            return False
        
        # Register module
        self.modules[module_name] = manifest
        
        # Determine service class
        service_name = manifest.get("service", "").lower()
        service_class = manifest.get("service_class", "")
        
        # Try to import and instantiate service
        service = self._create_service(service_name, service_class)
        
        if service:
            self.services[module_name] = service
            service_group = manifest.get("group", "background")
            self.service_groups[service_group].append(module_name)
            
            logger.info(f"Module loaded: {module_name}")
            return True
        
        return False
    
    def discover_modules(self) -> None:
        """Discover and load all modules in the modules directory."""
        modules_dir = Path(__file__).parent.parent / "modules"
        if not modules_dir.exists():
            logger.warning(f"Modules directory not found: {modules_dir}")
            return

        for item in modules_dir.iterdir():
            if item.is_dir() and (item / "manifest.json").exists():
                self.load_module(item.name, str(item))

    def _create_service(self, service_name: str, service_class_path: str) -> Optional[BaseService]:
        """Create a service instance based on configuration."""
        try:
            if not service_class_path:
                return None
            
            # Handle class path with colon (e.g., "module.path:ClassName")
            if ":" in service_class_path:
                module_path, class_name = service_class_path.split(":")
            else:
                module_path = service_class_path
                class_name = service_name
            
            # Fix for the "hiluxos." prefix if we are running from root
            if module_path.startswith("hiluxos."):
                # Check if hiluxos package exists, otherwise strip it
                try:
                    importlib.import_module("hiluxos")
                except ImportError:
                    module_path = module_path.replace("hiluxos.", "", 1)

            module = importlib.import_module(module_path)
            service_class = getattr(module, class_name)
            
            service = service_class()
            service.event_bus = self.event_bus
            return service
            
        except Exception as e:
            logger.error(f"Failed to create service {service_name} from {service_class_path}: {e}")
            return None
    
    def start_service(self, module_name: str) -> bool:
        """Start a service by module name."""
        if module_name not in self.services:
            logger.error(f"Service not found: {module_name}")
            return False
        
        service = self.services[module_name]
        if service.is_running():
            logger.info(f"Service already running: {module_name}")
            return True
        
        success = service.start()
        if success:
            service.running = True
            self.event_bus.publish("service:started", {"module": module_name})
        
        return success
    
    def stop_service(self, module_name: str) -> bool:
        """Stop a service by module name."""
        if module_name not in self.services:
            return False
        
        service = self.services[module_name]
        success = service.stop()
        
        if success:
            service.running = False
            self.event_bus.publish("service:stopped", {"module": module_name})
        
        return success
    
    def get_service_status(self, module_name: str) -> Optional[Dict[str, Any]]:
        """Get status of a service."""
        if module_name not in self.services:
            return None
        
        return self.services[module_name].status()
    
    def start_audio_services(self) -> None:
        """Start all audio-related services (Radio, Media, Audio)."""
        self._active_group = "audio"
        for module_name in self.service_groups["audio"]:
            self.start_service(module_name)
        self._active_group = None
    
    def start_all(self) -> None:
        """Start all services in order."""
        # Load HAL first
        self.load_hal()
        
        # Start background services
        for module_name in self.service_groups["background"]:
            self.start_service(module_name)
        
        # Start startup services
        for module_name in self.service_groups["startup"]:
            self.start_service(module_name)
        
        # Start audio services
        self.start_audio_services()
        
        # Initialize GPIO if available
        if self.gpio_controller:
            self.gpio_controller.init_gpio()
    
    def stop_all(self) -> None:
        """Stop all services."""
        for module_name in list(self.services.keys()):
            self.stop_service(module_name)
        
        if self.power_manager:
            self.power_manager.shutdown()
    
    def register_subscriber(self, event_name: str, callback: callable) -> None:
        """Register an event subscriber (convenience method)."""
        self.event_bus.subscribe(event_name, callback)
    
    def get_hal_gpio(self) -> Optional[Any]:
        """Get GPIO controller instance."""
        return self.gpio_controller
    
    def get_hal_power(self) -> Optional[Any]:
        """Get Power Manager instance."""
        return self.power_manager
    
    def get_hal_signals(self) -> Optional[Any]:
        """Get Vehicle Signals instance."""
        return self.vehicle_signals