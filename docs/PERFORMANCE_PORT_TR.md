# NovaFlare performans incelemesi ve Further Engine uyarlaması

Kaynak proje: [FNF NovaFlare Engine](https://github.com/NovaFlare-Engine-Concentration/FNF-NovaFlare-Engine) (`e5dd183` incelendi).

NovaFlare; Psych tabanını kapsamlı şekilde değiştirmiş, özel OpenFL/Lime davranışları ve Windows'a özel NovaGC Haxe/hxcpp forkları kullanan bağımsız bir motordur. Bu nedenle tüm performans katmanını dosya bazında kopyalamak Further Engine'in Android/iOS desteğini ve Psych 1.0.4 uyumluluğunu bozabilir.

## Bu aşamada uyarlanan güvenli parçalar

- Yükleme worker sayısını kullanıcı ayarına bağlama.
- Android worker sayısını en fazla 2, masaüstünü en fazla 4 ile sınırlama.
- Aynı preload girdilerini tekilleştirme.
- Tek bir loading boyunca aynı thread pool'u yeniden kullanma.
- Worker tamamlanma sayacını mutex ile koruma.
- Future hatasında sonsuz loading yerine güvenli fallback.
- Bitmap preload sonrasında doğru `cacheBitmap` parametre sırasını kullanma.
- Bulunmayan tracked bitmap üzerinde `.bitmap` erişimini engelleme.
- Her state geçişinde senkron major GC çalıştırmayı kaldırma.
- Kullanımda olan `FlxGraphic` texture'larını anında dispose etmek yerine Flixel yaşam döngüsüne bırakma.

## Bilerek alınmayan parçalar

### NovaGC / hxcpp-zgc

NovaFlare aşağıdaki özel toolchain'lere bağlıdır:

- `NovaFlare-Engine-haxelib/hxcpp-novagc`
- `NovaFlare-Engine-haxelib/haxe-novagc`

Bu sistem özellikle Windows build workflow'unda etkinleştiriliyor. Further Engine'e doğrudan alınması tüm derleme zincirini değiştirir, GitHub Actions ve Android NDK uyumluluğunu riske atar. Ayrı deneysel branch ve benchmark olmadan kullanılmamalıdır.

### Immix gameplay GC API

`__hxcpp_gc_enter_gameplay`, `__hxcpp_gc_leave_gameplay` ve ilişkili API'ler stock hxcpp'de garanti edilmez. Haxe dosyasını tek başına kopyalamak linker hatası üretir.

### Ayrı update/draw framerate

NovaFlare'ın `drawFrameRate` desteği özel Lime/OpenFL katmanına bağlıdır. Stock Further toolchain'de aynı API mevcut değildir. Sadece FPS sayısını yükseltmek mobilde pil, sıcaklık ve CPU kullanımını artırabilir.

### OpenFL renderer override'ları

NovaFlare `openfl/display/OpenGLRenderer.hx`, `Shader.hx`, `AssetCache.hx` gibi framework sınıflarını source override ile değiştiriyor. Bunlar kullanılan OpenFL commit'ine sıkı bağlıdır ve Further'ın shader/V-Slice katmanıyla çakışabilir.

### Loading sırasında GC'yi tamamen kapatma

NovaFlare loading ve PlayState kurulumu sırasında GC'yi belirli noktalarda kapatıyor. Büyük Android modlarında bu yaklaşım heap'in hızla büyümesine ve sistemin uygulamayı LMK ile öldürmesine yol açabilir. Further için worker sınırı ve güvenli cache temizliği tercih edilmiştir.

## Sonraki aşama için ölçüm planı

Her optimizasyon aynı cihaz ve aynı mod üzerinde karşılaştırılmalıdır:

- Story Menu → PlayState yükleme süresi
- İlk frame süresi
- Ortalama FPS ve %1 low
- En uzun frame süresi
- Şarkı öncesi/sonrası RAM
- Android Java/native PSS
- State geçişindeki GC pause
- Uygulamanın sıcaklık ve pil etkisi

Ölçülmeyen bir “optimizasyon” yalnızca davranış değişikliğidir. Özellikle özel GC ve renderer değişiklikleri benchmark sonucu olmadan kararlı branch'e alınmamalıdır.
