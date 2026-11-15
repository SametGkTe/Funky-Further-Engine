package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import backend.ClientPrefs;
import backend.Language;
import backend.Log;
import backend.AuthManager;
import backend.update.UpdateChecker;
import backend.update.ReleaseChecker;
import backend.update.UpdateConfig;
#if VIDEOS_ALLOWED
import objects.VideoSprite;
#end

/**
 * FurtherBootState — Yeni yükleme ekranı.
 *
 * Akış:
 *   furtherstart.mp4 (loop) + alt-orta durum metni
 *     → tüm sistemler paralel kontrol (güncelleme / profil / modlar)
 *     → furtherout.mp4 (tek sefer) → Wizard / Title
 *
 * videos/ klasörü: assets/videos/furtherstart.mp4 + furtherout.mp4
 *   Paths.video('furtherstart') → assets/videos/furtherstart.mp4
 *   Yoksa static fallback logo gösterilir.
 */
class FurtherBootState extends MusicBeatState
{
    static inline var MIN_SHOW_TIME:Float = 4.5;
    static inline var STATUS_Y_OFFSET:Float = 36;

    var bg:FlxSprite;
    var statusText:FlxText;
    var statusBg:FlxSprite;
    var status:String = "";
    var overlayCam:flixel.FlxCamera;

    #if VIDEOS_ALLOWED
    var video:VideoSprite;
    var outroVideo:VideoSprite;
    #end
    var fallbackLogo:FlxSprite;

    var tasksDone:Int = 0;
    var tasksTotal:Int = 4;
    var booted:Bool = false;
    var outroStarted:Bool = false;
    var startTime:Float = 0;

    override function create():Void
    {
        super.create();
        FlxG.mouse.visible = false;
        startTime = 0;

        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF060010);
        add(bg);

        // Video önce (default camera), sonra overlay status (üst kamera)
        setupVideoOrFallback();
        // Overlay camera video'dan SONRA ki video overlay'e bulaşmasın
        overlayCam = new flixel.FlxCamera(0,0, FlxG.width, FlxG.height, 0);
        overlayCam.bgColor = 0x00000000;
        FlxG.cameras.add(overlayCam, false);
        setupStatusUI();

        // Müzik yoksa sessiz kalır, varsa breakfast devam etmez — boot sessiz
        if (FlxG.sound.music != null) FlxG.sound.music.fadeOut(0.3);

        // Görevleri başlat
        runBootTasks();
    }

    function setupVideoOrFallback():Void
    {
        // Önce siyahın üstüne status'ün görünür olduğunu doğrula — status zaten setupStatusUI ile eklendi
        #if VIDEOS_ALLOWED
        var videoName:String = 'furtherstart';
        // Kullanıcının dediği "videos/" klasörü: assets/videos/ + mods/videos/ hepsini dene
        // Paths.video() zaten mods/videos'u öncelikli döndürür, yoksa assets/videos/furtherstart.mp4
        var tried:Array<String> = ['furtherstart', 'furtherstart'];
        for (name in tried)
        {
            try {
                var testPath:String = backend.Paths.video(name);
                trace('[FurtherBootState] Deneniyor video: $name -> $testPath');
                video = new VideoSprite(testPath, true, false, true); // isWaiting=true → no black cover
                video.play();
                // VideoSprite kendi içinde FlxVideoSprite oluşturup load eder; onFormatSetup'te setGraphicSize yapar
                add(video);
                // Status UI videonun üstünde kalsın — member order: video alt, status üst
                // Bu yüzden statusBg/text'i üste taşı
                if (statusBg != null) { remove(statusBg,false); add(statusBg); }
                if (statusText != null) { remove(statusText,false); add(statusText); }
                trace('[FurtherBootState] furtherstart loop başlatıldı: $testPath');
                return;
            } catch (e:Dynamic) {
                trace('[FurtherBootState] Video denemesi fail ($name -> ${backend.Paths.video(name)}): $e');
                if (video != null) try { video.destroy(); } catch (_:Dynamic) {} 
                video = null;
            }
        }
        trace('[FurtherBootState] Hiçbir video bulunamadı, fallback logo gösteriliyor');
        createFallbackLogo();
        #else
        createFallbackLogo();
        #end
    }

    function createFallbackLogo():Void
    {
        fallbackLogo = new FlxSprite();
        try {
            fallbackLogo.loadGraphic(backend.Paths.image('further/title'));
            var s:Float = Math.min(FlxG.width * 0.7 / fallbackLogo.width, FlxG.height * 0.5 / fallbackLogo.height);
            fallbackLogo.scale.set(s, s);
            fallbackLogo.updateHitbox();
            fallbackLogo.screenCenter();
            fallbackLogo.y -= 40;
            fallbackLogo.antialiasing = ClientPrefs.data.antialiasing;
            add(fallbackLogo);
            FlxTween.tween(fallbackLogo, {alpha: 0.9}, 1.2, {type: PINGPONG});
        } catch (_:Dynamic) {
            fallbackLogo.makeGraphic(300, 80, 0xFF6B46C1);
            fallbackLogo.screenCenter();
            add(fallbackLogo);
        }
    }

    function setupStatusUI():Void
    {
        statusBg = new FlxSprite().makeGraphic(FlxG.width, 56, 0xEE000000);
        statusBg.y = FlxG.height - 56;
        statusBg.scrollFactor.set();
        statusBg.cameras = [overlayCam];
        add(statusBg);

        statusText = new FlxText(0, 0, FlxG.width - 40, "", 18);
        statusText.setFormat(backend.Paths.font("vcr.ttf"), 18, FlxColor.WHITE, CENTER, flixel.text.FlxText.FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        statusText.borderSize = 2.5;
        statusText.antialiasing = ClientPrefs.data.antialiasing;
        statusText.scrollFactor.set();
        statusText.cameras = [overlayCam];
        statusText.x = 20;
        add(statusText);

        // Görsel debug: ekranda olduğunu kesinleştir
        trace('[FurtherBootState] Status UI kuruldu: bg y=${statusBg.y} text w=${statusText.width}');

        setStatus("Başlatılıyor...");
    }

    function setStatus(s:String):Void
    {
        status = s;
        if (statusText == null || statusBg == null) return;
        statusText.text = s;
        // fieldHeight'i güncelle, sonra ortala
        statusText.updateHitbox();
        statusText.y = statusBg.y + (statusBg.height - statusText.height) / 2 - 2;
        statusText.visible = true;
        statusText.alpha = 1;
        trace('[FurtherBootState] STATUS: \"$s\" y=${statusText.y} visible=${statusText.visible}');
    }

    function runBootTasks():Void
    {
        // Kapsamlı ve akıcı — her adım en az 0.6s ekranda kalsın
        var staged:Array<{msg:String, fn:Void->Void}> = [
            {msg: "Ayarlar yükleniyor...", fn: function() { try { ClientPrefs.loadPrefs(); Language.reloadPhrases(); } catch (e:Dynamic) {} }},
            {msg: "Modlar hazırlanıyor...", fn: function() { try { backend.modpack.ModImportQueue.poll(); backend.further.TexturePackManager.init(); } catch (e:Dynamic) {} }},
            {msg: "Güncellemeler kontrol ediliyor...", fn: function() {}},
            {msg: "Profil yükleniyor...", fn: function() {}}
        ];
        var stageIdx:Int = 0;
        function nextStage():Void {
            if (stageIdx >= staged.length) return;
            var s = staged[stageIdx++];
            setStatus(s.msg);
            try s.fn() catch (_:Dynamic) {}
        }
        nextStage(); // Ayarlar
        new flixel.util.FlxTimer().start(0.7, function(_) { nextStage(); // Modlar
        new flixel.util.FlxTimer().start(0.7, function(_) { nextStage(); // Güncellemeler
        });});
        // Profil mesajı runBootTasks içinde sonra güncellenecek ama erken gösterelim diye staged'e dahil
        // 3 — Güncellemeler (async, en uzun süren) — Release + Modpack
        var releaseDone:Bool = false;
        var modpackDone:Bool = false;
        var authDone:Bool = false;

        // Profil auto-login de paralel
        var gotAuth:Bool = false;

        function checkAllDone():Void
        {
            if (releaseDone && modpackDone && authDone)
            {
                tasksDone = tasksTotal;
                onAllTasksDone();
            }
        }

        // ReleaseChecker
        try {
            ReleaseChecker.check();
            // ReleaseChecker async değil, hemen done say
            releaseDone = true;
        } catch (e:Dynamic) { releaseDone = true; trace('[Boot] ReleaseChecker fail: $e'); }

        // Modpack list
        try {
            UpdateChecker.instance.fetchModpackList(function(result) {
                if (result != null && result.hasUpdates) UpdateChecker.instance.hasPendingModpackUpdates = true;
                else UpdateChecker.instance.hasPendingModpackUpdates = false;
                trace('[Boot] Modpack check done: hasUpdates=${result != null ? result.hasUpdates : false}');
                modpackDone = true;
                // Delta için ekstra check
                UpdateChecker.instance.checkAllUpdatesIncludingDelta(function(pending:Bool) {
                    // hasPending zaten set edildi, log only
                    trace('[Boot] Delta check: $pending');
                });
                checkAllDone();
            });
            // Timeout fallback: 4 sn içinde dönmezse devam et
            new flixel.util.FlxTimer().start(4.0, function(_) {
                if (!modpackDone) { modpackDone = true; trace('[Boot] Modpack timeout'); checkAllDone(); }
            });
        } catch (e:Dynamic) { modpackDone = true; trace('[Boot] modpack fetch fail: $e'); }

        if (releaseDone) {
            // zaten true
        }

        // Auth auto-login paralel
        setStatus("Profil yükleniyor...");
        try {
            if (backend.AuthManager.isLoggedIn)
            {
                AuthManager.autoLogin(function(ok:Bool) {
                    trace('[Boot] Auto-login: $ok');
                    authDone = true;
                    checkAllDone();
                });
                // timeout 3s
                new flixel.util.FlxTimer().start(3.0, function(_) {
                    if (!authDone) { authDone = true; trace('[Boot] Auth timeout'); checkAllDone(); }
                });
            } else {
                authDone = true;
            }
        } catch (e:Dynamic) { authDone = true; }

        // Eğer modpack/release zaten bitti, geri kalanı bekle
        // Minimum show time için timer
        if (releaseDone && modpackDone && authDone)
            onAllTasksDone();
    }

    function onAllTasksDone():Void
    {
        if (booted) return;
        booted = true;
        setStatus("Hazırlanıyor...");
        // Video loop'un tadını çıkar — en az MIN_SHOW_TIME göster
        var elapsedSinceStart:Float = startTime;
        var wait:Float = Math.max(0, MIN_SHOW_TIME - elapsedSinceStart);
        // Eğer hala 1sn'den az kaldıysa, status'ü biraz tut
        if (wait < 0.4) wait = 0.6;
        new flixel.util.FlxTimer().start(wait, function(_) { playOutro(); });
    }

    function playOutro():Void
    {
        if (outroStarted) return;
        outroStarted = true;
        setStatus("Yükleme tamamlandı...");

        #if VIDEOS_ALLOWED
        // Loop videoyu durdur
        try { if (video != null) { video.destroy(); video = null; } } catch (_:Dynamic) {}
        if (fallbackLogo != null) FlxTween.tween(fallbackLogo, {alpha: 0}, 0.3);

        // Status'u outro sırasında da üstte tut ama 1sn sonra fade out
        new flixel.util.FlxTimer().start(0.8, function(_) {
            if (statusBg != null) FlxTween.tween(statusBg, {alpha: 0}, 0.6);
            if (statusText != null) FlxTween.tween(statusText, {alpha: 0}, 0.6);
        });

        var triedOut:Array<String> = ['furtherout'];
        for (name in triedOut)
        {
            try {
                var outPath:String = backend.Paths.video(name);
                outroVideo = new VideoSprite(outPath, true, false, false);
                outroVideo.play();
                outroVideo.finishCallback = function() goNext();
                try { outroVideo.videoSprite.bitmap.onEndReached.add(function() goNext()); } catch (_:Dynamic) {}
                add(outroVideo);
                // Status'u tekrar üste taşı (video üstüne çıkmasın, istersen video altında kalsın)
                if (statusBg != null) { remove(statusBg,false); add(statusBg); }
                if (statusText != null) { remove(statusText,false); add(statusText); }
                trace('[FurtherBootState] furtherout başladı: $name');
                new flixel.util.FlxTimer().start(6.5, function(_) { if (!goNextDone) goNext(); });
                return;
            } catch (e:Dynamic) {
                trace('[FurtherBootState] furtherout denemesi fail ($name): $e');
                if (outroVideo != null) try { outroVideo.destroy(); } catch (_:Dynamic) {}
                outroVideo = null;
            }
        }
        trace('[FurtherBootState] Hiçbir outro video yok, direkt geç');
        goNext();
        #else
        goNext();
        #end
    }

    override function destroy():Void
    {
        if (overlayCam != null)
        {
            FlxG.cameras.remove(overlayCam, false);
            overlayCam.destroy();
            overlayCam = null;
        }
        super.destroy();
    }

    var goNextDone:Bool = false;
    function goNext():Void
    {
        if (goNextDone) return;
        goNextDone = true;
        // overlay cam'i temizle
        if (overlayCam != null)
        {
            FlxG.cameras.remove(overlayCam, false);
            overlayCam.destroy();
            overlayCam = null;
        }

        #if VIDEOS_ALLOWED
        try { if (outroVideo != null) outroVideo.destroy(); } catch (_:Dynamic) {}
        #end

        FlxTransitionableState.skipNextTransIn = true;
        FlxTransitionableState.skipNextTransOut = true;

        if (!ClientPrefs.data.setupWizardCompleted || SetupWizardState.debugMode)
        {
            SetupWizardState.returnToWizard = false;
            FlxG.switchState(new SetupWizardState());
        }
        else
        {
            FlxG.switchState(new FurtherIntroState());
        }
    }

    override function update(elapsed:Float):Void
    {
        super.update(elapsed);
        startTime += elapsed;
        // Status text nabız (hafif alpha)
        if (statusText != null) statusText.alpha = 0.85 + Math.sin(startTime * 2.5) * 0.15;
    }
}
