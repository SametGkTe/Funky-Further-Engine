# Further Online — Drop-in pack

**Doğrudan Funky-Further-Engine repo köküne kopyala.**

## Kurulum (1 dakika)

```bash
# 1) Bu klasörün İÇİNDEKİLERİ FE repo köküne birleştir:
#    source/  →  FE/source/
#    Project.xml → FE/Project.xml  (üzerine yaz veya diff al)
#    further-server/ → FE/further-server/  (veya ayrı klasör)

cp -r source/*   /path/to/Funky-Further-Engine/source/
cp Project.xml   /path/to/Funky-Further-Engine/Project.xml
cp -r further-server /path/to/Funky-Further-Engine/
```

> **Uyarı:** `PlayState.hx`, `MainMenuState.hx`, `MusicBeatState.hx`, `Note.hx`, `Project.xml`
> upstream FE main'den patch'lenmiş **tam dosyalardır**. Kendi local değişikliklerin varsa
> önce yedek al / merge et.

## Haxelib

```bash
haxelib install colyseus 0.15.0
haxelib install colyseus-websocket 1.0.14
```

Sürüm uyuşmazlığında server `further-server/package.json` içindeki `colyseus@0.15.x` ile hizala.

## Sunucu

```bash
cd further-server
npm install
npm start
# ws://0.0.0.0:2567
```

## Oyunda

1. Derle (`FURTHER_ONLINE` Project.xml'de açık)
2. Ana menüde **O** tuşu → Online menü
3. Address: `ws://127.0.0.1:2567`
4. CREATE → kodu paylaş → diğer client JOIN
5. **STRUM TEST** ile ok relay dene
6. Host SET SONG `tutorial` → ikisi I HAVE SONG → READY → maç

## Ne değişti (FE dosyaları)

| Dosya | Değişiklik |
|-------|------------|
| `Project.xml` | `FURTHER_ONLINE` + colyseus haxelibs |
| `MusicBeatState.hx` | `NetThread.pump()` |
| `MainMenuState.hx` | **O** → OnlineMenuState |
| `Note.hx` | Online'da opponent auto-hit kapalı |
| `PlayState.hx` | Full 1v1 hooks + startCallback defer |
| `source/online/**` | Yeni netcode paketi |

## Offline

`Project.xml` içinden `<define name="FURTHER_ONLINE" />` satırını sil → online kod compile-out, normal FE.

## MVP limitleri

- İlk sürüm aynı chart / skor+ok senkronu (side-swap duel sonraki adım)
- Supabase leaderboard aynen duruyor
- Public internet sunucu yok (LAN first)

## Test

```bash
cd further-server && npm start
# başka terminal:
node test-client.mjs
```
