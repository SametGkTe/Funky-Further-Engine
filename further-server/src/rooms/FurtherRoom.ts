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
export class FurtherRoom extends Room<{ state: RoomState }> {
  maxClients = MAX_PLAYERS;
  autoDispose = true;

  private lastPong = new Map<string, number>();

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
    this.onMessage("strumPlay", (client, message: unknown) => {
      if (!this.player(client)) return;
      if (!Array.isArray(message) || message.length < 2) return;
      this.broadcast("strumPlay", [client.sessionId, message], { except: client });
    });

    this.onMessage("noteHit", (client, message: unknown) => {
      if (!this.player(client)) return;
      if (!Array.isArray(message) || message.length < 3) return;
      this.broadcast("noteHit", [client.sessionId, message], { except: client });
      if (this.state.isStarted) this.applyHealth(client, "hit");
    });

    this.onMessage("noteMiss", (client, message: unknown) => {
      if (!this.player(client)) return;
      if (!Array.isArray(message) || message.length < 3) return;
      this.broadcast("noteMiss", [client.sessionId, message], { except: client });
      if (this.state.isStarted) this.applyHealth(client, "miss");
    });

    this.onMessage("charPlay", (client, message: unknown) => {
      if (!this.player(client)) return;
      this.broadcast("charPlay", [client.sessionId, message], { except: client });
    });

    this.onMessage("setScore", (client, score: number) => {
      const p = this.player(client);
      if (!p || !this.state.isStarted) return;
      p.score = Math.max(0, Math.floor(Number(score) || 0));
    });

    this.onMessage("addHitJudge", (client, rating: string) => {
      const p = this.player(client);
      if (!p || !this.state.isStarted) return;
      switch (String(rating)) {
        case "sick": p.sicks++; break;
        case "good": p.goods++; break;
        case "bad": p.bads++; break;
        case "shit": p.shits++; break;
      }
    });

    this.onMessage("addMiss", (client) => {
      const p = this.player(client);
      if (!p || !this.state.isStarted) return;
      p.misses++;
    });

    this.onMessage("updateMaxCombo", (client, combo: number) => {
      const p = this.player(client);
      if (!p || !this.state.isStarted) return;
      const v = Math.floor(Number(combo) || 0);
      if (v > p.maxCombo) p.maxCombo = v;
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
        `Server=${PROTOCOL} Client=${protocol}. Update Further Online.`,
      ]);
      // Still allow join in spike for easier testing if protocol omitted
      if (options?.protocol != null && protocol !== PROTOCOL) {
        client.leave(4000);
        return;
      }
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
        await this.allowReconnection(client, 15);
        console.log(`[FurtherRoom] ${client.sessionId} reconnected`);
        return;
      }
    } catch {
      // timeout — drop
    }

    const p = this.player(client);
    const name = p?.name ?? client.sessionId;
    const wasStarted = this.state.isStarted;
    this.state.players.delete(client.sessionId);
    this.lastPong.delete(client.sessionId);

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
