V-SLICE SCRIPT TEST MODU (v16)
==============================

Bu klasoru OLDUGU GIBI `mods/` altina kopyala:
  mods/vslice-script-test/

Sonra oyunda Mods menusunden "vslice-script-test" modunu AC.

NE TEST EDER?
-------------
1) FurtherTestModule.hxc  — ScriptedModule + TIPLI olay nesneleri
   Herhangi bir sarkiya gir; loglarda su satirlari gormelisin:
     [FETest] Modul kuruldu (startup).
     [FETest] onCreate — event.type=CREATE
     [FETest] onUpdate — event.elapsed=0.016...
     [FETest] onSongLoaded — id=... diff=... notes=... events=...
     [FETest] onBeatHit — beat=32 step=128
     [FETest] onNoteHit — judge=sick combo=5 ...
     [FETest] onSongEvent — kind=FocusCamera value={...}   <- V-Slice mod sarkilarinda

2) TestWarnEvent.hxc — ScriptedSongEvent (handleEvent)
   Chart JSON'una "TestWarn" event'i eklenince calisir:
     {"t": 1000, "e": "TestWarn", "v": {"mesaj": "merhaba"}}
   Beklenen log:
     [FETest] TestWarn tetiklendi! mesaj=merhaba ...

3) IPTAL TESTI (noteMiss)
   FurtherTestModule.hxc icindeki `// event.cancel();` satirini ac,
   derle, bir notayi kacir: can/skor kaybi OLMAMALI.

4) FAZ 2 TESTLERI (v16) — FurtherTestModule.hxc'ye eklendi:
   a) Conductor.instance:
      [FETest] Conductor — bpm=100 songPos=... beat=... stepLenMs=...
      (sarki icinde onUpdate ilk 3 karede basar)
   b) PlayState takma adlari (onSongStart'ta):
      [FETest] PlayState — opponent=dad girlfriend=gf boyfriend=bf currentStage=var
   c) Gercek hitDiff (onNoteHit'te):
      [FETest] onNoteHit — judge=sick ... hitDiff=12.34
      (hitDiff artik 0 degil; ms cinsinden vurus farki, isaretsiz)

5) FAZ 3 TESTLERI (v17) — FurtherTestModule.hxc + TestNoteKind.hxc:
   a) Strumline takma adlari (onSongStart'ta):
      [FETest] Strumline — player strumlar=4 opponent strumlar=4 scrollSpeed=...
   b) Bopper sinifi (onSongStart'ta):
      [FETest] Bopper kuruldu — danceEvery=2 shouldBop=true
      (dance() atlas olmadigi icin sessiz gecer; CRASH olmamali)
   c) NoteKind kesfi (onSongStart'ta):
      [FETest] NoteKinds kayitli: testkind
      (TestNoteKind.hxc otomatik kaydedilir)
   d) NoteKind dispatch: chart'a "k":"testkind" olan bir nota koy ve vur:
      [FETest] NoteKind onNoteHit — kind=testkind judge=sick

6) FAZ 4 TESTLERI (v18) — FurtherTestModule.hxc'ye eklendi:
   a) PlayState.song takma adi (onSongStart'ta):
      [FETest] PlayState.song — songName=... songId=...
      (songName: calan sarki; script Song sinifi varsa songId onun id'si)
   b) Conductor FlxSignal (onSongStart sonrasi ilk beat'te, tek seferlik):
      [FETest] Conductor.onBeatHit SINYALI calisiyor — beat=...
   c) Yeni yerlesik chart event'leri: SetCameraBop + SetTargetBopSpeed.
      Chart'a {"e":"SetCameraBop","v":{"intensity":2,"rate":4}} koy:
      kamera vurusu guclenmeli. {"e":"SetTargetBopSpeed",
      "v":{"target":"girlfriend","rate":1}} -> gf her beat dans eder.

SUNDAY V-SLICE PORT ILE TEST
----------------------------
Sunday modunu acip bir sarkiya girdiginde:
  - fretPC / WarnCreate gibi scripted event'ler artik
    SongEventRegistry uzerinden handleEvent cagrisi almali.
  - Loglarda '[SongEventRegistry] Scripted event yuklendi: ...'
    satirlarini startup'ta gormelisin.
  - Hata olursa '[SongEventRegistry] ... kurulamadi' loglari
    nedenini soyler (orn. super('id') eksik).
