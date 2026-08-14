package backend.modpack.zip;

class ZipExtractorFactory {
	public static function create():IZipExtractor {
		#if sys

		return new SystemZipExtractor();
		#else
		return new UnsupportedZipExtractor(
			"Bu platformda ZIP çıkarma desteklenmiyor (sys gerekli)."
		);
		#end
	}

	public static function createSafe():IZipExtractor {
		var extractor = create();

		if (!extractor.isSupported()) {
			trace('[ZipExtractorFactory] ${extractor.getBackendName()} desteklenmiyor, unsupported döndürüldü.');
			return new UnsupportedZipExtractor(
				'Platform (${extractor.getBackendName()}) ZIP çıkarmayı desteklemiyor.'
			);
		}

		trace('[ZipExtractorFactory] Backend: ${extractor.getBackendName()}');
		return extractor;
	}
}
