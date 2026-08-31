package cne.compatibility.codenamecrew.hscript;

/**
 * Special Interface to make a class usable for Custom Classes.
 * (hscript-improved fork'unun aynı isimli arayüzü;
 * Further'a gömmek için codenamecrew paketine taşındı — dış hscript paketi gerekmez)
 */
interface IHScriptCustomClassBehaviour extends IHScriptCustomAccessBehaviour{
	public var __interp:Interp;
	public var __real_fields:Array<String>;
	public var __class__fields:Array<String>;

}
