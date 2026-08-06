package options;

class PETSettingsState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'P.E.T Ayarlari';
		rpcTitle = 'P.E.T Ayarları Menüsünde';

		var option:Option = new Option(
			'P.E.T Filigrani',
			'Aktif edildiğinde, sol üstte tarafta Psych Engine Türkiye filigranı aktif hale gelir.',
			'petwatermark',
			'bool'
		);
		addOption(option);

		option = new Option(
			'P.E.T Yükleme Ekrani',
			'Aktif edildiğinde, P.E.T yükleme ekranlarını etkinleştirir.',
			'petloadingscreen',
			'bool'
		);
		addOption(option);

		option = new Option(
			'P.E.T Logo Stili:',
			'Filigrandaki logoyu seçin.',
			'petwatermarklogo',
			'string',
			['V1', 'V2', 'V2U', 'ONLINE']
		);
		addOption(option);

		option = new Option(
			'P.E.T Yükleme Ekranı Stili:',
			'P.E.T.O nun Kullanacağı Yükleme ekranı Stilini seçin seçin.',
			'petloadingscreenimage',
			'string',
			['V1', 'V2', 'V2U', 'ONLINE']
		);
		addOption(option);
		
		option = new Option(
			'Introyu Kapat',
			'Aktif edildiğinde, Oyunun başlangıcında oynatılan Intro videosu devre-dışı bırakılır.',
			'disableIntroVideo',
			'bool'
		);
		addOption(option);

		super();
	}
}
