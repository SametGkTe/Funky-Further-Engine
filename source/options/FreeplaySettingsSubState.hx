package options;

import backend.freeplay.FreeplayCatalog;

class FreeplaySettingsSubState extends BaseOptionsMenu
{
	public function new()
	{
		Mods.clearMenuMod();

		title = Language.getPhrase('freeplay_settings', 'Freeplay Ayarları');
		rpcTitle = 'Freeplay Settings';

		var option:Option = new Option(
			Language.getPhrase('setting_quick_freeplay', 'Daha Hizlı Freeplay'),
			Language.getPhrase('description_quick_freeplay',
				"Akitf Edilirse, Şarkı listesini çok daha hızlı açar.\nChart Klasörlerini taranmaz, zorluklar week dosyasından gelir. /nDİKKATLİ KULLANIN"),
			'quickFreeplay',
			BOOL
		);
		option.onChange = onFreeplayPrefChanged;
		addOption(option);

		var listing:Option = new Option(
			Language.getPhrase('setting_freeplay_listing', 'Freeplay Listeleme:'),
			Language.getPhrase('description_freeplay_listing',
				"Şarkıların nasıl gruplanmasını seçin."),
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
			Language.getPhrase('setting_hide_other_mods', 'Diğer Modları Gizle'),
			Language.getPhrase('description_hide_other_mods',
				"Aktif Edilirse, Modpack listesinde olmayan Modları göstermez."),
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
