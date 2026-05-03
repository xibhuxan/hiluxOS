# HiluxOS - Automotive Infotainment System

> [!WARNING]
> **Project Status: Alpha / Incomplete**  
> This project is currently under active development and is in a non-functional, experimental state. Many features described below are partially implemented or exist only as architectural skeletons.

A modular, service-oriented infotainment system designed for automotive use on Linux platforms (Raspberry Pi and MiniPC compatible).

---

## Features (Planned & In-Progress)

- **Modular Architecture**: Add new modules following a consistent pattern.
- **Event-Driven**: Built-in EventBus for decoupled communication.
- **Hardware Abstraction (HAL)**: Interfaces for GPIO, power management, and vehicle signals.
- **Dual UI Support**: 
    - **QML (Modern)**: Interactive UI using Qt Quick/QML (under development at root `main.py`).
    - **Widgets (Legacy/Debug)**: Standard PySide6 widgets (accessible via `hiluxos/main.py`).
- **Service Pattern**: All services inherit from a common `BaseService`.

---

## Quick Start

### Configuration & Installation

Follow these steps to set up HiluxOS on your system:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/xibhuxan/hiluxOS.git
   cd hiluxOS
   ```

2. **Set up virtual environment (recommended):**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Linux/macOS
   ```

3. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

4. **Run the application:**
   ```bash
   python main.py
   ```

That's it! The QML-based interface should launch automatically.

---

## System Requirements

### Minimum Requirements
- **OS**: Linux (Debian/Ubuntu/Raspberry Pi OS)
- **Python**: 3.10 or higher
- **RAM**: 2GB minimum, 4GB recommended
- **Storage**: 500MB free space
- **GPU**: OpenGL 3.3+ (for QML rendering)

---

## Project Structure

```
.
├── core/                      # Core application logic
│   ├── app_manager.py         # Service orchestration & module discovery
│   └── event_bus.py           # Event-driven communication system
├── services/                  # Service implementations
│   ├── base.py                # BaseService & AudioService abstract classes
│   ├── internet_radio.py      # Internet radio service
│   ├── media.py               # Media playback service
│   ├── radio.py               # FM/AM Radio service
│   └── system_audio.py        # System volume & audio routing
├── ui/                        # UI components (QML & Bridge)
│   ├── bridge.py              # Python-to-QML bridge
│   ├── Main.qml               # Root QML interface
│   ├── components/            # Reusable QML components
│   └── screens/               # Screen-specific QML and Widget code
├── hal/                       # Hardware Abstraction Layer
│   ├── gpio_controller.py     # GPIO access (RPi + mock)
│   ├── power_manager.py       # Power hooks (Ignition, shutdown)
│   └── vehicle_signals.py     # Vehicle state signals (Speed, Reverse, etc.)
├── modules/                   # Module metadata & manifests
│   └── ...                    # Directory-based modules with manifest.json
├── assets/                    # Images, videos, and fonts
├── main.py                    # Primary entry point (QML-based)
└── hiluxos/main.py            # Secondary entry point (Widget-based)
```

---

## Architecture Overview

### Layers

1. **UI Layer** (`ui/`) - QML files or PySide6 widgets.
2. **Core Layer** (`core/`) - `AppManager` (lifecycle) and `EventBus` (messaging).
3. **Services Layer** (`services/`) - Logic for specific features (Radio, Media, etc.).
4. **HAL Layer** (`hal/`) - Hardware interaction (GPIO, signals).

### Event-Driven Communication

```python
from core.event_bus import get_event_bus
event_bus = get_event_bus()

# Publish an event
event_bus.publish("audio:volume_changed", {"volume": 80})

# Subscribe to events
event_bus.subscribe("radio:frequency_changed", callback)
```

---

## Creating a New Module

Modules in HiluxOS consist of a service implementation and a manifest file.

### Step 1: Create a Service

Create a new file in `services/` (or within your module directory) inheriting from `BaseService`:

```python
from services.base import BaseService

class MyCustomService(BaseService):
    service_id = "my_custom"
    service_name = "My Custom Service"
    
    def start(self) -> bool:
        # Initialization logic
        self._on_init() # Sets running=True and publishes ready event
        return True
    
    def stop(self) -> bool:
        self.running = False
        return True
        
    def status(self) -> dict:
        return {"active": self.running}
```

### Step 2: Create manifest.json

Place a `manifest.json` in `modules/your_module/`:

```json
{
    "name": "my_custom",
    "display_name": "My Custom Module",
    "version": "0.1.0",
    "service": "MyCustomService",
    "service_class": "services.my_custom:MyCustomService",
    "group": "background"
}
```

---

## Development Notes

### Module Development Workflow

1. Create your service class in `services/`
2. Create a corresponding `manifest.json` in `modules/`
3. Add any required dependencies to `requirements.txt`
4. Restart the application to load the new module

### Testing Modules

```bash
# List all loaded modules
python main.py --list-modules

# Test a specific service directly
python -c "from services.radio import RadioService; print('Radio Service loaded')"
```

---

## Known Issues & TODO

- [ ] **UI Integration**: QML interface is partially connected via `bridge.py`, but many components lack real data binding.
- [ ] **Service Architecture**: Currently, there's a duplication of `BaseService` definitions in `core/app_manager.py` and `services/base.py` that needs consolidation.
- [ ] **Hardware Support**: GPIO and vehicle signals are mostly mocked; real hardware testing on Raspberry Pi is in early stages.
- [ ] **Configuration System**: Global settings and module configurations are not yet fully implemented.

---

## Changelog

### Version 0.1.0 (Current - Alpha)
**Release Date**: 2026-03-05

**Added:**
- Initial QML UI implementation
- Event bus system for decoupled communication
- HAL layer for hardware abstraction
- Module manifest system
- Radio, Media, and System Audio services

**Changed:**
- Consolidated BaseService definitions (pending)
- Updated project structure for better modularity

**Fixed:**
- Resolved python-vlc dependency issue (now included in requirements.txt)

**Known Issues:**
- UI data binding incomplete
- Hardware support still in development

---

## License

MIT License

---

## Author

HiluxOS Team