"""
Home Screen - Modern touch-optimized dashboard screen for HiluxOS.
Full-screen display with large touch targets and clear visual separation.
"""

from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
    QFrame, QGridLayout
)
from PySide6.QtCore import Qt
from PySide6.QtGui import QFont


# Modern color palette
COLORS = {
    "bg": "#0d1117",
    "card": "#161b22",
    "text": "#c9d1d9",
    "text_muted": "#8b949e",
    "radio": "#58a6ff",
    "media": "#f0883e",
    "bt": "#339af0",
    "camera": "#d2a8ff",
    "settings": "#8b949e",
    "reverse": "#d2a8ff",
}


class HomeScreen(QWidget):
    """
    Modern Home Screen - Touch-optimized dashboard.
    
    Features:
    - Full-screen touch interface
    - Large touch targets (minimum 48x48 pixels)
    - Separate cards for each function
    - Clean visual hierarchy
    """
    
    def __init__(self, event_bus=None, app_manager=None):
        super().__init__()
        self.event_bus = event_bus
        self.app_manager = app_manager
        
        self._setup_ui()
        self._setup_style()
        
        # Set window size for full-screen display
        self.setMinimumSize(800, 600)
    
    def _setup_ui(self) -> None:
        """Setup modern home screen UI with separate cards."""
        layout = QGridLayout(self)
        layout.setSpacing(25)
        layout.setContentsMargins(40, 40, 40, 40)
        
        # Row 0: Engine status + Reverse indicator
        row_0 = QHBoxLayout()
        self._create_engine_card(row_0)
        self._create_reverse_card(row_0)
        layout.addLayout(row_0, 0, 0, 1, 2)
        
        # Row 1: Audio services
        row_1 = QHBoxLayout()
        self._create_radio_card(row_1)
        self._create_media_card(row_1)
        self._create_bt_card(row_1)
        layout.addLayout(row_1, 1, 0, 1, 2)
        
        # Row 2: Vehicle controls
        row_2 = QHBoxLayout()
        self._create_speed_card(row_2)
        self._create_brake_card(row_2)
        layout.addLayout(row_2, 2, 0, 1, 2)
        
        # Row 3: Additional features
        row_3 = QHBoxLayout()
        self._create_camera_card(row_3)
        self._create_settings_card(row_3)
        layout.addLayout(row_3, 3, 0, 1, 2)
    
    def _setup_style(self) -> None:
        """Setup overall style."""
        self.setStyleSheet(f"""
            QWidget {{
                background: {COLORS["bg"]};
            }}
        """)
    
    def _create_engine_card(self, parent) -> QWidget:
        """Create engine status card."""
        card = QFrame()
        card.setMinimumHeight(140)
        card.setStyleSheet(f"""
            QFrame {{
                background: {COLORS["card"]};
                border-radius: 24px;
                padding: 24px;
            }}
        """)
        
        layout = QVBoxLayout(card)
        layout.setContentsMargins(24, 24, 24, 24)
        
        # Engine icon
        icon_label = QLabel("🚗")
        icon_label.setFont(QFont("Segoe UI", 64))
        
        # Engine label
        label = QLabel("ENGINE")
        label.setFont(QFont("Segoe UI", 22, QFont.Bold))
        
        # Speed text
        speed = QLabel("0 km/h")
        speed.setStyleSheet("color: " + COLORS["text_muted"])
        speed.setFont(QFont("Segoe UI", 16))
        speed.setAlignment(Qt.AlignCenter)
        
        layout.addWidget(icon_label)
        layout.addWidget(label)
        layout.addWidget(speed)
        
        return card
    
    def _create_reverse_card(self, parent) -> QWidget:
        """Create reverse indicator card."""
        card = QFrame()
        card.setMinimumHeight(140)
        card.setStyleSheet(f"""
            QFrame {{
                background: {COLORS["card"]};
                border-radius: 24px;
                padding: 24px;
            }}
        """)
        
        layout = QVBoxLayout(card)
        layout.setContentsMargins(24, 24, 24, 24)
        
        # Reverse icon
        icon = QLabel("⬆")
        icon.setFont(QFont("Segoe UI", 64))
        
        # Reverse label
        label = QLabel("REVERSE")
        label.setFont(QFont("Segoe UI", 18))
        label.setStyleSheet("color: " + COLORS["text_muted"])
        
        layout.addWidget(icon)
        layout.addWidget(label)
        
        return card
    
    def _create_radio_card(self, parent) -> QWidget:
        """Create Radio card button."""
        btn = QPushButton()
        btn.setMinimumHeight(140)
        btn.setMinimumWidth(140)
        btn.setCursor(Qt.PointingHandCursor)
        btn.setStyleSheet(f"""
            QPushButton {{
                background: {COLORS["radio"]};
                border-radius: 28px;
                padding: 30px;
            }}
            QPushButton:hover {{
                background: #5ec8ff;
            }}
        """)
        
        # Create layout for button
        btn_layout = QHBoxLayout()
        btn_layout.setContentsMargins(0, 0, 0, 0)
        btn_layout.setSpacing(15)
        btn.setLayout(btn_layout)
        
        btn_layout.addWidget(QLabel("📻"))
        btn_layout.addWidget(QLabel("RADIO"))
        
        return btn
    
    def _create_media_card(self, parent) -> QWidget:
        """Create Media card button."""
        btn = QPushButton()
        btn.setMinimumHeight(140)
        btn.setMinimumWidth(140)
        btn.setCursor(Qt.PointingHandCursor)
        btn.setStyleSheet(f"""
            QPushButton {{
                background: {COLORS["media"]};
                border-radius: 28px;
                padding: 30px;
            }}
            QPushButton:hover {{
                background: #ffab40;
            }}
        """)
        
        # Create layout for button
        btn_layout = QHBoxLayout()
        btn_layout.setContentsMargins(0, 0, 0, 0)
        btn_layout.setSpacing(15)
        btn.setLayout(btn_layout)
        
        btn_layout.addWidget(QLabel("📀"))
        btn_layout.addWidget(QLabel("MEDIA"))
        
        return btn
    
    def _create_bt_card(self, parent) -> QWidget:
        """Create Bluetooth card button."""
        btn = QPushButton()
        btn.setMinimumHeight(140)
        btn.setMinimumWidth(140)
        btn.setCursor(Qt.PointingHandCursor)
        btn.setStyleSheet(f"""
            QPushButton {{
                background: {COLORS["bt"]};
                border-radius: 28px;
                padding: 30px;
            }}
            QPushButton:hover {{
                background: #4da6ff;
            }}
        """)
        
        # Create layout for button
        btn_layout = QHBoxLayout()
        btn_layout.setContentsMargins(0, 0, 0, 0)
        btn_layout.setSpacing(15)
        btn.setLayout(btn_layout)
        
        btn_layout.addWidget(QLabel("📶"))
        btn_layout.addWidget(QLabel("BT"))
        
        return btn
    
    def _create_speed_card(self, parent) -> QWidget:
        """Create speed gauge card."""
        card = QFrame()
        card.setMinimumHeight(140)
        card.setStyleSheet(f"""
            QFrame {{
                background: {COLORS["card"]};
                border-radius: 24px;
                padding: 24px;
            }}
        """)
        
        layout = QVBoxLayout(card)
        layout.setContentsMargins(24, 24, 24, 24)
        
        # Speed label
        label = QLabel("SPEED")
        label.setFont(QFont("Segoe UI", 18))
        
        # Speed value
        value = QLabel("0 km/h")
        value.setFont(QFont("Segoe UI", 36, QFont.Bold))
        value.setAlignment(Qt.AlignCenter)
        value.setStyleSheet("color: " + COLORS["bt"])
        value.setMinimumHeight(80)
        
        layout.addWidget(label)
        layout.addWidget(value)
        
        return card
    
    def _create_brake_card(self, parent) -> QWidget:
        """Create parking brake card."""
        card = QFrame()
        card.setMinimumHeight(140)
        card.setStyleSheet(f"""
            QFrame {{
                background: {COLORS["card"]};
                border-radius: 24px;
                padding: 24px;
            }}
        """)
        
        layout = QVBoxLayout(card)
        layout.setContentsMargins(24, 24, 24, 24)
        
        # Brake icon
        icon = QLabel("🔘")
        icon.setFont(QFont("Segoe UI", 64))
        
        # Brake label
        label = QLabel("BRAKE")
        label.setFont(QFont("Segoe UI", 18))
        label.setStyleSheet("color: " + COLORS["text_muted"])
        
        layout.addWidget(icon)
        layout.addWidget(label)
        
        return card
    
    def _create_camera_card(self, parent) -> QWidget:
        """Create Camera card button."""
        btn = QPushButton()
        btn.setMinimumHeight(120)
        btn.setMinimumWidth(120)
        btn.setCursor(Qt.PointingHandCursor)
        btn.setStyleSheet(f"""
            QPushButton {{
                background: {COLORS["camera"]};
                border-radius: 20px;
                padding: 20px;
            }}
            QPushButton:hover {{
                background: #dca1ff;
            }}
        """)
        
        # Create layout for button
        btn_layout = QHBoxLayout()
        btn_layout.setContentsMargins(0, 0, 0, 0)
        btn_layout.setSpacing(10)
        btn.setLayout(btn_layout)
        
        btn_layout.addWidget(QLabel("📷"))
        btn_layout.addWidget(QLabel("CAMERA"))
        
        return btn
    
    def _create_settings_card(self, parent) -> QWidget:
        """Create Settings card button."""
        btn = QPushButton()
        btn.setMinimumHeight(120)
        btn.setMinimumWidth(120)
        btn.setCursor(Qt.PointingHandCursor)
        btn.setStyleSheet(f"""
            QPushButton {{
                background: {COLORS["settings"]};
                border-radius: 20px;
                padding: 20px;
            }}
            QPushButton:hover {{
                background: #9ca0a6;
            }}
        """)
        
        # Create layout for button
        btn_layout = QHBoxLayout()
        btn_layout.setContentsMargins(0, 0, 0, 0)
        btn_layout.setSpacing(10)
        btn.setLayout(btn_layout)
        
        btn_layout.addWidget(QLabel("⚙️"))
        btn_layout.addWidget(QLabel("SET"))
        
        return btn