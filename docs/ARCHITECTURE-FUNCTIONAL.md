# hiluxOS — Arquitectura Funcional

Fuente de verdad del nivel funcional y de producto. Para la arquitectura
técnica (stack, estructura de carpetas, Prisma, Docker, scripts), ver
[`../ARCHITECTURE.md`](../ARCHITECTURE.md).

---

## ¿Qué es hiluxOS?

hiluxOS no es una aplicación para un coche.

hiluxOS es un **sistema operativo** diseñado para controlar y monitorizar un
**Toyota Hilux LN165 MK4 Doble Cabina (1999, motor 2L-T)**, ejecutándose sobre
una **Raspberry Pi 5**.

Toda la lógica del sistema residirá en el backend (NestJS). Flutter será
exclusivamente la interfaz gráfica.

El sistema debe diseñarse para que cualquier funcionalidad pueda utilizarse desde:

- La pantalla del vehículo.
- Una futura aplicación móvil.
- Una futura aplicación web.
- Una futura API pública.

La interfaz nunca deberá contener lógica de negocio.

---

# Filosofía del proyecto

Todo el sistema debe construirse siguiendo estos principios.

## Backend First

Toda la lógica pertenece al backend.

Flutter únicamente representa información y envía acciones.

Nunca debe contener lógica de negocio.

---

## Mock First

Durante el desarrollo no existirá hardware.

TODO debe funcionar mediante simulaciones.

Cuando exista hardware únicamente se sustituye la implementación simulada por la
implementación real.

La interfaz nunca deberá saber si está trabajando contra un mock o contra hardware
real.

---

## Hardware Abstraction

Nunca acceder directamente a GPIO desde la lógica del sistema.

Toda interacción con hardware deberá hacerse mediante interfaces o servicios.

Ejemplo:

```
VehicleLightingService
        ↓
MockVehicleLightingService
GPIOVehicleLightingService
ESP32VehicleLightingService
CANBusVehicleLightingService
```

La aplicación nunca conocerá qué implementación está utilizando.

---

## API Driven

Toda acción deberá existir como operación de la API.

Si una acción puede ejecutarse desde la pantalla también deberá poder ejecutarse
desde una futura aplicación móvil.

---

# Arquitectura

```
Flutter
   ↓
NestJS
   ↓
Servicios
   ↓
Drivers de Hardware (Mock / GPIO / ESP32 / CAN / OBD...)
```

---

# Tipos de interfaz

Toda funcionalidad deberá pertenecer a uno de estos tipos.

## 1. Aplicación

Ocupa toda la pantalla.

El usuario entra y permanece un tiempo interactuando.

Ejemplos:

- Home
- Radio
- Mapas
- Agenda
- Ajustes
- Sistema
- Multimedia
- OBD

---

## 2. Home

La pantalla principal.

Siempre tendrá **exactamente cuatro tarjetas**.

Nunca deberá convertirse en un dashboard infinito.

Las tarjetas podrán evolucionar, pero la estructura será permanente.

### Estado Actual

Responde: **¿Qué está ocurriendo ahora?**

Ejemplos:

- Reproduciendo radio.
- Bluetooth conectado.
- Actualizando sistema.
- Todo correcto.

Solo existe un estado principal.

---

### Sistema

Responde: **¿Cómo está funcionando hiluxOS?**

Contenido:

- CPU
- RAM
- Disco
- Temperatura
- Tiempo activo

Nunca contendrá acciones. Solo monitorización.

---

### Vehículo

Responde: **¿Cómo está el coche?**

Inicialmente:

- No conectado.

En el futuro:

- Voltaje
- RPM
- Velocidad
- Temperaturas
- Sensores
- Estado general

---

### Agenda

Responde: **¿Qué tengo pendiente?**

Ejemplos:

- ITV
- Cambio aceite
- Seguro
- Revisiones
- Actualizaciones
- Backups

---

## 3. Quick Panel

No es una aplicación.

No cambia de pantalla.

Sirve para ejecutar **acciones inmediatas**.

Ejemplos:

- Ventanillas
- Luces
- Cierre centralizado
- Brillo
- WiFi
- Bluetooth
- Reiniciar backend

> **El volumen NO pertenece al Quick Panel.**
> El volumen permanecerá siempre en la barra superior.

---

## 4. Overlay

Información temporal.

Ejemplos:

- Ajustando brillo.
- Confirmación.
- Error.
- Selector multimedia.

Nunca reemplaza una aplicación.

---

## 5. Notificaciones

Mensajes temporales.

Ejemplos:

- Actualización disponible.
- Puerta abierta.
---

# Tipos de elementos

Toda nueva funcionalidad deberá pertenecer **exactamente a uno** de estos tipos.

| Tipo             | Descripción                  |
|------------------|------------------------------|
| **APP**          | Pantalla completa.           |
| **ACTION**       | Acción inmediata.            |
| **STATUS**       | Información de solo lectura. |
| **SETTING**      | Configuración persistente.   |
| **SENSOR**       | Dato físico.                 |
| **DEVICE**       | Dispositivo conectado.       |
| **SERVICE**      | Servicio interno.            |
| **EVENT**        | Evento ocurrido.             |
| **NOTIFICATION** | Mensaje temporal.            |

---

# Niveles de desarrollo

Todo el proyecto se desarrollará por fases.

**Nunca comenzar una fase sin haber completado la anterior.**

---

# NIVEL 1 — Sistema Base

## Sistema Base

Objetivo: Construir el sistema operativo.

Tareas:

- Shell principal.
- Navegación.
- Barra superior.
- Home.
- Launcher de aplicaciones.
- Quick Panel.
- Overlay.
- Sistema de notificaciones.
- Temas.
- Sistema de configuración.
- Arquitectura de servicios.

---

## Backend

Objetivo: Crear la base de toda la lógica.

Tareas:

- NestJS.
- PostgreSQL.
- WebSocket.
- Configuración.
- Logs.
- Autenticación futura.
- Actualizaciones OTA.

---

## Monitorización

Objetivo: Conocer el estado del sistema.

Tareas:

- CPU.
- RAM.
- Disco.
- Temperatura.
- Internet.
- Estado Backend.
- Estado PostgreSQL.

Todo inicialmente simulado.

---

# NIVEL 2 — Aplicaciones

Crear todas las aplicaciones del sistema.

### Home

### Radio

- Buscar emisoras.
- Favoritos.
- Historial.
- Categorías.
- Información.

---

### Agenda

- Revisiones.
- ITV.
- Seguro.
- Cambio aceite.
- Historial.
- Recordatorios.

---

### Sistema

- Información.
- Diagnóstico.
- Logs.
- Actualizaciones.
- Reinicio.

---

### Ajustes

- Audio.
- Red.
- Bluetooth.
- Idioma.
- Pantalla.
- API.

---

### Mapas

Inicialmente mediante simulación.

- Posición.
- Navegación.
- Favoritos.
- Casa.
- Trabajo.
- Historial.

---

### Multimedia

- USB.
- Bluetooth.
- Música local.
- Podcasts.
---

# NIVEL 3 — Vehículo

Toda la lógica deberá diseñarse usando abstracciones.

Nunca depender directamente del hardware.

---

### Iluminación

- Posición.
- Cortas.
- Largas.
- Antiniebla.
- Auxiliares.

---

### Intermitentes

- Izquierdo.
- Derecho.
- Warning.

---

### Ventanillas

Cada ventanilla será independiente.

Acciones:

- Subir.
- Bajar.
- Estado.

---

### Puertas

- Apertura.
- Cierre.
- Estado.

---

### Cierre centralizado

- Abrir.
- Cerrar.
- Estado.

---

### Sensores

Cada sensor será independiente.

Ejemplos:

- Puertas.
- Ventanillas.
- Temperaturas.
- Impacto.
- Ultrasonidos.
- Voltaje.

---

### Motor

- RPM.
- Velocidad.
- Temperaturas.
- Consumos.
- Kilómetros.

---

### Repostajes

- Historial.
- Consumo medio.
- Autonomía.
- Estadísticas.

---

# NIVEL 4 — Inteligencia

Todo deberá construirse sobre la API existente.

Nunca directamente sobre Flutter.

---

### Speech To Text

Control por voz.

---

### Text To Speech

Respuesta hablada.

---

### IA

Capaz de:

- Abrir aplicaciones.
- Ejecutar acciones.
- Añadir eventos.
- Gestionar agenda.
- Buscar emisoras.
- Controlar el vehículo.
- Automatizar acciones.

---

### Automatizaciones

Ejemplos:

```
Si el coche queda abierto
        ↓
Enviar notificación.
```

```
Si hay sobretemperatura
        ↓
Mostrar alerta.
```

```
Si hay actualización
        ↓
Notificar.
```

---

# Simulación

Todo el sistema deberá poder ejecutarse sin hardware.

Existirá un modo simulación.

Deberán existir simulaciones para:

- Vehículo.
- GPIO.
- GPS.
- RPM.
- Velocidad.
- Temperaturas.
- Ventanillas.
- Luces.
- Puertas.
- Sensores.
- Internet.
- OBD.

El backend será el encargado de generar todos estos datos.

Flutter nunca deberá conocer si los datos proceden de hardware real o de una
simulación.

---

# Regla principal

Antes de implementar cualquier funcionalidad deberá responderse a estas preguntas:

1. ¿Es una **APP**?
2. ¿Es una **ACTION**?
3. ¿Es un **STATUS**?
4. ¿Es un **SENSOR**?
5. ¿Es un **SETTING**?
6. ¿Es un **SERVICE**?

Solo después se decidirá dónde debe implementarse.

**La arquitectura siempre tendrá prioridad sobre la velocidad de desarrollo.**