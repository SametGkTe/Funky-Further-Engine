package funkin.modding;

/**
 * V-Slice/FNF uyumluluk shim'i (IScriptedClass modülü) — v15.
 *
 * Resmî funkin v0.8.7 `funkin/modding/IScriptedClass.hx` modülündeki
 * TÜM arayüzler burada taşınır. ÖNEMLİ FARK: resmî FNF'de bunlar
 * `interface`'tir; Haxe runtime'da arayüzler Type.resolveClass ile
 * ÇÖZÜLEMEZ. Polymod'un import doğrulaması (validateImports) runtime
 * çözümlemesine baktığı için burada BOŞ SINIF olarak tanımlandılar.
 *
 * Script tarafında `implements IPlayStateScriptedClass` yazmak sorun
 * çıkarmaz: HScript `implements` bildirimini parse eder ama runtime'da
 * zorlamaz (resmî FNF'de de davranış aynıdır — metodlar zaten
 * ScriptEventDispatcher üzerinden isimle çağrılır).
 */
@:noCustomClass
class IScriptedClass
{
}

@:noCustomClass
class IEventHandler
{
}

@:noCustomClass
class IStateChangingScriptedClass
{
}

@:noCustomClass
class IStateStageProp
{
}

@:noCustomClass
class INoteScriptedClass
{
}

@:noCustomClass
class IBPMSyncedScriptedClass
{
}

@:noCustomClass
class IPlayStateScriptedClass
{
}

@:noCustomClass
class IFreeplayScriptedClass
{
}

@:noCustomClass
class ICharacterSelectScriptedClass
{
}

@:noCustomClass
class IDialogueScriptedClass
{
}
