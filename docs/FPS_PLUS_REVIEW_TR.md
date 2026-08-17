# FPS Plus incelemesi ve Further Engine uyarlaması

Kaynak: [ThatRozebudDude/FPS-Plus-Public](https://github.com/ThatRozebudDude/FPS-Plus-Public), incelenen revision `4fc8632`.

FPS Plus'ın lisansı standart Apache/MIT değildir ve kullanımı non-commercial şartla sınırlar. Further Engine Apache 2.0 dağıtımını korumak için kaynak kod kopyalanmamış; genel mühendislik fikirleri Further mimarisinde bağımsız olarak uygulanmıştır.

## Uygulanan fikirler

- Mod metadata/sürüm kontrolünü mod scriptleri ve Polymod başlamadan önce çalıştırma.
- Devre dışı veya preflight'ta engellenmiş modları Polymod'a göndermeme.
- Update/animation callback ortasında yok edilen nesneleri `postUpdate` sonrasına erteleme.
- Frame hızından bağımsız, hitch sonrası overshoot üretmeyen exponential damp yardımcıları.
- Release build için Haxe analyzer optimizasyonu.
- İsteğe bağlı Tracy/hxcpp profiler define'ları.
- V-Slice chart algılamasını yalnızca gerçek difficulty-map ve `{t,d}` nota yapısında kabul etme.
- Chart parse exception'larını sessizce yutmak yerine mod, yol ve stack ile loglama.
- Custom difficulty suffixlerini aktif `Difficulty.list` üzerinden tanıma.

## Bilerek uygulanmayanlar

- Her state geçişinde zorunlu major GC: menü hitch'i oluşturduğu için alınmadı.
- Texture'ı doğrudan `__texture.dispose()` ile yok etme: kullanımda olan GPU kaynağında native crash riski taşır.
- Bütün karakter/stage varlıklarını mobilde VRAM'e preload etme: düşük bellek cihazlarında LMK riski taşır.
- 999/uncapped FPS'i mobilde varsayılan yapma: ısınma, pil ve throttling yaratır.
- FPS Plus kaynak sınıflarını veya görsel/marka varlıklarını kopyalama: lisans ve mimari uyumsuzluk nedeniyle yapılmadı.

## Gelecek için adaylar

- Bellek bütçeli LRU/TTL cache (mobil 1 state, masaüstü 2 state grace).
- Aynı anda gelen aynı asset isteklerini tek Future altında birleştirme.
- Mod `pack.json` içinde sınırlandırılmış preload önerileri.
- Event scriptleri için loading sırasında çalışan güvenli preprocess API.
- Tracy ile ölçülen, ayrı performans benchmark workflow'u.
