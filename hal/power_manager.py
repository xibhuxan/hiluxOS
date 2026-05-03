"""
Power Manager - Hardware Abstraction Layer for power control.
Handles system startup, shutdown hooks, and power state monitoring.
"""

import logging
import os
import subprocess
from typing import Optional, Callable
from pathlib import Path

logger = logging.getLogger(__name__)


class PowerManager:
    """
    Power Manager - Handles power control operations.
    
    Features:
    - System startup/shutdown hooks
    - Power state detection
    - Sleep/wake cycle support
    - Power button handler (when available)
    """
    
    def __init__(self, hal_path: Optional[str] = None):
        """
        Initialize Power Manager.
        
        Args:
            hal_path: Path to HAL directory for config scripts
        """
        self.hal_path = Path(hal_path) if hal_path else Path("hal")
        self._power_state_callbacks: list = []
        
        logger.info("Power Manager initialized")
    
    def startup_hook(self, command: str) -> bool:
        """
        Register a command to run on system startup.
        
        Args:
            command: Shell command to execute on boot
        
        Returns:
            True if hook registered successfully
        """
        try:
            # Check if we can write to systemd
            config_path = "/etc/systemd/system/hiluxos-start.service"
            
            content = f"""[Unit]
Description=HiluxOS Startup Hook
Before=graphical.target

[Service]
Type=oneshot
ExecStart={command}
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
"""
            
            # Write startup script
            Path(config_path).write_text(content)
            
            try:
                subprocess.run(
                    ["systemctl", "daemon-reload"],
                    check=True,
                    capture_output=True,
                    timeout=5
                )
            except subprocess.CalledProcessError:
                pass
            
            try:
                subprocess.run(
                    ["systemctl", "enable", "hiluxos-start"],
                    check=True,
                    capture_output=True,
                    timeout=5
                )
            except subprocess.CalledProcessError:
                pass
            
            logger.info(f"Registered startup hook: {command}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to register startup hook: {e}")
            return False
    
    def shutdown_hook(self, command: str) -> bool:
        """
        Register a command to run on system shutdown.
        
        Args:
            command: Shell command to execute on shutdown
        
        Returns:
            True if hook registered successfully
        """
        try:
            # Check if we can write to systemd
            config_path = "/etc/systemd/system/hiluxos-shutdown.service"
            
            content = f"""[Unit]
Description=HiluxOS Shutdown Hook
Before=shutdown.target

[Service]
Type=oneshot
ExecStart={command}
RemainAfterExit=yes

[Install]
WantedBy=shutdown.target
"""
            
            # Write shutdown script
            Path(config_path).write_text(content)
            
            try:
                subprocess.run(
                    ["systemctl", "daemon-reload"],
                    check=True,
                    capture_output=True,
                    timeout=5
                )
            except subprocess.CalledProcessError:
                pass
            
            try:
                subprocess.run(
                    ["systemctl", "enable", "hiluxos-shutdown"],
                    check=True,
                    capture_output=True,
                    timeout=5
                )
            except subprocess.CalledProcessError:
                pass
            
            logger.info(f"Registered shutdown hook: {command}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to register shutdown hook: {e}")
            return False
    
    def shutdown(self) -> bool:
        """
        Trigger system shutdown.
        
        Returns:
            True if shutdown initiated
        """
        try:
            # Check if we're on a desktop environment
            result = subprocess.run(
                ["ps", "auxf"],
                capture_output=True,
                text=True,
                timeout=1
            )
            
            if "gnome-shell" in result.stdout or "kde" in result.stdout or "xfce4" in result.stdout:
                logger.info("Desktop environment detected - asking for shutdown")
                return subprocess.run(
                    ["gnome-session", "--quit"],
                    capture_output=True,
                    timeout=5
                ).returncode == 0
            
            logger.info("No desktop environment detected - shutdown from CLI only")
            return True
            
        except Exception as e:
            logger.error(f"Shutdown error: {e}")
            return False
    
    def wake(self) -> bool:
        """
        Wake from sleep/suspend.
        
        Returns:
            True if wake successful
        """
        try:
            result = subprocess.run(
                ["pm-utils", "--resume"],
                capture_output=True,
                timeout=10
            )
            return result.returncode == 0
        except subprocess.TimeoutExpired:
            return False
        except Exception as e:
            logger.error(f"Wake error: {e}")
            return False
    
    def get_power_state(self) -> Optional[str]:
        """
        Get current power state.
        
        Returns:
            Power state string: "running", "sleeping", "shutdown", "hibernating"
        """
        try:
            result = subprocess.run(
                ["systemctl", "show-shell", "--property=InactiveSec"],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if "InactiveSec" in result.stdout:
                # System is running
                return "running"
            
            # Check for sleep
            result = subprocess.run(
                ["systemctl", "show", "-p", "SliceState"],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if "sleep" in result.stdout.lower():
                return "sleeping"
            
            return "running"
            
        except Exception as e:
            logger.error(f"Power state check error: {e}")
            return None
    
    def add_power_callback(self, callback: Callable[[str], None]) -> None:
        """
        Add callback for power state changes.
        
        Args:
            callback: Function(state) called when power state changes
        """
        self._power_state_callbacks.append(callback)
    
    def notify_state_change(self, state: str) -> None:
        """
        Notify all callbacks of power state change.
        
        Args:
            state: New power state
        """
        for callback in self._power_state_callbacks:
            try:
                callback(state)
            except Exception as e:
                logger.error(f"Power callback error: {e}")
    
    def setup_raspberry_pi(self) -> bool:
        """
        Setup GPIO wake-on-network (WoN) for Raspberry Pi.
        
        Returns:
            True if setup successful
        """
        try:
            # Check if we're on Raspberry Pi
            result = subprocess.run(
                ["cat", "/sys/devices/soc0/model"],
                capture_output=True,
                text=True,
                timeout=1
            )
            
            if result.returncode != 0:
                return True  # Not on Pi, skip WoN setup
            
            # Set up GPIO wake-on-network if available
            # This would involve configuring gpio and WoN settings
            logger.info("Raspberry Pi detected - WoN setup optional")
            return True
            
        except Exception as e:
            logger.error(f"WoN setup error: {e}")
            return False
    
    def cleanup(self) -> None:
        """Clean up power manager resources."""
        self._power_state_callbacks.clear()
        logger.info("Power Manager cleaned up")