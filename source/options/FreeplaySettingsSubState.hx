package options;

import backend.freeplay.FreeplayCatalog;

class FreeplaySettingsSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = Language.getPhrase('freeplay_settings', 'Freeplay Ayarlari');
		rpcTitle = 'Freeplay Settings';

		var option:Option = new Option(
			Language.getPhrase('setting_quick_freeplay', 'Daha Hizli Freeplay'),
			Language.getPhrase('description_quick_freeplay',
				"Dikkatli kullanin: listeyi cok daha hizli acar.\nChart klasoru taranmaz, zorluklar week dosyasindan gelir.\nMod / modpack degisince liste otomatik yenilenir."),
			'quickFreeplay',
			BOOL
		);
		option.onChange = onFreeplayPrefChanged;
		addOption(option);

		var listing:Option = new Option(
			Language.getPhrase('setting_freeplay_listing', 'Listeleme:'),
			Language.getPhrase('description_freeplay_listing',
				"Sarkilari nasil gruplamak istediginizi secin.\nModpack: kurulu paketlere gore\nModlar: her moda gore\nOrjinal: duz liste"),
			'freeplayListing',
			DROPDOWN,
			['original', 'mods', 'modpack'],
			'freeplay_listing'
		);
		listing.dropdownLabels = [
			Language.getPhrase('freeplay_listing_original', 'Orjinal'),
			Language.getPhrase('freeplay_listing_mods', 'Modlara gore'),
			Language.getPhrase('freeplay_listing_modpack', 'Modpack e gore')
		];
		listing.onChange = onFreeplayPrefChanged;
		addOption(listing);

		var hideOther:Option = new Option(
			Language.getPhrase('setting_hide_other_mods', 'Diger Modlari Gizle'),
			Language.getPhrase('description_hide_other_mods',
				"Modpack listesinde pakete girmeyen leftover / Diger Modlar grubunu gizler.\nSadece Listeleme: Modpack e gore iken gecerli."),
			'freeplayHideOtherMods',
			BOOL
		);
		hideOther.onChange = onFreeplayPrefChanged;
		addOption(hideOther);

		super();
	}

	function onFreeplayPrefChanged():Void
	{
		FreeplayCatalog.markDirty();
		ClientPrefs.saveSettings();
	}
}
