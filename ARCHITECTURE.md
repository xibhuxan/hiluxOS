# Project Architecture

## Goal

This project is designed to be developed primarily by AI agents with human supervision.

The architecture must prioritize:

- Simplicity.
- Reproducibility.
- Fast local development.
- Easy deployment.
- Minimal moving parts.
- Predictable project structure.

Every architectural decision should favor maintainability over cleverness.

> La **filosofía funcional** del proyecto (Backend First, Mock First, Hardware
> Abstraction, API Driven, tipos de interfaz, tipos de elementos, niveles de
> desarrollo y simulación) se define en
> [`docs/ARCHITECTURE-FUNCTIONAL.md`](./docs/ARCHITECTURE-FUNCTIONAL.md), fuente
> de verdad del nivel funcional y de producto. Este documento describe
> únicamente la arquitectura **técnica**.

---

# Technology Stack

## Frontend

- Flutter
- Linux Desktop during development.
- Raspberry Pi Linux Desktop in production.

The frontend must follow a feature-first architecture.

Business logic must never be mixed with UI.

---

## Backend

- Node.js
- NestJS
- Prisma ORM

The backend is responsible for:

- Business logic
- REST API
- Raspberry Pi hardware interaction
- Media control
- Configuration
- Updates
- Database access

Flutter must never access the operating system directly.

---

## Database

Database engine:

- PostgreSQL

PostgreSQL must always run inside Docker.

The backend connects using environment variables.

No other service should communicate directly with PostgreSQL.

---

# Docker

Docker is only used for infrastructure services.

Allowed examples:

- PostgreSQL
- Redis
- MinIO
- Adminer

Application code must not run inside Docker during development unless explicitly requested.

Flutter must run directly on the host.

NestJS must run directly on the host.

---

# Raspberry Pi

The Raspberry Pi is the production target.

Development always happens on Fedora.

Deployment must be automated.

---

# Project Structure

The repository must be organized using clear separation of concerns.

Expected top-level directories include:

- app
- backend
- docker
- scripts
- docs

Avoid unnecessary nesting.

---

# Modular Architecture

All of hiluxOS is divided into fully independent modules.

A module represents a single capability of the system and must be able to
evolve without affecting the rest of the project.

No module may access the internal implementation of another module.

Communication between modules is always done through services, interfaces or
the API.

> The functional rationale (Backend First, Mock First, Hardware Abstraction,
> API Driven) is defined in
> [`docs/ARCHITECTURE-FUNCTIONAL.md`](./docs/ARCHITECTURE-FUNCTIONAL.md). This
> section defines the **technical rules** that enforce it.

---

## Objectives

Modular architecture allows:

- Keeping the code organized.
- Replacing implementations without modifying other modules.
- Easier development by AI agents.
- Fewer dependencies.
- Several people or agents working in parallel.

---

## Rules

A module:

- Has a single responsibility.
- May contain frontend and backend.
- May have its own database if needed.
- Never knows internal details of other modules.
- Uses only public interfaces.

---

## Examples

Incorrect: Radio accesses Agenda's database directly.

Correct: Radio requests the information through Agenda's public service.

Incorrect: Flutter accesses GPIO directly.

Correct:

```
Flutter
   ↓
API
   ↓
Vehicle Service
   ↓
Hardware Interface
   ↓
GPIO / ESP32 / Mock
```

---

## Independence

Each module must be able to be developed, tested and evolved independently.

If a module disappears, the rest of the system must keep working.

Example: if the Radio module ceases to exist:

- Home keeps working.
- Agenda keeps working.
- System keeps working.
- Vehicle keeps working.

---

## Communication

Modules may only communicate through:

- Public services.
- Interfaces.
- Events.
- WebSocket.
- API.

Never through direct access to internal classes.

---

## Module examples

System

- Monitoring
- Updates
- Logs
- Configuration

Vehicle

- Lights
- Windows
- Doors
- Central locking
- Sensors
- Engine

Multimedia

- Radio
- Bluetooth
- USB
- Podcasts

Agenda

- Revisions
- MOT (ITV)
- Insurance
- Reminders

Maps

- GPS
- Navigation
- Favorites

AI

- Speech to Text
- Text to Speech
- Automations
- Assistant

---

## Dependencies

Dependencies must always point downwards.

```
Flutter
   ↓
API
   ↓
Services
   ↓
Drivers
   ↓
Hardware
```

Never the other way around.

- Hardware never knows Flutter.
- The backend never knows the interface.
- Drivers never know the applications.

---

## Implementation substitution

Every implementation must be replaceable without modifying the rest of the
system.

Example:

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

For the rest of the system they are all exactly the same service.

---

## Golden Rule

If implementing a new feature requires modifying several unrelated modules, the
architecture is probably wrong.

The solution must be found by creating new interfaces or new services, never by
increasing coupling between modules.

---

# Flutter Architecture

Use Feature First.

Example:

lib/

core/

shared/

features/

Each feature owns:

- UI
- State
- Models
- Services

Shared code belongs only in shared/.

---

# NestJS Architecture

Organize code by modules.

Each module owns:

- Controllers
- Services
- DTOs
- Entities
- Tests

Avoid giant utility folders.

Avoid monolithic services.

---

# Database Access

Only Prisma may access PostgreSQL.

Do not use raw SQL unless performance requires it.

---

# Configuration

All configuration must come from environment variables.

Never hardcode:

- ports
- passwords
- hosts
- URLs
- secrets

Provide .env.example.

---

# Scripts

The project must provide scripts that automate repetitive tasks.

Typical responsibilities include:

- Environment setup
- Dependency installation
- Development startup
- Testing
- Deployment
- Environment validation

Agents should create or update these scripts whenever the workflow changes.

# AI Development Rules

When creating new code:

- Follow the existing architecture.
- Do not introduce new frameworks without justification.
- Prefer consistency over novelty.
- Keep dependencies to a minimum.
- Avoid unnecessary abstractions.
- Generate reusable scripts instead of manual instructions.
- Automate repetitive tasks whenever possible.
- Prefer convention over configuration.

If a workflow requires multiple manual commands, create a script instead.

---

# Deployment

Deployment must be reproducible.

The deployment process should require a single command whenever possible.

---

# Repository Philosophy

> The functional and product philosophy is defined in
> [`docs/ARCHITECTURE-FUNCTIONAL.md`](./docs/ARCHITECTURE-FUNCTIONAL.md). This
> section only covers repository-level principles.

Every architectural decision should be documented.

The repository should be self-contained.

A developer (or AI agent) cloning the repository should be able to understand:

- the architecture
- the workflow
- the deployment process

without needing additional documentation.

Whenever possible, improve automation instead of increasing documentation.

# Versions

Node 22 LTS
Flutter Stable
PostgreSQL 17
NestJS latest Stable
Prisma latest Stable
Docker Engine latest Stable
Docker Compose v2
