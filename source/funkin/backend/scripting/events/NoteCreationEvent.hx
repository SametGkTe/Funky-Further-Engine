package funkin.backend.scripting.events;

import objects.Note;

final class NoteCreationEvent extends CancellableEvent {
	/**
	 * Note that is being created
	 */
	public var note:Note;

	/**
	 * Note Type (ex: "My Super Cool Note", or "Mine")
	 */
	public var noteType:String;

	/**
	 * ID of the player.
	 */
	public var strumLineID:Int;

	/**
	 * Whenever the note will need to be hit by the player
	 */
	public var mustHit:Bool;

	/**
	 * Sing animation suffix. "-alt" for alt anim or "" for normal notes.
	 */
	public var animSuffix:String;
}