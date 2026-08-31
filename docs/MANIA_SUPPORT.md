# Mania Desteği Düzeltmesi (Further Engine)

Bu belge, Mania Modu'nun (5K-9K) yeniden yazılan davranışını açıklar.

## Düzeltilmeden önceki hatalar

1. **Rakip okları oyuncu tarafına geliyordu**: eski mantık `mustPress = (lane < totalColumns)`
   kullanıyordu. Standart 4K chart'ta rakip şeritleri 4-7'dir; 6K modunda 4-5 numaralı
   rakip notaları yanlışlıkla oyuncu notası sayılıyordu.
2. **Ok konumları bozuktu**: `getManiaStrumX` yarı ekranı kolon sayısına bölüp grubu
   ortalamıyordu — oklar üst üste biniyor (middleScroll'ta "aşırı büyük" görüntü) veya
   ekran dışına taşıyordu (6K'da son 2 ok 1280px'i aşıyordu).
3. **Çift konum ofseti**: nota konumu strum'a hizalandıktan sonra bir de
   `x += FlxG.width / 2` uygulanıyordu → oyuncu notaları yarım ekran sağa kayıyordu.

## Yeni davranış

| Konu | Kural |
|---|---|
| Şerit eşleme | lane 0-3 = oyuncu, 4-7 = rakip, **8+ = oyuncu ekstra tuşları** (mania-native chart'lar için) |
| Rakip tarafı | Her zaman **4K** kalır (oklar yerinden oynamaz, oyuncu tarafına asla karışmaz) |
| Oyuncu tarafı | `totalColumns` (mania) kadar ok, oyun alanına **eşit aralıklı ve ortalanmış** dizilir |
| Alan | middleScroll kapalı: sağ yarı ekran; middleScroll açık: tam ekran (osu tarzı) |
| Ok boyutu | Şerit ok genişliğinden dar kalırsa oklar orantılı küçülür → çakışma/taşma olmaz; notalar da aynı ölçekle gelir |
| Nota konumu | Nota her zaman kendi strum'ının üzerine hizalanır; yarım ekran ofseti mania'da uygulanmaz |
| Sustain | Sustain notaları da aynı hizada ve ölçekte |
| Hitbox | `PlayState.getManiaColumns()` → ayar + şarkı bildirimi senkron |

## Şarkı tarafından mania bildirimi

- `SwagSong`'a `@:optional var mania:Null<Int>` eklendi.
- Bir şarkı JSON'unda `mania: 6` varsa, kullanıcı ayarı ne olursa olsun o şarkı 6K oynanır
  (`resolveTotalColumns`).
- **CNE şarkılarında otomatik**: `CNESongConverter` artık oyuncu strumline'ındaki
  id 4-7 notalarını lane 8-11'e taşır ve şarkıya `mania: <maks id + 1>` yazar.
  Yani CNE 6K/7K/9K şarkıları Mania Modu açık olmasa bile doğru şekilde mania olarak açılır.

## Değişen dosyalar

- `states/PlayState.hx` — şerit eşleme (`maniaMapLane`), ok dizilimi (`getManiaStrumX` /
  `getManiaLaneWidth`), çift ofset düzeltmesi, sustain hizalaması, `getManiaColumns()`,
  `strumsBlocked` başlatma (countdown'da oyuncu şeridi başına false; mania kolonları dahil)
- `backend/Song.hx` — `SwagSong.mania` alanı
- `cne/compatibility/CNESongConverter.hx` — mania lane taşıma + `mania` bildirimi
- `mobile/objects/Hitbox.hx` / `FurtherHitbox.hx` — hitbox artık şarkının mania değerini görür
- `options/GameplaySettingsSubState.hx` — açıklama güncellendi

## Notlar

- 4K modunda (mania kapalı) lane 8+ notaları sessizce atlanır — normal chart'lar etkilenmez.
- Rakip strumline'ı 4K üstü CNE chart'ları desteklenmez (notalar atlanır).
- Ekstra tuşlarda splash/renk, o tuşun kolonuna en yakın 4K yönünü kullanır (görsel sınırlama).
