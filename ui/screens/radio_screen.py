"""
Radio Screen - UI for the Radio service.
Demonstrates audio player screen pattern with frequency tuning and presets.
"""

from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
    QSlider, QFrame, QComboBox, QListWidget, QListWidgetItem, QGroupBox
)
from PySide6.QtCore import Qt, Signal, QTimer
from PySide6.QtGui import QFont


class RadioScreen(QWidget):
    """
    Radio Screen - FM Radio tuner interface.
    
    Features:
    - Frequency tuning (87.5 - 108.0 MHz)
    - Station presets
    - Volume control
    - Status display
    """
    
    # Signals for external communication
    frequency_changed = Signal(float)
    volume_changed = Signal(int)
    playback_started = Signal(str)
    
    def __init__(self, event_bus=None, app_manager=None, radio_service=None):
        """
        Initialize radio screen.
        
        Args:
            event_bus: EventBus instance
            app_manager: AppManager instance
            radio_service: Optional RadioService instance
        """
        super().__init__()
        
        self.event_bus = event_bus
        self.app_manager = app_manager
        self.radio_service = radio_service
        
        self._setup_ui()
        self._setup_connections()
    
    def _setup_ui(self) -> None:
        """Setup radio screen UI."""
        layout = QVBoxLayout(self)
        layout.setContentsMargins(10, 10, 10, 10)
        layout.setSpacing(10)
        
        # Title bar
        title_layout = QHBoxLayout()
        title_label = QLabel("FM Radio")
        title_label.setFont(QFont("Sans Serif", 20, QFont.Bold))
        title_label.setStyleSheet("color: #3498db;")
        
        # Frequency display
        self.frequency_label = QLabel("100.0 MHz")
        self.frequency_label.setFont(QFont("Monospace", 32))
        self.frequency_label.setStyleSheet("color: #f1c40f; background: #2c3e50; padding: 5px; border-radius: 5px;")
        
        title_layout.addWidget(title_label)
        title_layout.addWidget(self.frequency_label, alignment=Qt.AlignCenter)
        title_layout.addStretch()
        
        layout.addLayout(title_layout)
        layout.addSpacing(20)
        
        # Volume control
        volume_frame = QFrame()
        volume_frame.setStyleSheet("background: #34495e; border-radius: 10px; padding: 10px;")
        
        volume_layout = QVBoxLayout(volume_frame)
        
        volume_label = QLabel("Volume")
        volume_label.setStyleSheet("color: #ecf0f1; font-size: 12px;")
        
        # Volume slider
        self.volume_slider = QSlider(Qt.Horizontal)
        self.volume_slider.setMinimum(0)
        self.volume_slider.setMaximum(100)
        self.volume_slider.setValue(50)
        self.volume_slider.setTickPosition(QSlider.TicksBelow)
        self.volume_slider.setTickInterval(10)
        
        # Play/Pause button
        self.play_pause_btn = QPushButton("PLAY")
        self.play_pause_btn.setFixedHeight(40)
        self.play_pause_btn.setStyleSheet("""
            QPushButton {
                background: #27ae60;
                color: white;
                font-size: 16px;
                font-weight: bold;
                border-radius: 5px;
                padding: 10px;
            }
            QPushButton:hover {
                background: #2ecc71;
            }
            QPushButton:pressed {
                background: #1e8449;
            }
        """)
        
        volume_layout.addWidget(volume_label, alignment=Qt.AlignCenter)
        volume_layout.addWidget(self.volume_slider, alignment=Qt.AlignCenter)
        volume_layout.addWidget(self.play_pause_btn, alignment=Qt.AlignCenter)
        
        layout.addWidget(volume_frame)
        layout.addSpacing(15)
        
        # Presets section
        presets_frame = QFrame()
        presets_frame.setStyleSheet("background: #34495e; border-radius: 10px; padding: 10px;")
        
        presets_layout = QVBoxLayout(presets_frame)
        
        presets_title = QLabel("Presets")
        presets_title.setStyleSheet("color: #ecf0f1; font-size: 12px; font-weight: bold;")
        
        # Preset list
        self.preset_list = QListWidget()
        self.preset_list.setMaximumHeight(120)
        self.preset_list.setStyleSheet("QListWidget { background: #2c3e50; color: #ecf0f1; border: none; }")
        
        presets_layout.addWidget(presets_title, alignment=Qt.AlignCenter)
        presets_layout.addWidget(self.preset_list, alignment=Qt.AlignCenter)
        
        layout.addWidget(presets_frame)
        layout.addSpacing(15)
        
        # Status section
        status_frame = QFrame()
        status_frame.setStyleSheet("background: #2c3e50; border-radius: 10px; padding: 10px;")
        
        status_layout = QHBoxLayout(status_frame)
        
        # Station label
        self.station_label = QLabel("No station selected")
        self.station_label.setStyleSheet("color: #95a5a6; font-size: 14px;")
        
        # Status LED
        self.status_led = QFrame()
        self.status_led.setFixedSize(10, 10)
        self.status_led.setStyleSheet("background: #95a5a6; border-radius: 5px;")
        
        status_layout.addWidget(self.status_led)
        status_layout.addWidget(self.station_label)
        status_layout.addStretch()
        
        layout.addWidget(status_frame)
    
    def _setup_connections(self) -> None:
        """Setup connections."""
        if self.radio_service:
            # Connect to service events
            if hasattr(self.radio_service, 'event_bus'):
                self.radio_service.event_bus.subscribe("radio:frequency_changed", self._on_frequency_changed)
        
        if self.app_manager:
            self.app_manager.event_bus.subscribe("radio:frequency_changed", self._on_frequency_changed)
        
        # Connect slider and buttons
        self.volume_slider.valueChanged.connect(self._on_volume_changed)
        self.play_pause_btn.clicked.connect(self._on_play_pause)
        self.preset_list.itemDoubleClicked.connect(self._on_preset_selected)
    
    def _on_volume_changed(self, volume: int) -> None:
        """Handle volume change."""
        if self.radio_service:
            self.radio_service.set_volume(volume)
            self.volume_changed.emit(volume)
    
    def _on_play_pause(self) -> None:
        """Handle play/pause toggle."""
        if self.radio_service:
            status = self.radio_service.status()
            is_playing = status.get('frequency', None) is not None
            
            if is_playing:
                self.play_pause_btn.setText("PAUSE")
                self.play_pause_btn.setStyleSheet("""
                    QPushButton {
                        background: #e74c3c;
                        color: white;
                        font-size: 16px;
                        font-weight: bold;
                        border-radius: 5px;
                        padding: 10px;
                    }
                """)
            else:
                self.play_pause_btn.setText("PLAY")
                self.play_pause_btn.setStyleSheet("""
                    QPushButton {
                        background: #27ae60;
                        color: white;
                        font-size: 16px;
                        font-weight: bold;
                        border-radius: 5px;
                        padding: 10px;
                    }
                """)
    
    def _on_frequency_changed(self, data: dict) -> None:
        """Handle frequency change event."""
        freq = data.get('frequency', 0.0)
        self.frequency_label.setText(f"{freq:.1f} MHz")
        self.station_label.setText(f"FM {freq:.1f} MHz")
        self.frequency_changed.emit(freq)
        
        # Update status LED
        if freq > 0:
            self.status_led.setStyleSheet("background: #2ecc71;")
        else:
            self.status_led.setStyleSheet("background: #95a5a6;")
    
    def _on_preset_selected(self, item) -> None:
        """Handle preset selection."""
        preset_name = item.text()
        if self.radio_service:
            self.radio_service.play_station(preset_name)
    
    def load_presets(self, presets: dict) -> None:
        """
        Load station presets.
        
        Args:
            presets: Dict of preset_name -> frequency
        """
        self.preset_list.clear()
        
        for name, freq in sorted(presets.items()):
            item = QListWidgetItem(f"FM {freq:.1f} MHz")
            self.preset_list.addItem(item)
        
        # Auto-select first preset
        if presets:
            self.preset_list.setCurrentRow(0)
    
    def set_volume(self, volume: int) -> None:
        """Set volume level."""
        self.volume_slider.setValue(volume)
    
    def get_volume(self) -> int:
        """Get current volume level."""
        return self.volume_slider.value()
    
    def set_frequency(self, frequency: float) -> None:
        """Set frequency."""
        if self.radio_service:
            self.radio_service.tune_frequency(frequency)
        self.frequency_label.setText(f"{frequency:.1f} MHz")
        self.station_label.setText(f"FM {frequency:.1f} MHz")
        self.frequency_changed.emit(frequency)
    
    def get_frequency(self) -> float:
        """Get current frequency."""
        if self.radio_service:
            return self.radio_service.frequency or 0.0
        return 0.0
    
    def is_playing(self) -> bool:
        """Check if radio is playing."""
        if self.radio_service:
            status = self.radio_service.status()
            return status.get('frequency') is not None
        return False