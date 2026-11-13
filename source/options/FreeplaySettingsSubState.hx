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

		var keepCache:Option = new Option(
			Language.getPhrase('setting_freeplay_cache', 'Freeplay Bellekte Tutulsun'),
			Language.getPhrase('description_freeplay_cache',
				"Açıksa Freeplay grafiklerini (DJ, kartlar, seçim ekranı) bellekten silmez; Freeplay her açıldığında yeniden yüklemek zorunda kalmaz.\nÇOK hızlandırır ama RAM kullanımını artırır. Zayıf cihazlarda kapalı tut."),
			'freeplayCache',
			BOOL,
			null,
			'freeplay_cache'
		);
		addOption(keepCache);

		var fastFs:Option = new Option(
			Language.getPhrase('setting_fast_fs', 'Hızlı Dosya Sistemi'),
			Language.getPhrase('description_fast_fs',
				"Dizin listelerini bellekte tutar; menüler ve Freeplay çok daha hızlı açılır.\nHarici depolamada (EXTERNAL_PE) fark çok büyüktür.\nBir sorun görürsen kapat."),
			'fastFS',
			BOOL,
			null,
			'fast_fs'
		);
		fastFs.onChange = function()
		{
			#if sys
			backend.fs.DirCache.enabled = ClientPrefs.data.fastFS;
			backend.fs.DirCache.invalidateAll();
			#end
			ClientPrefs.saveSettings();
		};
		addOption(fastFs);

		super();
	}

	function onFreeplayPrefChanged():Void
	{
		FreeplayCatalog.invalidate();
		FreeplayCatalog.markDirty();
		ClientPrefs.saveSettings();
	}
}
