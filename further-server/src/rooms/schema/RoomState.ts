import { Schema, MapSchema, ArraySchema, type } from "@colyseus/schema";
import { PlayerState } from "./PlayerState";

export class RoomState extends Schema {
  @type("string") song: string = "";
  @type("string") folder: string = "";
  @type("number") diff: number = 1;
  @type({ array: "string" }) diffList = new ArraySchema<string>();
  /** MD5 of raw chart JSON — both clients must match */
  @type("string") chartHash: string = "";

  @type("string") host: string = "";
  @type("boolean") isStarted: boolean = false;

  /** Shared health bar 0..2, start at 1 */
  @type("number") health: number = 1;

  @type({ map: PlayerState }) players = new MapSchema<PlayerState>();
}
