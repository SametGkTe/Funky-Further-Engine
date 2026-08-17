# Further Engine `pack.json`

Further Engine, standart Psych Engine `pack.json` dosyalarını değiştirmeden desteklemeye devam eder. Sürüm kontrolü kullanmak isteyen modlar yalnızca aşağıdaki isteğe bağlı alanı ekleyebilir:

```json
{
  "name": "Örnek Mod",
  "description": "Açıklama.",
  "restart": false,
  "runsGlobally": false,
  "minimumFurtherVersion": "1.5.3"
}
```

## `minimumFurtherVersion`

- İsteğe bağlıdır.
- Modun çalışması için gereken en eski Further Engine sürümünü belirtir.
- bulunmuyorsa klasik Psych Engine davranışı korunur ve sürüm kontrolü yapılmaz.
- Oyununun sürümü belirtilen sürümden eskiyse `AlertMgr` üzerinden uyarı gösterilir.
- Uyarıya basıldığında `states.DebugErrState`, mod klasörünü ve iki sürümü ayrıntılı biçimde gösterir.

Sürüm karşılaştırması `v` ön ekini, noktayla ayrılmış sayıları, prerelease (`-beta.1`) ve build metadata (`+build`) biçimlerini destekler.
