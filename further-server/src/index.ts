import http from "http";
import express from "express";
import cors from "cors";
import { Server } from "colyseus";
import { WebSocketTransport } from "@colyseus/ws-transport";
import os from "os";
import { FurtherRoom, PROTOCOL } from "./rooms/FurtherRoom";

const PORT = Number(process.env.PORT ?? 2567);

function lanIPv4(): string[] {
  const out: string[] = [];
  const ifs = os.networkInterfaces();
  for (const name of Object.keys(ifs)) {
    for (const info of ifs[name] ?? []) {
      if (info.family === "IPv4" && !info.internal) out.push(info.address);
    }
  }
  return out;
}

async function main() {
  const app = express();
  app.use(cors());
  app.use(express.json());

  app.get("/", (_req, res) => {
    res.json({
      name: "further-online-server",
      protocol: PROTOCOL,
      room: "further",
      status: "ok",
    });
  });

  app.get("/api/onlinecount", (_req, res) => {
    // simple placeholder — clients may poll
    res.type("text").send(String(gameServer.presence ? 0 : 0));
  });

  app.get("/health", (_req, res) => res.send("ok"));

  const httpServer = http.createServer(app);

  const gameServer = new Server({
    transport: new WebSocketTransport({
      server: httpServer,
    }),
  });

  gameServer.define("further", FurtherRoom).enableRealtimeListing();

  // also accept Psych-Online-like name for easier experiments
  gameServer.define("room", FurtherRoom);

  httpServer.listen(PORT, "0.0.0.0", () => {
    const lans = lanIPv4();
    console.log("");
    console.log("╔══════════════════════════════════════════════╗");
    console.log("║     Further Online Server (MVP spike)        ║");
    console.log("╚══════════════════════════════════════════════╝");
    console.log(`  protocol : ${PROTOCOL}`);
    console.log(`  room name: "further" (alias: "room")`);
    console.log(`  local    : ws://127.0.0.1:${PORT}`);
    for (const ip of lans) {
      console.log(`  LAN      : ws://${ip}:${PORT}`);
    }
    console.log(`  Android emulator → host: ws://10.0.2.2:${PORT}`);
    console.log("");
    console.log("  FE client: GameClient.serverAddress = above URL");
    console.log("");
  });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
