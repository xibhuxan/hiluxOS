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

---

# Documentation

Every architectural decision should be documented.

The project should remain understandable without external explanations.

---

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

# Philosophy

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
