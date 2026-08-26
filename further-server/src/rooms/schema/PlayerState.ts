import { Schema, type } from "@colyseus/schema";

/**
 * Minimal 1v1 player state for Further Online MVP.
 * Inspired by Psych Online's Player schema — intentionally smaller.
 */
export class PlayerState extends Schema {
  @type("string") name: string = "Player";
  @type("number") ping: number = 0;

  /** true = BF / right side, false = opponent / left side */
  @type("boolean") bfSide: boolean = true;

  @type("boolean") hasSong: boolean = false;
  @type("boolean") isReady: boolean = false;
  /** PlayState finished loading; waiting for mutual startSong */
  @type("boolean") hasLoaded: boolean = false;
  @type("boolean") hasEnded: boolean = false;

  @type("number") score: number = 0;
  @type("number") misses: number = 0;
  @type("number") sicks: number = 0;
  @type("number") goods: number = 0;
  @type("number") bads: number = 0;
  @type("number") shits: number = 0;
  @type("number") maxCombo: number = 0;
}
