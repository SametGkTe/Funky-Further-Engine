package backend;

/**
 * Audio mixer kanalı.
 */
@:enum
abstract AudioChannel(String)
{
	public var MASTER = 'master';
	public var MUSIC  = 'music';
	public var INST   = 'inst';
	public var VOICES = 'voices';
	public var HIT    = 'hitSfx';
	public var UI     = 'ui';
	public var SFX    = 'sfx';
}
