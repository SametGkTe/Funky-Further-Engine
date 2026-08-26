# Further Online Server

LAN-first **1v1** Colyseus game server for [Funky Further Engine](https://github.com/SametGkTe/Funky-Further-Engine).

Supabase is **not** used here. Auth/leaderboards stay on Supabase in the game client. This process only handles realtime rooms (strum/note relay + lobby).

## Quick start

```bash
cd further-server
npm install
npm start
```

Default bind: `0.0.0.0:2567`

- PC local: `ws://127.0.0.1:2567`
- Phone on same Wi‑Fi: `ws://<PC_LAN_IP>:2567`
- Android emulator: `ws://10.0.2.2:2567`

## Room

- Matchmake name: **`further`** (alias `room`)
- Max players: **2**
- Protocol version: **1** (send `options.protocol = 1` from client)

## Client messages (C→S)

| type | payload |
|------|---------|
| `setSong` | `{ song, folder, diff, diffList, chartHash }` host only |
| `hasSong` | `bool` |
| `toggleReady` | — |
| `playerReady` | — after PlayState load |
| `strumPlay` | `[anim, keyIndex, resetAnim]` |
| `noteHit` | `[strumTime, noteData, isSustain, …]` |
| `noteMiss` | `[strumTime, noteData, isSustain]` |
| `charPlay` | anim payload |
| `setScore` | number |
| `addHitJudge` | `sick\|good\|bad\|shit` |
| `addMiss` | — |
| `updateMaxCombo` | number |
| `playerEnded` | — |
| `pong` | — reply to `ping` |
| `chat` | string |

## Server messages (S→C)

| type | meaning |
|------|---------|
| `welcome` | roomId, sessionId, bfSide |
| `gameStarted` | both ready → load PlayState |
| `startSong` | both loaded → countdown |
| `strumPlay` / `noteHit` / `noteMiss` / `charPlay` | relay `[sessionId, payload]` |
| `matchEnded` | results object |
| `ping` | keepalive |
| `alert` | `[title, body]` or string |
| `log` | lobby text |
| `chat` | `{ from, sid, text }` |

## Health

Server-authoritative `state.health` (0..2, start 1):

- BF-side hit → −0.023  
- Opponent-side hit → +0.023  
- Misses invert  

## Dev notes

- Node 18+
- Colyseus **0.15.x** (stable with current Haxe `colyseus` 0.15–0.17 clients; bump together later if needed)
- No database. Pure ephemeral rooms.

See also: `/home/user/Further-Online-MVP-Plan.md`
