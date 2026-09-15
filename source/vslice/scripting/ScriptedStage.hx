package vslice.scripting;

import polymod.hscript.HScriptedClass;

/**
 * Scripted sahne sarmalayıcısı (resmî funkin v0.8.7 ScriptedStage ile aynı yapı).
 *
 * Mod script'leri `class garage extends Stage` (veya tam yol ile
 * `extends funkin.play.stage.Stage`) yazar. Polymod'un derleme-zamanı
 * scriptClassOverrides tablosu bu sınıf sayesinde otomatik dolar:
 *   "funkin.play.stage.Stage" -> vslice.scripting.ScriptedStage
 * ve `Type.createInstance(ScriptedStage, [id])` ile script'li sahne üretilir.
 *
 * SÖZLEŞME: script sınıfının ADI, sahne adıyla eşleşmelidir.
 * Örn. `stage: "garage"` için `class garage extends Stage { ... }`.
 * VSScriptRegistry.resolveStage(name) bu eşleşmeyi yapar.
 *
 * DİKKAT: Bu sınıfın ebeveyni DEĞİŞTİRİLMEMELİ — ebeveyn, override
 * tablosunun anahtarıdır (backend.BaseStage'e döndürmek V-Slice mod
 * script'lerinin "Cannot extend non-scriptable class" hatasıyla patlamasına yol açar).
 */
@:hscriptClass
class ScriptedStage extends funkin.play.stage.Stage implements HScriptedClass implements IHScriptedEvents
{
}
