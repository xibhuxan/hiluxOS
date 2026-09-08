import { Injectable, Logger } from '@nestjs/common';
import { OllamaTool } from './ollama.service';
import { EventsGateway } from '../events/events.gateway';
import { RadioService, StationDto } from '../radio/radio.service';
import { SystemService } from '../system/system.service';
import { BtMediaService } from '../btmedia/btmedia.service';
import { WeatherService } from '../weather/weather.service';
import { TasksService } from '../tasks/tasks.service';
import { VehicleService } from '../vehicle/vehicle.service';

/** The outcome of running one tool: a short, speakable result string. */
export interface ToolResult {
  /** Short Spanish summary the LLM turns into the spoken reply. */
  text: string;
  /** Optional UI action the app should run (open a screen, play a station). */
  action?: { type: string; stations?: StationDto[] };
}

/**
 * The assistant's hands: the catalogue of tools exposed to the LLM, each one
 * backed by a real hiluxOS module. This is what makes the assistant *actually
 * do things* (radio, volume, weather, Bluetooth media, reminders/tasks,
 * vehicle, system, navigation) instead of just talking about them.
 *
 * Each tool is a thin, defensive wrapper: it calls the domain service and
 * returns a short Spanish result string. Failures are caught and turned into
 * a spoken-friendly apology so one broken module never crashes the assistant.
 */
@Injectable()
export class AssistantToolsService {
  private readonly logger = new Logger(AssistantToolsService.name);

  constructor(
    private readonly events: EventsGateway,
    private readonly radio: RadioService,
    private readonly system: SystemService,
    private readonly btmedia: BtMediaService,
    private readonly weather: WeatherService,
    private readonly tasks: TasksService,
    private readonly vehicle: VehicleService,
  ) {}

  /** The tool catalogue advertised to the model (Ollama function-calling). */
  readonly tools: OllamaTool[] = [
    {
      type: 'function',
      function: {
        name: 'radio_play',
        description:
          'Sintoniza/reproduce una emisora de radio por internet. Si no se da nombre, reanuda la última o la primera favorita.',
        parameters: {
          type: 'object',
          properties: { station: { type: 'string', description: 'Nombre de la emisora (opcional).' } },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'radio_stop',
        description: 'Detiene la reproducción de la radio.',
        parameters: { type: 'object', properties: {} },
      },
    },
    {
      type: 'function',
      function: {
        name: 'radio_list',
        description: 'Lista las emisoras de radio favoritas del usuario.',
        parameters: { type: 'object', properties: {} },
      },
    },
    {
      type: 'function',
      function: {
        name: 'set_volume',
        description:
          'Ajusta el volumen del sistema. action "set" fija un nivel (0-100), "up"/"down" lo sube/baja, "mute" silencia o quita el silencio.',
        parameters: {
          type: 'object',
          properties: {
            action: { type: 'string', enum: ['set', 'up', 'down', 'mute'] },
            level: { type: 'number', description: 'Nivel 0-100 (solo para action "set").' },
          },
          required: ['action'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'get_weather',
        description: 'Tiempo actual en una ciudad (o la ubicación guardada si no se indica).',
        parameters: { type: 'object', properties: { city: { type: 'string', description: 'Ciudad (opcional).' } } },
      },
    },
    {
      type: 'function',
      function: {
        name: 'get_forecast',
        description: 'Previsión del tiempo para hoy/próximos días en una ciudad.',
        parameters: { type: 'object', properties: { city: { type: 'string', description: 'Ciudad (opcional).' } } },
      },
    },
    {
      type: 'function',
      function: {
        name: 'media_control',
        description: 'Controla la música Bluetooth del teléfono: play, pause, next, previous, stop.',
        parameters: {
          type: 'object',
          properties: { action: { type: 'string', enum: ['play', 'pause', 'next', 'previous', 'stop'] } },
          required: ['action'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'add_task',
        description: 'Añade un recordatorio o tarea pendiente (p. ej. "cambiar aceite", "pasar la ITV").',
        parameters: {
          type: 'object',
          properties: { title: { type: 'string', description: 'Texto del recordatorio.' } },
          required: ['title'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'list_tasks',
        description: 'Lista los recordatorios/tareas pendientes.',
        parameters: { type: 'object', properties: {} },
      },
    },
    {
      type: 'function',
      function: {
        name: 'vehicle_status',
        description: 'Estado del vehículo: motor, velocidad, combustible, batería, luces, puertas, ventanillas.',
        parameters: { type: 'object', properties: {} },
      },
    },
    {
      type: 'function',
      function: {
        name: 'vehicle_lights',
        description: 'Enciende o apaga una luz del vehículo (position/low/high/fog/auxiliary).',
        parameters: {
          type: 'object',
          properties: {
            light: { type: 'string', enum: ['position', 'low', 'high', 'fog', 'auxiliary'] },
            on: { type: 'boolean' },
          },
          required: ['light', 'on'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'vehicle_window',
        description: 'Sube, baja o para una ventanilla. ids: 0=del.izq,1=del.der,2=tras.izq,3=tras.der.',
        parameters: {
          type: 'object',
          properties: {
            id: { type: 'number', enum: [0, 1, 2, 3] },
            action: { type: 'string', enum: ['up', 'down', 'stop'] },
          },
          required: ['id', 'action'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'vehicle_door',
        description: 'Abre o cierra una puerta. ids: 0=del.izq,1=del.der,2=tras.izq,3=tras.der.',
        parameters: {
          type: 'object',
          properties: {
            id: { type: 'number', enum: [0, 1, 2, 3] },
            open: { type: 'boolean' },
          },
          required: ['id', 'open'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'vehicle_lock',
        description: 'Bloquea o desbloquea el cierre centralizado.',
        parameters: {
          type: 'object',
          properties: { locked: { type: 'boolean' } },
          required: ['locked'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'system_status',
        description: 'Estado del sistema: memoria, carga de CPU y temperatura.',
        parameters: { type: 'object', properties: {} },
      },
    },
    {
      type: 'function',
      function: {
        name: 'open_screen',
        description: 'Abre una pantalla de la app: radio, media, maps/nav, vehicle, tasks, system, settings, equalizer.',
        parameters: {
          type: 'object',
          properties: { screen: { type: 'string', description: 'Nombre de la pantalla.' } },
          required: ['screen'],
        },
      },
    },
  ];

  /** Execute a tool call requested by the model. Never throws. */
  async run(name: string, args: Record<string, unknown>): Promise<ToolResult> {
    try {
      switch (name) {
        case 'radio_play':
          return await this.radioPlay(args.station as string | undefined);
        case 'radio_stop':
          return this.radioStop();
        case 'radio_list':
          return await this.radioList();
        case 'set_volume':
          return this.setVolume(args.action as string, args.level as number | undefined);
        case 'get_weather':
          return await this.getWeather(args.city as string | undefined);
        case 'get_forecast':
          return await this.getForecast(args.city as string | undefined);
        case 'media_control':
          return this.mediaControl(args.action as string);
        case 'add_task':
          return await this.addTask(args.title as string);
        case 'list_tasks':
          return await this.listTasks();
        case 'vehicle_status':
          return this.vehicleStatus();
        case 'vehicle_lights':
          return this.vehicleLights(args.light as string, args.on as boolean);
        case 'vehicle_window':
          return this.vehicleWindow(args.id as number, args.action as 'up' | 'down' | 'stop');
        case 'vehicle_door':
          return this.vehicleDoor(args.id as number, args.open as boolean);
        case 'vehicle_lock':
          return this.vehicleLock(args.locked as boolean);
        case 'system_status':
          return this.systemStatus();
        case 'open_screen':
          return this.openScreen(args.screen as string);
        default:
          return { text: `No conozco la herramienta ${name}.` };
      }
    } catch (err) {
      this.logger.warn(`Tool ${name} failed: ${(err as Error).message}`);
      return { text: `No he podido ejecutar ${name} ahora mismo.` };
    }
  }

  // ---- radio ----

  private async radioPlay(station?: string): Promise<ToolResult> {
    if (station) {
      const needle = station.toLowerCase();
      const favs = (await this.radio.listFavorites()) ?? [];
      const exact = favs.find((s) => s.name.toLowerCase() === needle);
      const partial = favs.filter((s) => s.name.toLowerCase().includes(needle));
      const favMatch = exact ?? (partial.length === 1 ? partial[0] : undefined);
      if (favMatch) {
        this.playStation(favMatch);
        return { text: `Sintonizando ${favMatch.name}.`, action: { type: 'open_radio' } };
      }
      if (partial.length > 1) {
        return {
          text: `Tengo varias que coinciden: ${partial.slice(0, 5).map((s) => s.name).join(', ')}. ¿Cuál?`,
          action: { type: 'choose_station', stations: partial },
        };
      }
      let results: StationDto[] = [];
      try {
        results = await this.radio.search(station);
      } catch {
        return { text: 'No puedo buscar emisoras ahora mismo; no hay conexión.' };
      }
      if (results.length === 0) return { text: `No he encontrado la emisora ${station}.` };
      if (results.length === 1) {
        this.playStation(results[0]);
        return { text: `Sintonizando ${results[0].name}.`, action: { type: 'open_radio' } };
      }
      return {
        text: `He encontrado varias: ${results.slice(0, 5).map((s) => s.name).join(', ')}. ¿Cuál?`,
        action: { type: 'choose_station', stations: results.slice(0, 5) },
      };
    }
    const history = (await this.radio.listHistory()) ?? [];
    const favs = (await this.radio.listFavorites()) ?? [];
    const target = history[0] ?? favs[0];
    if (!target) return { text: 'No tienes emisoras guardadas todavía.' };
    this.playStation(target);
    return { text: `Sintonizando ${target.name}.`, action: { type: 'open_radio' } };
  }

  private radioStop(): ToolResult {
    this.events.broadcast('voice_action', { type: 'radio_stop' });
    return { text: 'Radio detenida.' };
  }

  private async radioList(): Promise<ToolResult> {
    const favs = (await this.radio.listFavorites()) ?? [];
    if (favs.length === 0) return { text: 'No tienes emisoras favoritas todavía.' };
    const names = favs.slice(0, 6).map((s) => s.name).join(', ');
    return {
      text: `Tus emisoras favoritas son: ${names}.`,
      action: { type: 'choose_station', stations: favs.slice(0, 6) },
    };
  }

  private playStation(station: StationDto): void {
    this.events.broadcast('voice_action', { type: 'radio_play', station });
    this.radio.recordHistory(station).catch(() => undefined);
  }

  // ---- volume ----

  private setVolume(action: string, level?: number): ToolResult {
    const current = this.system.getAudio();
    const curVol = current.volume ?? 50;
    switch (action) {
      case 'set': {
        const lvl = Math.max(0, Math.min(100, Math.round(level ?? curVol)));
        this.system.setAudioVolume(lvl);
        return { text: `Volumen al ${lvl} por ciento.` };
      }
      case 'up': {
        const lvl = Math.min(100, curVol + 10);
        this.system.setAudioVolume(lvl);
        return { text: `Volumen al ${lvl} por ciento.` };
      }
      case 'down': {
        const lvl = Math.max(0, curVol - 10);
        this.system.setAudioVolume(lvl);
        return { text: `Volumen al ${lvl} por ciento.` };
      }
      case 'mute': {
        const muted = !(current.muted ?? false);
        this.system.setAudioMuted(muted);
        return { text: muted ? 'Silenciado.' : 'Sonido activado.' };
      }
      default:
        return { text: '¿Qué hago con el volumen?' };
    }
  }

  // ---- weather ----

  private async getWeather(city?: string): Promise<ToolResult> {
    const w = await this.weather.getCurrent(undefined, undefined, city);
    return {
      text:
        `En ${w.location.name} hace ${Math.round(w.temperature)} grados, ` +
        `${w.description.toLowerCase()}, sensación de ${Math.round(w.apparentTemperature)} ` +
        `y viento de ${Math.round(w.windSpeed)} kilómetros por hora.`,
    };
  }

  private async getForecast(city?: string): Promise<ToolResult> {
    const f = await this.weather.getForecast(undefined, undefined, city);
    const today = f.daily[0];
    if (!today) return { text: 'No tengo la previsión ahora mismo.' };
    return {
      text:
        `Para hoy en ${f.location.name}: máxima de ${Math.round(today.tempMax)} ` +
        `y mínima de ${Math.round(today.tempMin)} grados, con un ` +
        `${today.precipitationProbability}% de probabilidad de lluvia.`,
    };
  }

  // ---- bluetooth media ----

  private mediaControl(action: string): ToolResult {
    switch (action) {
      case 'play':
        this.btmedia.play();
        return { text: 'Reproduciendo.' };
      case 'pause':
        this.btmedia.pause();
        return { text: 'Pausando la música.' };
      case 'next':
        this.btmedia.next();
        return { text: 'Siguiente canción.' };
      case 'previous':
        this.btmedia.previous();
        return { text: 'Canción anterior.' };
      case 'stop':
        this.btmedia.pause();
        return { text: 'Música detenida.' };
      default:
        return { text: '¿Qué hago con la música?' };
    }
  }

  // ---- tasks / reminders ----

  private async addTask(title: string): Promise<ToolResult> {
    if (!title || !title.trim()) return { text: '¿Qué quieres que te recuerde?' };
    await this.tasks.create({ title: title.trim() });
    return { text: `Anotado: ${title.trim()}.` };
  }

  private async listTasks(): Promise<ToolResult> {
    const list = (await this.tasks.findAll()) ?? [];
    if (list.length === 0) return { text: 'No tienes recordatorios pendientes.' };
    const titles = list.slice(0, 6).map((t) => t.title).join(', ');
    return { text: `Tienes ${list.length} pendientes: ${titles}.` };
  }

  // ---- vehicle ----

  private vehicleStatus(): ToolResult {
    const s = this.vehicle.getSnapshot();
    if (!s.connected) return { text: 'El vehículo no está conectado ahora mismo.' };
    const parts: string[] = [];
    if (s.engine.speedKmh != null) parts.push(`velocidad ${Math.round(s.engine.speedKmh)} kilómetros por hora`);
    if (s.engine.fuelLevel != null) parts.push(`combustible al ${Math.round(s.engine.fuelLevel)} por ciento`);
    if (s.batteryVoltage != null) parts.push(`batería a ${s.batteryVoltage.toFixed(1)} voltios`);
    if (s.engine.coolantTempC != null) parts.push(`refrigerante a ${Math.round(s.engine.coolantTempC)} grados`);
    return { text: parts.length > 0 ? `El coche: ${parts.join(', ')}.` : 'El coche está conectado.' };
  }

  private vehicleLights(light: string, on: boolean): ToolResult {
    this.vehicle.setLights({ [light]: on });
    const names: Record<string, string> = {
      position: 'de posición', low: 'cortas', high: 'largas', fog: 'antiniebla', auxiliary: 'auxiliares',
    };
    return { text: `${on ? 'Encendiendo' : 'Apagando'} las luces ${names[light] ?? light}.` };
  }

  private vehicleDoor(id: number, open: boolean): ToolResult {
    try {
      this.vehicle.setDoor(id, { open });
    } catch {
      return { text: 'No conozco esa puerta.' };
    }
    const names = ['delantera izquierda', 'delantera derecha', 'trasera izquierda', 'trasera derecha'];
    return { text: `${open ? 'Abriendo' : 'Cerrando'} la puerta ${names[id] ?? id}.` };
  }

  private vehicleWindow(id: number, action: 'up' | 'down' | 'stop'): ToolResult {
    try {
      this.vehicle.windowAction(id, action);
    } catch {
      return { text: 'No conozco esa ventanilla.' };
    }
    const names = ['delantera izquierda', 'delantera derecha', 'trasera izquierda', 'trasera derecha'];
    const verbs = { up: 'Subiendo', down: 'Bajando', stop: 'Parando' };
    return { text: `${verbs[action]} la ventanilla ${names[id] ?? id}.` };
  }

  private vehicleLock(locked: boolean): ToolResult {
    this.vehicle.setCentralLock({ locked });
    return { text: locked ? 'Coche bloqueado.' : 'Coche desbloqueado.' };
  }

  // ---- system ----

  private systemStatus(): ToolResult {
    const r = this.system.getResources();
    const temp = this.system.getTemperature();
    const parts = [
      `memoria usada al ${Math.round(r.memoryUsagePercent)} por ciento`,
      `carga del procesador ${r.loadAverage['1m'].toFixed(1)}`,
    ];
    if (temp.celsius != null) parts.push(`temperatura de ${Math.round(temp.celsius)} grados`);
    return { text: `El sistema va bien: ${parts.join(', ')}.` };
  }

  // ---- navigation / screens ----

  private openScreen(screen: string): ToolResult {
    const map: Record<string, { type: string; label: string }> = {
      radio: { type: 'open_radio', label: 'la radio' },
      media: { type: 'open_media', label: 'la música' },
      maps: { type: 'open_nav', label: 'los mapas' },
      nav: { type: 'open_nav', label: 'la navegación' },
      vehicle: { type: 'open_vehicle', label: 'el vehículo' },
      tasks: { type: 'open_tasks', label: 'los recordatorios' },
      system: { type: 'open_system', label: 'el sistema' },
      settings: { type: 'open_settings', label: 'los ajustes' },
      equalizer: { type: 'open_equalizer', label: 'el ecualizador' },
    };
    const target = map[(screen ?? '').toLowerCase()];
    if (!target) return { text: `No conozco la pantalla ${screen}.` };
    return { text: `Abriendo ${target.label}.`, action: { type: target.type } };
  }
}
