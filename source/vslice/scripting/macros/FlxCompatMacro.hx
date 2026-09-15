package vslice.scripting.macros;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

/**
 * FNF uyumluluk build makrosu (FNF'nin funkin.util.macro.FlxMacro'sunun
 * esdegeri — FunkinCrew/Funkin, MIT lisansli uyarlama).
 *
 * Yeni flixel (dev) `zIndex` alanini FlxBasic'ten KALDIRDI (derinlik
 * sistemi FlxContainer/FlxDepthSlot'a tasindi). FNF, script'lerin
 * kullandigi `zIndex` (ve FlxSprite'taki local* uyumluluk alanlarini)
 * bu makroyla geri ekler (project.hxp: addMetadata('@:build(FlxMacro...)',
 * 'flixel.FlxBasic' / 'flixel.FlxSprite')).
 *
 * v15.7: Ayni mekanizma Further'a eklendi. Makro calismazsa V-Slice
 * script'lerinde `sprite.zIndex = ...` yazmalari "Invalid access to
 * field zIndex" hatasi alir (garage.hxc satir 148 gibi).
 */
class FlxCompatMacro
{
	public static macro function buildFlxBasic():Array<Field>
	{
		var pos:Position = Context.currentPos();
		var fields:Array<Field> = Context.getBuildFields();

		var hasZIndex = false;
		for (f in fields)
		{
			if (f.name == 'zIndex')
			{
				hasZIndex = true;
				break;
			}
		}

		if (!hasZIndex)
		{
			// FNF'nin ekledigi alanla BIREBIR ayni: islevsel kod bagli degil,
			// FlxTypedGroup.sort icin hedef deger olarak kullanilabilir.
			fields.push({
				name: 'zIndex',
				access: [APublic],
				kind: FVar(macro :Int, macro $v{0}),
				pos: pos
			});
		}

		return fields;
	}

	public static macro function buildFlxSprite():Array<Field>
	{
		var pos:Position = Context.currentPos();
		var fields:Array<Field> = Context.getBuildFields();

		var wanted:Array<{name:String, kind:FieldType}> = [
			{name: 'localX', kind: FVar(macro :Float, macro $v{0})},
			{name: 'localY', kind: FVar(macro :Float, macro $v{0})},
			{name: 'localAngle', kind: FVar(macro :Float, macro $v{0})},
			{name: 'localScale', kind: FVar(macro :flixel.math.FlxPoint, macro new flixel.math.FlxPoint(1, 1))},
			{name: 'localAlpha', kind: FVar(macro :Float, macro $v{1})},
			{name: 'localVisible', kind: FVar(macro :Bool, macro $v{true})}
		];

		for (w in wanted)
		{
			var exists = false;
			for (f in fields)
			{
				if (f.name == w.name)
				{
					exists = true;
					break;
				}
			}
			if (!exists)
			{
				fields.push({
					name: w.name,
					access: [APublic],
					kind: w.kind,
					pos: pos
				});
			}
		}

		return fields;
	}
}
#end
