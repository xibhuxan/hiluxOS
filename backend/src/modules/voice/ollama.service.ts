import { Injectable, Logger } from '@nestjs/common';

/** Ollama tool definition (OpenAI-compatible function-calling schema). */
export interface OllamaTool {
  type: 'function';
  function: {
    name: string;
    description: string;
    parameters: {
      type: 'object';
      properties: Record<string, unknown>;
      required?: string[];
    };
  };
}

/** A chat message in the Ollama /api/chat format. */
export interface OllamaMessage {
  role: 'system' | 'user' | 'assistant' | 'tool';
  content: string;
  tool_calls?: OllamaToolCall[];
  /** Present on tool-result messages. */
  tool_name?: string;
}

/** A single tool invocation requested by the model. */
export interface OllamaToolCall {
  function: {
    name: string;
    arguments: Record<string, unknown>;
  };
}

/** The relevant slice of Ollama's /api/chat response. */
interface OllamaChatResponse {
  message?: {
    role?: string;
    content?: string;
    tool_calls?: OllamaToolCall[];
  };
  error?: string;
}

/**
 * Thin client for a local Ollama server (https://ollama.com) that adds
 * function/tool calling on top of plain chat.
 *
 * The assistant uses this as its *reasoning brain*: when the deterministic
 * regex parser doesn't recognise an utterance, the text goes to the model
 * together with the catalogue of tools (radio, volume, weather, tasks,
 * vehicle, …). The model either answers directly (chat) or asks to call one
 * or more tools, which the orchestrator executes against the real modules.
 *
 * Everything is local/offline — the model runs on the same machine (or the
 * Pi) via `ollama serve`. If Ollama is unreachable or no model is pulled,
 * `isAvailable()` returns false and the assistant degrades to the regex-only
 * behaviour with a spoken apology for free-form questions.
 *
 * Configuration (env):
 *   OLLAMA_URL    default http://localhost:11434
 *   OLLAMA_MODEL  default qwen3.5:4b (good Spanish + tool-calling, fits a Pi 5)
 */
@Injectable()
export class OllamaService {
  private readonly logger = new Logger(OllamaService.name);
  private readonly baseUrl = (process.env.OLLAMA_URL ?? 'http://localhost:11434').replace(/\/$/, '');
  readonly model = process.env.OLLAMA_MODEL ?? 'qwen3.5:4b';
  /** Cached availability so we don't hammer the server on every turn. */
  private available: boolean | null = null;
  private lastCheck = 0;
  private static readonly CHECK_TTL_MS = 30_000;

  /** Whether the Ollama server is reachable and has the configured model. */
  async isAvailable(): Promise<boolean> {
    const now = Date.now();
    if (this.available !== null && now - this.lastCheck < OllamaService.CHECK_TTL_MS) {
      return this.available;
    }
    this.lastCheck = now;
    try {
      const res = await fetch(`${this.baseUrl}/api/tags`, { signal: AbortSignal.timeout(3000) });
      if (!res.ok) {
        this.available = false;
        return false;
      }
      const data = (await res.json()) as { models?: { name: string }[] };
      const names = (data.models ?? []).map((m) => m.name);
      // Accept an exact match or the same model with an implicit :latest tag.
      this.available = names.some(
        (n) => n === this.model || n === `${this.model}:latest` || n.split(':')[0] === this.model.split(':')[0],
      );
      if (!this.available) {
        this.logger.warn(`Ollama up but model '${this.model}' not pulled (have: ${names.join(', ') || 'none'})`);
      }
    } catch {
      this.available = false;
    }
    return this.available;
  }

  /**
   * One chat round-trip. `messages` carries the running conversation (system
   * prompt + history + latest user turn + any tool results). When `tools` are
   * provided the model may respond with `tool_calls` instead of text.
   *
   * Returns the assistant message (content and/or tool_calls). Throws on
   * transport/HTTP error — the caller turns that into a spoken apology.
   */
  async chat(messages: OllamaMessage[], tools?: OllamaTool[]): Promise<OllamaMessage> {
    const res = await fetch(`${this.baseUrl}/api/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      // A small local model can take a while to reason + emit tool calls,
      // especially with the full tool catalogue, so allow a generous window.
      signal: AbortSignal.timeout(120_000),
      body: JSON.stringify({
        model: this.model,
        messages,
        ...(tools && tools.length > 0 ? { tools } : {}),
        stream: false,
        // Keep the context small & fast on the Pi; the assistant only needs a
        // short conversation + tool results, not a huge window. Low temperature
        // keeps tool selection deterministic.
        options: { num_ctx: 2048, temperature: 0.2 },
      }),
    });
    if (!res.ok) {
      const body = await res.text().catch(() => '');
      throw new Error(`Ollama HTTP ${res.status}: ${body.slice(0, 200)}`);
    }
    const data = (await res.json()) as OllamaChatResponse;
    if (data.error) throw new Error(`Ollama error: ${data.error}`);
    const msg = data.message ?? {};
    return {
      role: 'assistant',
      content: msg.content ?? '',
      ...(msg.tool_calls && msg.tool_calls.length > 0 ? { tool_calls: msg.tool_calls } : {}),
    };
  }
}
