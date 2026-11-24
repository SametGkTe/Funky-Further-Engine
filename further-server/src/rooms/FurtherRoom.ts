import { Room, Client } from "colyseus";
import { RoomState } from "./schema/RoomState";
import { PlayerState } from "./schema/PlayerState";

/** Bump when client/server message contract changes incompatibly */
export const PROTOCOL = 1;

const MAX_PLAYERS = 2;
const HEALTH_HIT = 0.023;
const HEALTH_MISS = 0.0475;

type SongPayload = {
  song?: string;
  folder?: string;
  diff?: number;
  diffList?: string[];
  chartHash?: string;
};

/**
 * Further Engine 1v1 duel room.
 * - Lobby: setSong / hasSong / ready
 * - Match: strumPlay + noteHit/noteMiss relay, server health
 * - End: playerEnded gate
 */
export class FurtherRoom extends Room<RoomState> {
  maxClients = MAX_PLAYERS;
  // autoDispose Room'da accessor (get/set) olarak tanımlı; alan olarak ezmek
  // TS2610'a yol açıyordu. Room'un varsayılanı zaten true (oda boşalınca imha).

  private lastPong = new Map<string, number>();
  private msgBudget = new Map<string, { count: number; windowStart: number }>();

  /**
   * Basit istemci-başına hız sınırı: pencere başına en fazla `max` mesaj.
   * Relay/spam mesajlarının sunucuyu ve diğer istemciyi boğmasını engeller.
   */
  private allow(client: Client, bucket: string, max: number, windowMs = 1000): boolean {
    const key = `${client.sessionId}:${bucket}`;
    const now = Date.now();
    let b = this.msgBudget.get(key);
    if (!b || now - b.windowStart >= windowMs) {
      b = { count: 0, windowStart: now };
      this.msgBudget.set(key, b);
    }
    b.count++;
    return b.count <= max;
  }

  private clearBudgets(sessionId: string) {
    for (const key of this.msgBudget.keys()) {
      if (key.startsWith(sessionId + ":")) this.msgBudget.delete(key);
    }
  }

  /** Relay edilecek payload'larda yalnızca basit (JSON-güvenli) türlere izin ver. */
  private static isPrimitive(v: unknown): boolean {
    return v == null || typeof v === "string" || typeof v === "number" || typeof v === "boolean";
  }

  onCreate(_options: any) {
    this.setState(new RoomState());
    this.state.health = 1;

    // Short room codes for LAN sharing (not globally unique forever — fine for LAN MVP)
    this.roomId = this.generateCode(5);

    console.log(`[FurtherRoom] created ${this.roomId}`);

    this.onMessage("setSong", (client, message: SongPayload) => {
      if (!this.isHost(client)) {
        client.send("alert", ["No permission", "Only the host can pick the song."]);
        return;
      }
      if (this.state.isStarted) return;
      if (!this.allow(client, "setSong", 2, 3000)) return;

      this.state.song = String(message?.song ?? "");
      this.state.folder = String(message?.folder ?? "");
      this.state.diff = Number(message?.diff ?? 1);
      this.state.chartHash = String(message?.chartHash ?? "");

      this.state.diffList.clear();
      const list = Array.isArray(message?.diffList) ? message.diffList : [];
      for (const d of list) this.state.diffList.push(String(d));

      // Reset song readiness when chart changes
      this.state.players.forEach((p) => {
        p.hasSong = false;
        p.isReady = false;
        p.hasLoaded = false;
        p.hasEnded = false;
      });

      this.broadcast("log", `Host set song: ${this.state.song} [${this.state.chartHash.slice(0, 8)}…]`);
      this.broadcast("songChanged", {
        song: this.state.song,
        folder: this.state.folder,
        diff: this.state.diff,
        chartHash: this.state.chartHash,
        diffList: Array.from(this.state.diffList)
      });
      console.log(`[FurtherRoom] ${this.roomId} song=${this.state.song} hash=${this.state.chartHash}`);
    });

    this.onMessage("hasSong", (client, ok: boolean) => {
      const p = this.player(client);
      if (!p || this.state.isStarted) return;
      p.hasSong = !!ok;
      if (!ok) p.isReady = false;
      this.broadcast("log", `${p.name} hasSong=${p.hasSong}`);
    });

    const toggleReady = (client: Client) => {
      const p = this.player(client);
      if (!p || this.state.isStarted) return;
      if (!this.allow(client, "ready", 5)) return;
      if (!p.hasSong) {
        client.send("alert", ["Not ready", "Load/verify the chart first (hasSong)."]);
        return;
      }
      p.isReady = !p.isReady;
      this.broadcast("log", `${p.name} ready=${p.isReady}`);
      void this.tryStartGame();
    };

    this.onMessage("toggleReady", toggleReady);
    // alias used by some clients / Psych Online muscle memory
    this.onMessage("startGame", toggleReady);

    this.onMessage("playerReady", (client) => {
      const p = this.player(client);
      if (!p || !this.state.isStarted) return;
      if (p.hasLoaded) return;
      p.hasLoaded = true;
      this.broadcast("log", `${p.name} loaded PlayState`);

      let all = true;
      this.state.players.forEach((pl) => {
        if (!pl.hasLoaded) all = false;
      });
      if (all && this.state.players.size >= 2) {
        this.broadcast("startSong", null, { afterNextPatch: true });
        console.log(`[FurtherRoom] ${this.roomId} startSong`);
      }
    });

    // --- realtime relay ---
    // strumPlay allowed in lobby too (StrumTestState sandbox)
    // Payload biçimi (PlayStateSync): ["pressed"|"static"|"confirm", key:Int, reset:Float]
    this.onMessage("strumPlay", (client, message: unknown) => {
      if (!this.player(client)) return;
      if (!this.allow(client, "strum", 120)) return;
      if (!Array.isArray(message) || message.length < 2 || message.length > 4) return;
      const anim = message[0];
      const key = message[1];
      if (typeof anim !== "string" || anim.length > 16) return;
      if (typeof key !== "number" || !Number.isFinite(key) || key < 0 || key > 31 || Math.floor(key) !== key) return;
      const reset = message.length > 2 && typeof message[2] === "number" && Number.isFinite(message[2]) ? message[2] : 0;
      this.broadcast("strumPlay", [client.sessionId, [anim, key, reset]], { except: client });
    });

    // Payload biçimi (PlayStateSync): [strumTime, noteData, isSustain, rating, noteType, 0, mustPress]
    this.onMessage("noteHit", (client, message: unknown) => {
      if (!this.player(client)) return;
      if (!this.allow(client, "hit", 80)) return;
      if (!Array.isArray(message) || message.length < 3 || message.length > 8) return;
      const strumTime = message[0];
      const noteData = message[1];
      const isSus = message[2];
      if (typeof strumTime !== "number" || !Number.isFinite(strumTime)) return;
      if (typeof noteData !== "number" || !Number.isFinite(noteData) || noteData < 0 || noteData > 31 || Math.floor(noteData) !== noteData) return;
      if (!FurtherRoom.isPrimitive(message[3]) || !FurtherRoom.isPrimitive(message[4])) return;
      const clean = [
        strumTime,
        noteData,
        isSus === true,
        String(message[3] ?? "").slice(0, 16),
        String(message[4] ?? "").slice(0, 32),
        0,
        message[6] === true,
      ];
      this.broadcast("noteHit", [client.sessionId, clean], { except: client });
      if (this.state.isStarted) this.applyHealth(client, "hit");
    });

    // Payload biçimi (PlayStateSync): [strumTime, noteData, isSustain]
    this.onMessage("noteMiss", (client, message: unknown) => {
      if (!this.player(client)) return;
      if (!this.allow(client, "miss", 80)) return;
      if (!Array.isArray(message) || message.length < 3 || message.length > 4) return;
      const strumTime = message[0];
      const noteData = message[1];
      if (typeof strumTime !== "number" || !Number.isFinite(strumTime)) return;
      if (typeof noteData !== "number" || !Number.isFinite(noteData) || noteData < 0 || noteData > 31) return;
      this.broadcast("noteMiss", [client.sessionId, [strumTime, noteData, message[2] === true]], { except: client });
      if (this.state.isStarted) this.applyHealth(client, "miss");
    });

    this.onMessage("charPlay", (client, message: unknown) => {
      if (!this.player(client)) return;
      if (!this.allow(client, "char", 40)) return;
      // Büyük/karmaşık payload'ları reddet (relay şişirmesin).
      try {
        if (message != null && JSON.stringify(message).length > 512) return;
      } catch {
        return;
      }
      this.broadcast("charPlay", [client.sessionId, message], { except: client });
    });

    this.onMessage("setScore", (client, score: number) => {
      const p = this.player(client);
      if (!p || !this.state.isStarted) return;
      if (!this.allow(client, "score", 5)) return;
      // Mantık tavanı: sonucu belirleyen bu değer — çıplak istemci iddiasına sınırsız güvenme.
      p.score = Math.min(99999999, Math.max(0, Math.floor(Number(score) || 0)));
    });

    this.onMessage("addHitJudge", (client, rating: string) => {
      const p = this.player(client);
      if (!p || !this.state.isStarted) return;
      if (!this.allow(client, "judge", 80)) return;
      switch (String(rating)) {
        case "sick": if (p.sicks < 99999) p.sicks++; break;
        case "good": if (p.goods < 99999) p.goods++; break;
        case "bad": if (p.bads < 99999) p.bads++; break;
        case "shit": if (p.shits < 99999) p.shits++; break;
      }
    });

    this.onMessage("addMiss", (client) => {
      const p = this.player(client);
      if (!p || !this.state.isStarted) return;
      if (!this.allow(client, "judge", 80)) return;
      if (p.misses < 99999) p.misses++;
    });

    this.onMessage("updateMaxCombo", (client, combo: number) => {
      const p = this.player(client);
      if (!p || !this.state.isStarted) return;
      if (!this.allow(client, "combo", 10)) return;
      const v = Math.floor(Number(combo) || 0);
      if (v > p.maxCombo) p.maxCombo = Math.min(99999, v);
    });

    this.onMessage("playerEnded", (client) => {
      const p = this.player(client);
      if (!p || !this.state.isStarted) return;
      p.hasEnded = true;
      this.broadcast("log", `${p.name} finished`);

      let all = true;
      this.state.players.forEach((pl) => {
        if (!pl.hasEnded) all = false;
      });
      if (all) {
        this.broadcast("matchEnded", this.resultsPayload(), { afterNextPatch: true });
        console.log(`[FurtherRoom] ${this.roomId} matchEnded`);
        // Allow rematch from lobby without recreating room
        this.state.isStarted = false;
        this.state.players.forEach((p) => {
          p.isReady = false;
          p.hasLoaded = false;
          p.hasEnded = false;
          p.hasSong = true; // keep song unless host changes
        });
        // Notify clients to reset lobby UI
        this.broadcast("lobbyReset", {
          song: this.state.song,
          folder: this.state.folder,
          diff: this.state.diff,
          chartHash: this.state.chartHash,
          host: this.state.host
        });
        try { this.unlock(); } catch (_) {}
      }
    });

    this.onMessage("pong", (client) => {
      const now = Date.now();
      const sent = this.lastPong.get(client.sessionId);
      const p = this.player(client);
      if (p && sent != null) {
        p.ping = Math.max(0, now - sent);
      }
    });

    this.onMessage("chat", (client, text: string) => {
      const p = this.player(client);
      if (!p) return;
      if (!this.allow(client, "chat", 4, 2000)) return;
      const msg = String(text ?? "").slice(0, 200);
      if (!msg.trim()) return;
      this.broadcast("chat", { from: p.name, sid: client.sessionId, text: msg });
    });

    // Keepalive + ping sample every 5s
    this.clock.setInterval(() => {
      const now = Date.now();
      this.clients.forEach((c) => {
        this.lastPong.set(c.sessionId, now);
        c.send("ping", now);
      });
    }, 5000);
  }

  onJoin(client: Client, options: any) {
    const protocol = Number(options?.protocol ?? 0);
    if (protocol !== PROTOCOL) {
      client.send("alert", [
        "Protocol mismatch",
        `Server=${PROTOCOL} Client=${options?.protocol ?? "missing"}. Update Further Online.`,
      ]);
      // Uyumsuz istemci kesinlikle içeri girmez (protokol alanı eksik olsa bile).
      // İstemci tarafı FurtherOnline.PROTOCOL'ü her zaman gönderir (GameClient.buildOptions).
      client.leave(4000);
      return;
    }

    if (this.state.players.size >= MAX_PLAYERS) {
      client.leave(4001);
      return;
    }

    const p = new PlayerState();
    p.name = String(options?.name ?? "Player").slice(0, 24) || "Player";
    // First player = host + BF side; second = opponent side
    const isFirst = this.state.players.size === 0;
    p.bfSide = isFirst;
    if (isFirst) this.state.host = client.sessionId;

    this.state.players.set(client.sessionId, p);
    this.broadcast("log", `${p.name} joined (${this.state.players.size}/${MAX_PLAYERS})`);
    console.log(`[FurtherRoom] ${this.roomId} join ${p.name} ${client.sessionId}`);

    client.send("welcome", {
      roomId: this.roomId,
      sessionId: client.sessionId,
      protocol: PROTOCOL,
      host: this.state.host,
      bfSide: p.bfSide,
    });
  }

  async onLeave(client: Client, consented: boolean) {
    console.log(`[FurtherRoom] ${this.roomId} leave ${client.sessionId} consented=${consented}`);

    try {
      if (!consented) {
        // Notify the other player that opponent is reconnecting
        this.broadcast("log", `Waiting for ${this.player(client)?.name ?? client.sessionId} to reconnect... (15s)`);
        this.broadcast("alert", ["Connection Lost", "Opponent disconnected. Waiting for reconnection..."], { except: client });

        await this.allowReconnection(client, 15);
        console.log(`[FurtherRoom] ${client.sessionId} reconnected`);

        // Notify that player reconnected successfully
        this.broadcast("log", `${this.player(client)?.name ?? client.sessionId} reconnected!`);
        return;
      }
    } catch {
      // timeout — drop
    }

    const p = this.player(client);
    if (!p) {
      // Kayıt hiç oluşmadıysa (ör. protokol uyuşmazlığıyla reddedildiyse)
      // yalnızca yan kayıtları temizle.
      this.lastPong.delete(client.sessionId);
      this.clearBudgets(client.sessionId);
      return;
    }

    const name = p.name;
    const wasStarted = this.state.isStarted;
    this.state.players.delete(client.sessionId);
    this.lastPong.delete(client.sessionId);
    this.clearBudgets(client.sessionId);

    if (this.state.host === client.sessionId) {
      let next: string | null = null;
      this.state.players.forEach((_, sid) => {
        if (!next) next = sid;
      });
      this.state.host = next ?? "";
    }

    this.broadcast("log", `${name} left`);

    // Mid-match disconnect: end match for remaining player
    if (wasStarted) {
      this.broadcast("alert", ["Opponent left", "Match ended."]);
      // Force remaining players as ended and close match
      this.state.players.forEach((pl) => {
        pl.hasEnded = true;
      });
      this.broadcast("matchEnded", this.resultsPayload(), { afterNextPatch: true });
      this.state.isStarted = false;
      this.state.players.forEach((pl) => {
        pl.isReady = false;
        pl.hasLoaded = false;
        pl.hasEnded = false;
      });
      try { this.unlock(); } catch (_) {}
      console.log(`[FurtherRoom] ${this.roomId} matchEnded (disconnect)`);
    }
  }

  onDispose() {
    console.log(`[FurtherRoom] disposed ${this.roomId}`);
  }

  // --- helpers ---

  private player(client: Client): PlayerState | undefined {
    return this.state.players.get(client.sessionId);
  }

  private isHost(client: Client): boolean {
    return client.sessionId === this.state.host;
  }

  private applyHealth(client: Client, kind: "hit" | "miss") {
    const p = this.player(client);
    if (!p) return;

    // BF-side hit hurts "opponent" health convention like Psych Online:
    // bf hit → health decreases, dad hit → health increases
    const bf = p.bfSide;
    let delta = 0;
    if (kind === "hit") delta = bf ? -HEALTH_HIT : HEALTH_HIT;
    else delta = bf ? HEALTH_MISS : -HEALTH_MISS;

    let h = this.state.health + delta;
    if (h < 0) h = 0;
    if (h > 2) h = 2;
    this.state.health = h;
  }

  private async tryStartGame() {
    if (this.state.isStarted) return;
    if (this.state.players.size < 2) return;
    if (!this.state.song) return;

    let ok = true;
    this.state.players.forEach((p) => {
      if (!p.hasSong || !p.isReady) ok = false;
    });
    if (!ok) return;

    // reset match stats
    this.state.players.forEach((p) => {
      p.score = 0;
      p.misses = 0;
      p.sicks = 0;
      p.goods = 0;
      p.bads = 0;
      p.shits = 0;
      p.maxCombo = 0;
      p.hasLoaded = false;
      p.hasEnded = false;
      p.isReady = false;
    });

    this.state.health = 1;
    this.state.isStarted = true;
    await this.lock();
    this.broadcast("gameStarted", {
      song: this.state.song,
      folder: this.state.folder,
      diff: this.state.diff,
      chartHash: this.state.chartHash,
    }, { afterNextPatch: true });

    console.log(`[FurtherRoom] ${this.roomId} gameStarted ${this.state.song}`);
  }

  private resultsPayload() {
    const players: Record<string, object> = {};
    this.state.players.forEach((p, sid) => {
      players[sid] = {
        name: p.name,
        bfSide: p.bfSide,
        score: p.score,
        misses: p.misses,
        sicks: p.sicks,
        goods: p.goods,
        bads: p.bads,
        shits: p.shits,
        maxCombo: p.maxCombo,
      };
    });
    return {
      song: this.state.song,
      folder: this.state.folder,
      diff: this.state.diff,
      health: this.state.health,
      players,
    };
  }

  private generateCode(len: number): string {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    let out = "";
    for (let i = 0; i < len; i++) {
      out += chars[Math.floor(Math.random() * chars.length)];
    }
    return out;
  }
}
