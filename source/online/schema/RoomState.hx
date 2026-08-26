package online.schema;

#if FURTHER_ONLINE
import io.colyseus.serializer.schema.Schema;
import io.colyseus.serializer.schema.types.*;

/**
 * Keep fields in sync with further-server/src/rooms/schema/RoomState.ts
 */
class RoomState extends Schema {
	@:type("string") public var song:String = "";
	@:type("string") public var folder:String = "";
	@:type("number") public var diff:Dynamic = 1;
	@:type("array", "string") public var diffList:ArraySchema<String> = new ArraySchema<String>();
	@:type("string") public var chartHash:String = "";

	@:type("string") public var host:String = "";
	@:type("boolean") public var isStarted:Bool = false;
	@:type("number") public var health:Dynamic = 1;

	@:type("map", PlayerState) public var players:MapSchema<PlayerState> = new MapSchema<PlayerState>();
}
#else
class RoomState {}
#end
