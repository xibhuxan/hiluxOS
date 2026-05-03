"""
Main Window - Full-screen touch-optimized for HiluxOS infotainment system.
"""

from PySide6.QtWidgets import (
    QMainWindow, QWidget, QVBoxLayout, QStackedWidget, QLabel
)
from PySide6.QtCore import Qt, Signal
from PySide6.QtGui import QFont


class MainWindow(QMainWindow):
    """
    Main Window for HiluxOS infotainment system.
    """
    
    screen_changed = Signal(str)
    
    def __init__(self, event_bus=None, app_manager=None):
        super().__init__()
        
        self.event_bus = event_bus
        self.app_manager = app_manager
        
        # Screen registry
        self.screens = {}
        self.current_screen = "home"
        
        # Setup
        self._setup_ui()
        self._setup_connections()
        
        # Set window properties
        self.setWindowTitle("HiluxOS - Infotainment System")
        self.setMinimumSize(1280, 720)
        self.setStyleSheet("""
            QMainWindow {
                background: #0d1117;
            }
        """)
        
        # Show window immediately
        self.show()
    
    def _setup_ui(self) -> None:
        """Setup main UI layout."""
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        layout = QVBoxLayout(central_widget)
        layout.setContentsMargins(0, 0, 0, 0)
        
        # Stacked widget for screens
        self.stacked_widget = QStackedWidget()
        layout.addWidget(self.stacked_widget)
    
    def _setup_connections(self) -> None:
        """Setup connections."""
        if self.app_manager:
            self.app_manager.event_bus.subscribe("service:ready", self._on_service_ready)
            self.app_manager.event_bus.subscribe("media:playback_started", self._on_media_playback_start)
            self.app_manager.event_bus.subscribe("radio:frequency_changed", self._on_radio_tune)
    
    def _on_service_ready(self, data) -> None:
        """Handle service ready event."""
        pass
    
    def _on_media_playback_start(self, data) -> None:
        """Handle media playback start."""
        pass
    
    def _on_radio_tune(self, data) -> None:
        """Handle radio frequency change."""
        pass
    
    def add_screen(self, name, widget, title=""):
        """Add a screen to the stacked widget."""
        if name in self.screens:
            raise ValueError(f"Screen already exists: {name}")
        
        self.screens[name] = widget
        self.stacked_widget.addWidget(widget)
        
        # Set initial screen if it's the first one
        if self.screens.get(self.current_screen) is None:
            self.stacked_widget.setCurrentIndex(len(self.stacked_widget) - 1)
            self.current_screen = name
    
    def switch_screen(self, screen_name):
        """Switch to a specific screen."""
        if screen_name in self.screens:
            index = self.stacked_widget.indexOf(self.screens[screen_name])
            self.stacked_widget.setCurrentIndex(index)
            self.current_screen = screen_name
            self.screen_changed.emit(screen_name)
    
    def show_home(self):
        """Show home screen."""
        if "home" in self.screens:
            self.switch_screen("home")
    
    def show_about(self):
        """Show about dialog."""
        from PySide6.QtWidgets import QMessageBox
        QMessageBox.about(
            self,
            "About HiluxOS",
            "<b>HiluxOS</b><br/>Automotive Infotainment System<br/>Version 0.1.0"
        )
    
    def get_current_screen(self):
        """Get current screen name."""
        return self.current_screen
    
    def get_current_screen_widget(self):
        """Get current screen widget."""
        return self.screens.get(self.current_screen)