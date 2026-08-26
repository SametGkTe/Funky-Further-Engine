/**
 * Quick Node smoke test without the game client.
 * Usage: node test-client.mjs
 *        node test-client.mjs join ROOMCODE
 */
import { Client } from "colyseus.js";

const endpoint = process.env.FURTHER_URL || "http://127.0.0.1:2567";
const mode = process.argv[2] || "create";
const roomId = process.argv[3];
const name = process.argv[4] || (mode === "create" ? "HostBot" : "GuestBot");

const client = new Client(endpoint);

function bind(room) {
  console.log("joined", room.roomId, "sid", room.sessionId);

  room.onMessage("*", (type, message) => {
    console.log("←", type, JSON.stringify(message));
  });

  room.onStateChange((state) => {
    const players = [];
    state.players.forEach((p, sid) => {
      players.push(`${p.name}(${sid.slice(0, 4)} ready=${p.isReady} song=${p.hasSong} bf=${p.bfSide})`);
    });
    console.log("state players:", players.join(" | "), "song=", state.song, "started=", state.isStarted);
  });

  return room;
}

async function main() {
  console.log("endpoint", endpoint, "mode", mode);
  let room;
  if (mode === "join") {
    if (!roomId) throw new Error("need room id");
    room = await client.joinById(roomId, { name, protocol: 1 });
  } else {
    room = await client.create("further", { name, protocol: 1 });
    console.log("\n*** SHARE CODE:", room.roomId, "***\n");
  }
  bind(room);

  // host auto-sets a fake song after 1s
  if (mode !== "join") {
    setTimeout(() => {
      room.send("setSong", {
        song: "tutorial",
        folder: "",
        diff: 1,
        diffList: ["Normal"],
        chartHash: "dev",
      });
      room.send("hasSong", true);
      console.log("→ setSong + hasSong");
    }, 800);
  } else {
    setTimeout(() => {
      room.send("hasSong", true);
      console.log("→ hasSong");
    }, 500);
  }

  // ready after 2s
  setTimeout(() => {
    room.send("toggleReady");
    console.log("→ toggleReady");
  }, 2000);

  // if game starts, pretend loaded
  room.onMessage("gameStarted", () => {
    console.log("gameStarted — sending playerReady");
    room.send("playerReady");
  });

  room.onMessage("startSong", () => {
    console.log("startSong — fake strum");
    room.send("strumPlay", ["pressed", 0, 0]);
    setTimeout(() => room.send("strumPlay", ["static", 0, 0]), 200);
    setTimeout(() => {
      room.send("noteHit", [1000, 0, false, "sick", "", 0, true]);
      room.send("setScore", 350);
      room.send("addHitJudge", "sick");
    }, 500);
  });
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
