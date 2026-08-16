# Further Engine — Derleme Rehberi

Bu rehber Further Engine'i kaynak koddan Windows, Linux, macOS, Android veya iOS için derlemek isteyen geliştiricilere yöneliktir.

## Gereksinimler

### Ortak araçlar

- [Git](https://git-scm.com/)
- [Haxe](https://haxe.org/download/) ve Haxelib
- Hedef platforma uygun araç zinciri

### Platform için araçlar

| Windows | Visual Studio Build Tools ve C++/MSVC bileşenleri |
| Linux | GCC/Clang ve gerekli paketler |
| macOS | Xcode ve Command Line Tools |
| Android | Android SDK, Android NDK ve JDK 17 |
| iOS | macOS, Xcode ve iOS araç zinciri |

## 1. Repoyu klonlama
** Herhangi bir klasör açın, Masaüstü daha uygun olur, açtığınız klasörde CMD Panelini açın**
```bash
git clone https://github.com/SametGkTe/Funky-Further-Engine.git
```

Güncel geliştirme kodunu kullanmak istiyorsan `main` kullanabilirsin. istediğin bir sürümü derlemek için ilgili etikete geç:

**Örnek (Release 2 Alpha Sürümü)**
```bash
git checkout 1.5.3
```

## 2. Bağımlılıkları kurma

Proje için gerekli Haxelib paketlerini ve projeye sürümler kurar.

### Windows için

```bat
setup\windows.bat
```

MSVC ile ilgili sorun yaşarsan diğer bat'ı deneyebilirsin:

```bat
setup\windows-msvc.bat
```

### Linux / macOS için

```bash
chmod +x setup/unix.sh
./setup/unix.sh
```

Bu Kurulum; hxcpp, Lime, OpenFL, HaxeFlixel, flixel-addons, Iris/HScript, LuaJIT, hxVLC, FlxAnimate, Discord RPC, mobil kontroller ve diğer proje bağımlılıklarını kurar

> [!ÖNEMLİ]
> Betiği çalıştırmadan önce Haxe ile `haxelib` komutlarının CMD den çalıştığını garantile.

## 3. Test Derleme (Geliştirdiğiniz zaman için)

```bash
# Windows
lime test windows

# Linux
lime test linux

# macOS
lime test mac

# Android
lime test android

# iOS — (imzasız)
lime build ios -nosign
```

## 4. Final Derleme (Son Çıktı)

```bash
lime build <hedef> -final
```

Örnekler:

```bash
lime build windows -final
lime build linux -final
lime build mac -final
lime build android -final
lime build ios -final -nosign
```

Çıktılar normalde `export/release/` altında, derlenen platformun klasöründe oluşturulur. (`export/release/android, windows, linux` gibi)

## Android Derlemesi için!

Android derlemesinden önce Lime'a araç yollarını tanıtman gerek:

```bash
haxelib run lime config ANDROID_SDK /android/sdk/yolu
haxelib run lime config ANDROID_NDK_ROOT /android/ndk/yolu
haxelib run lime config JAVA_HOME /jdk17/yolu
haxelib run lime config ANDROID_SETUP true
```

Bu Projenin paket adı `com.sametgkte.furtherengine` olarak tanımlıdır. APK çıktısı genellikle şurada oluşur:

```text
export/release/android/bin/app/build/outputs/apk/release/
```

## Proje Özelliklerini Kişileştirme

İsteğe bağlı sistemler `Project.xml` içindeki tanımlarla yönetilir:

| `MODS_ALLOWED` | Mod klasörlerini etkinleştirir, Modları Kullanabilmek için gerekli |
| `LUA_ALLOWED` | Lua desteğini etkinleştirir, modlardaki lua kodları için gerekli |
| `HSCRIPT_ALLOWED` | HScript/Iris desteğini etkinleştirir, mod destekleri için |
| `VIDEOS_ALLOWED` | Video desteğini etkinleştirir, Cutscene ve Video oynatabilmek için |
| `ACHIEVEMENTS_ALLOWED` | Başarım sistemini etkinleştirir, Başarımlar için gerekli |
| `DISCORD_ALLOWED` | PC'de Discord Durumunu etkinleştirir, Discord'da Oyunun oynandığını gösterebilmek için gerekli |
| `TRANSLATIONS_ALLOWED` | Dil sistemini etkinleştirir, diğer diller için: en-EN, pt-BR vb. |
| `CHECK_FOR_UPDATES` | Güncelleme denetimini etkinleştirir, Oyun her açıldığında Güncellemeleri kontrol etmesi için gerekli |
| `MULTITHREADED_LOADING` | Desteklenen hedeflerde çok iş parçacıklı yüklemeyi etkinleştirir, Performans için |

Herhangi bir özelliği devre dışı bırakmak için ilgili satırı silebilir veya yorumuna alabilirsin:

**Örnek**

```xml
<!-- <define name="VIDEOS_ALLOWED" if="desktop || mobile" /> -->
```

> [!UYARI]
> Bir Özelliği kaldırmak yalnızca özelliği kapatmaz; o özelliğe bağlı Kodlarında çalışmasını engelleyebilir.

## GitHub Actions (Github Derlemesi)

Depodaki GitHub Actions iş akışı aşağıdaki hedefler için çıktı üretebilir:

- Windows x86_64
- Linux x86_64
- macOS x86_64
- macOS ARM64
- Android ARMv7/ARM64
- iOS

Manuel CI derlemesi başlatmak için deponun **Actions** sekmesinden uygun Derlemeyi seçip **Run workflow** kullanabilirsin.

## Sorun bildirirken

Bir derleme hatası için [issue açarken](https://github.com/SametGkTe/Funky-Further-Engine/issues/new/choose) şunları ekle:

- İşletim sistemi ve sürümü
- Hedef platform
- Haxe sürümü
- Kullandığın Further Engine etiketi veya commit'i
- Çalıştırdığın komut
- Terminal çıktısının hatayla ilgili tam bölümü
- `Project.xml` üzerinde yaptığın değişiklikler

---

[← Ana README](../README.md) · [Modlama rehberi →](MODDING_TR.md)
