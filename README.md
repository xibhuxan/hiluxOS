# HiluxOS - Automotive Infotainment System

A modular, service-oriented infotainment system designed for automotive use on Linux platforms (Raspberry Pi and MiniPC compatible).

## Features

- **Modular Architecture**: Add new modules following a consistent pattern
- **Event-Driven**: Built-in EventBus for decoupled communication
- **Hardware Abstraction**: Works on Raspberry Pi (GPIO) and generic Linux systems
- **PySide6 UI**: Clean, responsive GUI
- **Service Pattern**: All services inherit from `BaseService`

## Project Structure

```
hiluxos/
├── core/                      # Core application logic
│   ├── app_manager.py         # Service orchestration
│   └── event_bus.py           # Event-driven communication
├── services/                  # Service implementations
│   ├── base_service.py        # BaseService + Audio subclasses
│   ├── audio/                 # Audio-specific services
│   └── ...
├── ui/                        # PySide6 UI components
│   ├── main_window.py         # Main application window
│   └── screens/               # Screen widgets
│       ├── home_screen.py     # Home dashboard
│       └── radio_screen.py    # Radio example
├── hal/                       # Hardware Abstraction Layer
│   ├── gpio_controller.py     # GPIO access (RPi + mock)
│   ├── power_manager.py       # Power hooks
│   └── vehicle_signals.py     # Vehicle state signals
├── modules/                   # Module system
│   └── example_radio/         # Example module template
├── assets/                    # Images, sounds, configs
├── config/                    # Configuration files
└── main.py                    # Application entry point
```

## Quick Start

### Installation

```bash
# Clone or copy the project
cd hiluxos

# Install dependencies
pip install PySide6

# Run the application
python main.py
```

### Running on Raspberry Pi

```bash
# On Raspberry Pi OS
sudo apt install python3-pyside6 rpi.gpio

# Run
python main.py
```

## Architecture Overview

### Layers

1. **UI Layer** (`ui/`) - PySide6 widgets, screens
2. **Core Layer** (`core/`) - AppManager, EventBus
3. **Services Layer** (`services/`) - Business logic
4. **HAL Layer** (`hal/`) - Hardware abstraction

### Event-Driven Communication

```python
# Publish an event
event_bus.publish("audio:volume_changed", {"volume": 80})

# Subscribe to events
event_bus.subscribe("radio:frequency_changed", callback)
```

## Creating a New Module

### Step 1: Create Module Directory

```bash
mkdir -p modules/your_module
```

### Step 2: Create manifest.json

```json
{
    "name": "your_module",
    "display_name": "Your Module Name",
    "version": "0.1.0",
    "description": "Description of your module",
    "service": "YourService",
    "service_class": "path.to.your_module:YourService",
    "group": "audio",  // startup, background, audio, vehicle
    "requires_gpio": false,
    "requires_hardware": true,
    "ui": false,  // or true if you want a UI screen
    "screenshots": [],
    "dependencies": []
}
```

### Step 3: Create Your Service

Create `your_module.py` with a service class:

```python
"""
Your Module Service
"""

from services.base_service import BaseService, AudioService

class YourService(AudioService):
    """
    Your service implementation.
    
    Must implement:
    - start(): Initialize service
    - stop(): Cleanup resources
    - status(): Return status dict
    """
    
    service_id = "your_module"
    service_name = "Your Service"
    
    def __init__(self):
        super().__init__()
        self._your_state = {}
    
    def start(self) -> bool:
        """Initialize your service."""
        # Your initialization code
        self.event_bus.publish("your_module:init", {"status": "ready"})
        return True
    
    def stop(self) -> bool:
        """Cleanup your service."""
        self.event_bus.publish("your_module:stopped", {})
        return True
    
    def status(self) -> dict:
        """Return status information."""
        return {
            "state": self._your_state,
            "running": self.running
        }
```

### Step 4: Create UI Screen (Optional)

If you want a UI screen, create it in `ui/screens/your_screen.py`:

```python
from PySide6.QtWidgets import QWidget, QVBoxLayout, QLabel, QPushButton

class YourScreen(QWidget):
    """Your UI screen."""
    
    def __init__(self, event_bus=None, app_manager=None, service=None):
        super().__init__()
        self.service = service
        
        layout = QVBoxLayout(self)
        layout.addWidget(QLabel("Your Screen"))
        layout.addWidget(QPushButton("Button"))
```

### Step 5: Add to AppManager

The AppManager automatically loads modules from `modules/` directory if they have a valid `manifest.json`.

### Step 6: Connect UI + Service

```python
# In your screen's setup
if self.service:
    self.service.event_bus.subscribe("your_event", self._on_event)
```

## EventBus Usage

### Publish

```python
event_bus.publish("event_name", {"data": "payload"})
```

### Subscribe

```python
def callback(data):
    print(f"Received: {data}")

event_bus.subscribe("event_name", callback)
```

### Service Events

| Event | Description | Data |
|-------|-------------|------|
| `service:ready` | Service initialized | `{"service_id": "...", "service_name": "..."}` |
| `service:stopped` | Service stopped | `{"module": "..."}` |
| `radio:frequency_changed` | Radio tuned | `{"frequency": ...}` |
| `media:playback_started` | Media playing | `{"file": "..."}` |
| `audio:volume_changed` | Volume changed | `{"volume": ...}` |
| `audio:muted` | Mute state | `{"muted": ...}` |
| `bluetooth:connected` | Bluetooth connected | `{"device": "..."}` |
| `hal:reverse` | Reverse gear | `{"state": True}` |

## Vehicle Signals

The HAL provides access to vehicle state:

```python
# Get signals
signals = app_manager.get_hal_signals()

# Simulate reverse
signals.simulate_reverse()

# Get reverse state
reverse = signals.get_signal("reverse")

# Set speed
signals.set_speed(50.0)

# Get speed
speed = signals.get_speed()

# Check ignition
ignition = signals.get_ignition_state()
```

## Service Groups

Services are organized into groups:

- **startup**: Started on app launch
- **background**: Run in background
- **audio**: Audio-related services
- **vehicle**: Vehicle-related services

Configure in `manifest.json`:

```json
"group": "audio"  // or "background", "startup"
```

## Configuration

Place config files in `config/`:

- `config/settings.json` - Global settings
- `config/modules.yaml` - Module configuration
- `config/gpio_pins.txt` - GPIO pin mapping

## License

MIT License

## Author

HiluxOS Team