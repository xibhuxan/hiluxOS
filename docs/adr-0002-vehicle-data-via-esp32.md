# ADR-0002: Vehicle Data via a Parallel ESP32/Arduino Node

Date: 2026-09-01
Status: Accepted

## Context

hiluxOS planned to read vehicle data from the car's OBD-II port. After testing
the actual vehicle, **it has no OBD-II port available**. The Fase 3 HAL
(`docs/STATUS.md`) — `Vehicle`/`Power`/`GPIO` modules with mock-first
implementations — still needs a real hardware backend to target.

## Decision

Drop the OBD-II driver from the hardware roadmap. Vehicle data will come from
a **parallel controller ("centralita paralela") based on ESP32/Arduino**, wired
by the owner to the sensors and actuators it makes sense to control, and
talking to the Raspberry Pi over **WiFi or serial**.

The backend driver for the Fase 3 HAL is therefore `ESP32VehicleService`
(already anticipated by the substitution chain in `ARCHITECTURE.md`:

```
VehicleLightingService
        ↓
MockVehicleLightingService
        ↓
GPIOVehicleLightingService
        ↓
ESP32VehicleLightingService
        ↓
CANBusVehicleLightingService
```

).

## Consequences

- The Fase 3 HAL is unchanged in shape: interface + mock implementation
  (env-toggled), then a real `ESP32*` implementation substituting the mock.
- The protocol between the ESP32 and the backend is to be defined when the
  hardware exists (candidates: plain JSON lines over TCP/serial, or MQTT).
  `ARCHITECTURE-FUNCTIONAL.md` simulation requirements (RPM, speed,
  temperatures, windows, lights, doors, sensors) apply to the mock as usual —
  Flutter never knows whether data is real or simulated.
- `OBD-II` is removed from the drivers list in `ARCHITECTURE-FUNCTIONAL.md` and
  the drawer app tile `/obd` is superseded by a future `/vehicle` tile backed
  by the HAL.
- No work is blocked: the mock-first HAL can be built and shipped before the
  ESP32 hardware is finalized.

## Out of scope

The ESP32 firmware itself, its wiring to the car, and the transport protocol
details. These are decided when the hardware is in hand.
