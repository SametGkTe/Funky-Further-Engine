# Further Engine `pack.json` uyumluluğu

Further Engine, standart Psych Engine `pack.json` dosyalarını değiştirmeden desteklemeye devam eder. Sürüm kontrolü kullanmak isteyen modlar yalnızca aşağıdaki isteğe bağlı alanı ekleyebilir:

```json
{
  "name": "Örnek Mod",
  "description": "Psych Engine alanları aynen kullanılabilir.",
  "restart": false,
  "runsGlobally": false,
  "minimumFurtherVersion": "1.5.3"
}
```

## `minimumFurtherVersion`

- İsteğe bağlıdır.
- Modun çalışması için gereken en eski Further Engine sürümünü belirtir.
- Alan bulunmuyorsa klasik Psych Engine davranışı korunur ve sürüm kontrolü yapılmaz.
- Kullanıcının motoru belirtilen sürümden eskiyse `AlertMgr` üzerinden uyarı gösterilir.
- Uyarıya basıldığında `states.DebugErrState`, mod klasörünü ve iki sürümü ayrıntılı biçimde gösterir.

Örnek:

| Oyun | Mod minimumu | Sonuç |
| :-- | :-- | :-- |
| `1.5.3` | `1.5.3` | Uyumlu |
| `1.6.0` | `1.5.3` | Uyumlu |
| `1.5.3` | `1.6.0` | Uyarı gösterilir |
| `1.6.0-beta.1` | `1.6.0` | Uyarı gösterilir |

Sürüm karşılaştırması `v` ön ekini, noktayla ayrılmış sayıları, prerelease (`-beta.1`) ve build metadata (`+build`) biçimlerini destekler.
