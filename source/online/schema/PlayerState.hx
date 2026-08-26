package online.schema;

#if FURTHER_ONLINE
import io.colyseus.serializer.schema.Schema;
import io.colyseus.serializer.schema.types.*;

/**
 * Keep fields in sync with further-server/src/rooms/schema/PlayerState.ts
 */
class PlayerState extends Schema {
	@:type("string") public var name:String = "Player";
	@:type("number") public var ping:Dynamic = 0;

	@:type("boolean") public var bfSide:Bool = true;
	@:type("boolean") public var hasSong:Bool = false;
	@:type("boolean") public var isReady:Bool = false;
	@:type("boolean") public var hasLoaded:Bool = false;
	@:type("boolean") public var hasEnded:Bool = false;

	@:type("number") public var score:Dynamic = 0;
	@:type("number") public var misses:Dynamic = 0;
	@:type("number") public var sicks:Dynamic = 0;
	@:type("number") public var goods:Dynamic = 0;
	@:type("number") public var bads:Dynamic = 0;
	@:type("number") public var shits:Dynamic = 0;
	@:type("number") public var maxCombo:Dynamic = 0;
}
#else
class PlayerState {}
#end
