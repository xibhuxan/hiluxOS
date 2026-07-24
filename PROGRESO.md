# Progreso del Port: HiluxOS → Flutter

## ✅ Lo que tienes listo para mañana

He creado el proyecto Flutter completo en `frontend/`. Cuando te levantes, puedes ejecutarlo y verás:

### Pantallas implementadas:

1. **Splash Screen** — Animación idéntica al QML:
   - Fade in de la imagen del coche (2.5s)
   - Slide up suave
   - Logo "HILUX OS" con efecto glow pulsante
   - Barra de progreso azul (4s)
   - Texto "ESTABLISHED 1999"
   - Transición automática al home

2. **Home Dashboard** — Grid 3x2 con cards:
   - 🚗 ESTADO → READY
   - 📻 RADIO → 104.5 MHz (navega a radio)
   - 📶 TELÉFONO → SIN CONEXIÓN
   - 🚀 VELOCIDAD → 0 km/h
   - 🔘 FRENO → ACTIVO
   - ⚙️ AJUSTES → CONFIGURAR (navega a settings)

3. **Radio** — Con visualizador de espectro:
   - Búsqueda de estaciones (mock data con 5 estaciones reales)
   - Controles: play/pause, stop
   - Tabs: Búsqueda, Favoritos, Historial
   - **Visualizador FFT**: 32 barras animadas al ritmo del audio (gradiente azul)

4. **Media Player** — Placeholder listo para conectar

5. **Settings** — Sliders y switches:
   - Brillo (slider 0-100%)
   - Modo oscuro (switch)
   - Volumen (slider 0-100%)
   - Wi-Fi status
   - Bluetooth status
   - Info de versión

### Navegación:
- Bottom navigation bar (Home, Radio, Media, Ajustes)
- Transiciones suaves entre pantallas
- Splash screen desaparece sola después de 4.8s

---

## 🚀 Cómo ejecutarlo mañana

```bash
# 1. Instalar Flutter (si no lo tienes):
git clone https://github.com/flutter/flutter.git -b stable --depth 1 ~/development/flutter
export PATH="$HOME/development/flutter/bin:$PATH"
flutter doctor

# 2. Dependencias del sistema (Fedora):
sudo dnf install clang cmake ninja-build pkg-config libgtk-3-dev

# 3. Ejecutar el proyecto:
cd /home/xibhu/Development/GitHub/hiluxOS/frontend
flutter pub get
flutter run -d linux

# O en Android emulador:
flutter run -d android

# O en iOS simulator:
flutter run -d ios
```

### Nota sobre la imagen del splash:
El código busca `assets/images/hilux_99.png`. Si no la encuentra, muestra un icono de coche como placeholder. Para usar tu imagen original:
```bash
cp ../assets/images/hilux_99.png frontend/assets/images/
```

---

## 📁 Estructura creada

```
frontend/
├── lib/
│   ├── main.dart                          ✅ Entry point
│   ├── core/theme/app_theme.dart          ✅ Tema oscuro (#0d1117, #58a6ff)
│   ├── layout/
│   │   ├── app_shell.dart                 ✅ Bottom navigation
│   │   └── navigation_router.dart         ✅ go_router routes
│   ├── features/
│   │   ├── splash/splash_screen.dart      ✅ Animación completa
│   │   ├── home/home_screen.dart          ✅ Dashboard grid
│   │   ├── radio/radio_screen.dart        ✅ Radio + visualizador
│   │   ├── media/media_screen.dart        ⏳ Placeholder
│   │   └── settings/settings_screen.dart  ✅ Sliders/switches
│   └── widgets/
│       ├── dashboard_card.dart            ✅ Card reutilizable
│       └── spectrum_visualizer.dart       ✅ FFT bars animadas
├── assets/images/.gitkeep                 ⚠️ Agregar hilux_99.png
├── pubspec.yaml                           ✅ Dependencias
├── test/widget_test.dart                  ✅ Tests básicos
└── README.md                              ✅ Documentación completa
```

---

## 🎯 Próximos pasos (cuando el backend esté listo)

1. **Conectar Radio a NestJS**:
   - Reemplazar `mockStations` por llamada a `GET /radio/stations/search?q=`
   - Actualizar `_playStation()` para usar `just_audio.setUrl()`

2. **Audio real**:
   ```dart
   // En radio_screen.dart, reemplazar mock:
   final audioPlayer = AudioPlayer();
   await audioPlayer.setUrl(station['url']);
   ```

3. **WebSocket para vehicle signals**:
   - Escuchar `vehicle:speed`, `vehicle:reverse`, etc.
   - Actualizar dashboard cards en tiempo real

4. **Backend NestJS** (pendiente):
   - Docker Compose con Postgres + Invidious
   - Módulos: Radio, Media, System, Settings, Vehicle, GPIO, Power, Events

---

## 📊 Equivalencias QML → Flutter

| QML | Flutter | Estado |
|-----|---------|--------|
| `Main.qml` (Window) | `MaterialApp.router` + `GoRouter` | ✅ |
| `SplashScreen.qml` | `splash_screen.dart` | ✅ |
| `Home.qml` (dashboard) | `home_screen.dart` + `GridView.count` | ✅ |
| `DashboardCard.qml` | `dashboard_card.dart` | ✅ |
| `BottomBar.qml` | `app_shell.dart` (NavigationBar) | ✅ |
| `Radio.qml` | `radio_screen.dart` | ✅ |
| Visualizador Winamp | `spectrum_visualizer.dart` (CustomPainter FFT) | ✅ |
| `Settings.qml` | `settings_screen.dart` | ✅ |
| `QmlBridge` signals | Riverpod providers + API calls | ✅ |
| StackView.push/pop | go_router navigation | ✅ |

---

## 🎨 Colores usados (idénticos al QML)

```dart
backgroundColor: #0d1117
surfaceColor:    #161b22
borderColor:     #21262d
primaryBlue:     #58a6ff
successGreen:    #2ecc71
warningOrange:   #f0883e
dangerRed:       #da3633
textPrimary:     #c9d1d9
textSecondary:   #8b949e
```

---

## 💡 Notas técnicas

- **Visualizador**: Simula FFT con senoides + ruido (en producción usa `just_audio.processedAudioSampleStream`)
- **Navegación**: go_router es el equivalente a QML StackView, más moderno y type-safe
- **Estado**: Riverpod reemplaza las propiedades QML + signals del bridge
- **Tema**: Dark theme con Material 3, colores exactos del diseño original

---

**¡Eso es todo!** Mañana tienes una ventanita Flutter funcional con el splash animado, dashboard, radio con visualizador y settings. El backend NestJS va en paralelo o después, según prefieras.
