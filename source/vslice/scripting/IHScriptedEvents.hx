package vslice.scripting;

/**
 * Polymod hscript köprüsünün (HScriptedClassMacro) her scripted sınıfta
 * OTOMATİK ürettiği ortak API'nin arayüzü.
 *
 * Scripted sarmalayıcılar bu arayüzü implement eder; böylece
 * VSScriptEventDispatcher tip-güvenli şekilde script fonksiyonlarını
 * yoklayıp çağırabilir (script'te `function onBeatHit(event)` tanımlı mı?
 * varsa çağır, yoksa sessizce geç).
 */
interface IHScriptedEvents
{
	/** Script sınıfında (veya üst zincirinde) o alan/fonksiyon var mı? */
	public function scriptHas(fieldName:String):Bool;

	/** Script sınıfında tanımlı bir fonksiyonu çağırır. */
	public function scriptCall(funcName:String, ?funcArgs:Array<Dynamic>):Dynamic;
}
