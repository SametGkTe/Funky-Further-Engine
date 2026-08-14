package backend.modpack;

#if sys
import haxe.io.Bytes;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileOutput;
import sys.net.Host;
import sys.net.Socket;
#if target.threaded
import sys.thread.Thread;
#end
#end

typedef ParsedUrl = {
	scheme:String,
	host:String,
	port:Int,
	path:String
};

typedef DownloadProgress = {
	var downloadedBytes:Float;
	var totalBytes:Float;
	var percent:Float;
	var fileName:String;
	var speed:Float;
}

typedef DownloadCallbacks = {
	?onProgress:DownloadProgress->Void,
	?onComplete:String->Void,
	?onError:String->Void,
	?onCancelled:Void->Void
}

class DownloadManager {
	#if sys
	var _downloading:Bool = false;
	var _cancelled:Bool = false;

	static final BUFFER_SIZE:Int = 65536;
	static final MAX_REDIRECTS:Int = 5;
	static final CONNECT_TIMEOUT:Int = 15;
	static final READ_TIMEOUT:Int = 30;
	static final PROGRESS_INTERVAL:Float = 0.25;

	public function new() {}

	public function isDownloading():Bool {
		return _downloading;
	}

	public function cancel():Void {
		if (!_downloading) return;
		_cancelled = true;
		trace('[DownloadManager] İptal isteği.');
	}

	public function smartDownload(url:String, savePath:String, callbacks:DownloadCallbacks, ?expectedBytes:Float = -1):Void {
		if (url == null || url.length == 0) {
			safeError(callbacks, "İndirme URL'si boş.");
			return;
		}

		if (expectedBytes > 0) {
			var spaceError:Null<String> = StorageGuard.checkDownloadSpace(expectedBytes);
			if (spaceError != null) {
				trace('[DownloadManager] Alan kontrolü reddetti: $spaceError');
				safeError(callbacks, spaceError);
				return;
			}
		}

		if (isMediafirePage(url)) {
			resolveMediafire(url, savePath, callbacks);
			return;
		}

		if (StringTools.startsWith(url, "https://drive.google.com/file/d/")) {
			resolveGDrive(url, savePath, callbacks);
			return;
		}

		download(url, savePath, callbacks);
	}

	public static function isMediafirePage(url:String):Bool {
		if (url == null) return false;

		return StringTools.startsWith(url, "https://www.mediafire.com/file/")
			|| StringTools.startsWith(url, "http://www.mediafire.com/file/")
			|| StringTools.startsWith(url, "https://mediafire.com/file/")
			|| StringTools.startsWith(url, "http://mediafire.com/file/");
	}

	function resolveMediafire(pageUrl:String, savePath:String, callbacks:DownloadCallbacks):Void {
		trace('[DownloadManager] Mediafire linki çözülüyor: $pageUrl');

		#if target.threaded
		Thread.create(() -> {
			doResolveMediafire(pageUrl, savePath, callbacks);
		});
		#else
		doResolveMediafire(pageUrl, savePath, callbacks);
		#end
	}

	function doResolveMediafire(pageUrl:String, savePath:String, callbacks:DownloadCallbacks):Void {
		try {
			var pageHtml:String = fetchPageContent(pageUrl);

			if (pageHtml == null || pageHtml.length == 0) {
				finishError(callbacks, "Mediafire sayfası yüklenemedi.");
				return;
			}

			var realUrl:String = extractMediafireDownloadUrl(pageHtml);

			if (realUrl != null && realUrl.length > 0) {
				trace('[DownloadManager] Mediafire gerçek link: $realUrl');
				download(realUrl, savePath, callbacks);
				return;
			}

			finishError(callbacks,
				"Mediafire indirme linki çıkarılamadı.\n"
				+ "Mediafire sayfa yapısı değişmiş olabilir.");

		} catch (e:Dynamic) {
			finishError(callbacks, 'Mediafire çözümleme hatası: ${Std.string(e)}');
		}
	}

	function extractMediafireDownloadUrl(html:String):Null<String> {
		try {
			var doc = new htmlparser.HtmlDocument(html, true);

			for (node in doc.find('#downloadButton')) {
				if (node.hasAttribute('data-scrambled-url')) {
					var scrambled:String = node.getAttribute('data-scrambled-url');
					if (scrambled != null && scrambled.length > 10) {
						try {
							var decoded:String = haxe.crypto.Base64.decode(scrambled).toString();
							if (StringTools.startsWith(decoded, "http")) {
								trace('[DownloadManager] Mediafire link çözüldü (scrambled)');
								return decoded;
							}
						} catch (_) {}
					}
				}
			}
			for (node in doc.find('#downloadButton')) {
				if (node.hasAttribute('href')) {
					var href:String = node.getAttribute('href');
					if (href != null && StringTools.startsWith(href, "http")) {
						trace('[DownloadManager] Mediafire link çözüldü (href)');
						return href;
					}
				}
			}
			for (node in doc.find('a[aria-label="Download file"]')) {
				if (node.hasAttribute('href')) {
					var href:String = node.getAttribute('href');
					if (href != null && StringTools.startsWith(href, "http")) {
						trace('[DownloadManager] Mediafire link çözüldü (aria-label)');
						return href;
					}
				}
			}
			for (node in doc.find('.popsok')) {
				if (node.hasAttribute('href')) {
					var href:String = node.getAttribute('href');
					if (href != null && StringTools.startsWith(href, "http")) {
						trace('[DownloadManager] Mediafire link çözüldü (popsok)');
						return href;
					}
				}
			}

		} catch (e:Dynamic) {
			trace('[DownloadManager] HTML parse hatası: ${Std.string(e)}');
		}

		return null;
	}

	function resolveGDrive(url:String, savePath:String, callbacks:DownloadCallbacks):Void {
		var afterD:String = url.substr("https://drive.google.com/file/d/".length);
		var fileId:String = afterD.split("/")[0];

		if (fileId == null || fileId.length == 0) {
			safeError(callbacks, "Google Drive dosya ID'si bulunamadı.");
			return;
		}

		var directUrl:String = 'https://drive.usercontent.google.com/download?id=$fileId&export=download&confirm=t';
		trace('[DownloadManager] Google Drive link çözüldü: $directUrl');
		download(directUrl, savePath, callbacks);
	}

	function fetchPageContent(url:String, redirectCount:Int = 0):Null<String> {
		if (redirectCount >= MAX_REDIRECTS)
			return null;

		var parsed = parseUrl(url);
		if (parsed == null)
			return null;

		var useSSL:Bool = parsed.scheme == "https";
		var host:String = parsed.host;
		var port:Int = parsed.port;
		var path:String = parsed.path;

		var socket:Socket = null;

		try {
			if (useSSL) {
				#if (haxe_ver >= 4.0)
				socket = new sys.ssl.Socket();
				#else
				return null;
				#end
			} else {
				socket = new Socket();
			}

			socket.setTimeout(CONNECT_TIMEOUT);
			socket.connect(new Host(host), port);

			var request = 'GET $path HTTP/1.1\r\n'
				+ 'Host: $host\r\n'
				+ 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36\r\n'
				+ 'Accept: text/html,application/xhtml+xml\r\n'
				+ 'Accept-Language: en-US,en;q=0.9\r\n'
				+ 'Connection: close\r\n'
				+ '\r\n';

			socket.output.writeString(request);
			socket.output.flush();

			socket.setTimeout(READ_TIMEOUT);

			var headerResult = readHeaders(socket);
			if (headerResult == null) {
				closeSocket(socket);
				return null;
			}

			if (headerResult.statusCode >= 300 && headerResult.statusCode < 400) {
				var location = headerResult.headers.get("location");
				closeSocket(socket);

				if (location == null || location.length == 0)
					return null;

				if (StringTools.startsWith(location, "/")) {
					var scheme = useSSL ? "https" : "http";
					location = '$scheme://$host$location';
				}

				return fetchPageContent(location, redirectCount + 1);
			}

			if (headerResult.statusCode != 200) {
				closeSocket(socket);
				return null;
			}

			var contentLength:Int = -1;
			if (headerResult.headers.exists("content-length")) {
				var cl:Null<Int> = Std.parseInt(headerResult.headers.get("content-length"));
				contentLength = cl != null ? cl : -1;
			}

			var body = new StringBuf();
			var buffer = Bytes.alloc(8192);
			var totalRead:Int = 0;
			var maxRead:Int = 2 * 1024 * 1024;

			while (true) {
				var bytesRead:Int = 0;
				try {
					bytesRead = socket.input.readBytes(buffer, 0, 8192);
				} catch (e:haxe.io.Eof) {
					break;
				} catch (e:Dynamic) {
					break;
				}

				if (bytesRead <= 0) break;

				body.add(buffer.sub(0, bytesRead).toString());
				totalRead += bytesRead;

				if (totalRead >= maxRead) break;
				if (contentLength > 0 && totalRead >= contentLength) break;
			}

			closeSocket(socket);
			return body.toString();

		} catch (e:Dynamic) {
			closeSocket(socket);
			return null;
		}
	}

	public function fetchUrlText(url:String, onData:String->Void, onError:String->Void):Void {
		#if target.threaded
		Thread.create(() -> {
			doFetchUrlText(url, onData, onError);
		});
		#else
		doFetchUrlText(url, onData, onError);
		#end
	}

	function doFetchUrlText(url:String, onData:String->Void, onError:String->Void):Void {
		var content:Null<String> = fetchPageContent(url);
		if (content == null || content.length == 0) {
			if (onError != null) onError("Sayfa yüklenemedi: $url");
			return;
		}
		if (onData != null) onData(content);
	}

	public function download(url:String, savePath:String, callbacks:DownloadCallbacks):Void {
		if (_downloading) {
			safeError(callbacks, "Zaten bir indirme devam ediyor.");
			return;
		}

		if (url == null || url.length == 0) {
			safeError(callbacks, "İndirme URL'si boş.");
			return;
		}

		if (isMediafirePage(url)) {
			resolveMediafire(url, savePath, callbacks);
			return;
		}

		_downloading = true;
		_cancelled = false;

		trace('[DownloadManager] İndirme başladı: $url');

		var dir = Path.directory(savePath);
		if (dir != null && dir.length > 0) {
			try {
				ensureDirectoryRecursive(dir);
			} catch (e:Dynamic) {
				finishError(callbacks, 'Klasör oluşturulamadı: ${Std.string(e)}');
				return;
			}
		}

		#if target.threaded
		Thread.create(() -> {
			doStreamDownload(url, savePath, callbacks, 0);
		});
		#else
		doStreamDownload(url, savePath, callbacks, 0);
		#end
	}

	public function downloadFromGitHub(url:String, savePath:String, callbacks:DownloadCallbacks):Void {
		var fixedUrl = fixGitHubUrl(url);
		download(fixedUrl, savePath, callbacks);
	}

	function doStreamDownload(url:String, savePath:String, callbacks:DownloadCallbacks, redirectCount:Int):Void {
		if (redirectCount >= MAX_REDIRECTS) {
			finishError(callbacks, 'Çok fazla yönlendirme ($MAX_REDIRECTS). İndirme durduruldu.');
			return;
		}

		if (_cancelled) {
			finishCancel(callbacks);
			return;
		}

		var fileName = Path.withoutDirectory(savePath);

		var parsed = parseUrl(url);
		if (parsed == null) {
			finishError(callbacks, 'Geçersiz URL: $url');
			return;
		}

		var useSSL:Bool = parsed.scheme == "https";
		var host:String = parsed.host;
		var port:Int = parsed.port;
		var path:String = parsed.path;

		var socket:Socket = null;
		var fileOutput:FileOutput = null;

		try {
			if (useSSL) {
				#if (haxe_ver >= 4.0)
				socket = new sys.ssl.Socket();
				#else
				finishError(callbacks, 'HTTPS bu platformda desteklenmiyor.');
				return;
				#end
			} else {
				socket = new Socket();
			}

			socket.setTimeout(CONNECT_TIMEOUT);

			trace('[DownloadManager] Bağlanıyor: $host:$port');
			socket.connect(new Host(host), port);

			var request = 'GET $path HTTP/1.1\r\n'
				+ 'Host: $host\r\n'
				+ 'User-Agent: PsychEngineTR-Updater/1.0\r\n'
				+ 'Accept: */*\r\n'
				+ 'Connection: close\r\n'
				+ '\r\n';

			socket.output.writeString(request);
			socket.output.flush();

			socket.setTimeout(READ_TIMEOUT);

			var headerResult = readHeaders(socket);
			if (headerResult == null) {
				closeSocket(socket);
				finishError(callbacks, 'Sunucudan yanıt alınamadı.');
				return;
			}

			var statusCode:Int = headerResult.statusCode;
			var headers:Map<String, String> = headerResult.headers;
			var contentLength:Float = -1;

			if (headers.exists("content-length")) {
				contentLength = Std.parseFloat(headers.get("content-length"));
			}

			trace('[DownloadManager] HTTP $statusCode, Content-Length: $contentLength');

			if (statusCode >= 300 && statusCode < 400) {
				var location = headers.get("location");
				if (location == null || location.length == 0) {
					closeSocket(socket);
					finishError(callbacks, 'Yönlendirme yanıtında Location header yok.');
					return;
				}

				if (StringTools.startsWith(location, "/")) {
					var scheme = useSSL ? "https" : "http";
					location = '$scheme://$host$location';
				}

				trace('[DownloadManager] Yönlendirme → $location');
				closeSocket(socket);

				doStreamDownload(location, savePath, callbacks, redirectCount + 1);
				return;
			}

			if (statusCode < 200 || statusCode >= 300) {
				closeSocket(socket);
				finishError(callbacks, 'HTTP hata kodu: $statusCode');
				return;
			}

			fileOutput = File.write(savePath, true);

			var downloadedBytes:Float = 0;
			var startTime:Float = Sys.time();
			var lastProgressTime:Float = startTime;
			var buffer = Bytes.alloc(BUFFER_SIZE);

			while (true) {
				if (_cancelled) {
					closeFileOutput(fileOutput);
					closeSocket(socket);
					deleteFileSafe(savePath);
					finishCancel(callbacks);
					return;
				}

				var bytesRead:Int = 0;
				try {
					bytesRead = socket.input.readBytes(buffer, 0, BUFFER_SIZE);
				} catch (e:haxe.io.Eof) {
					break;
				} catch (e:Dynamic) {
					break;
				}

				if (bytesRead <= 0) break;

				fileOutput.writeBytes(buffer, 0, bytesRead);
				fileOutput.flush();
				downloadedBytes += bytesRead;

				var now = Sys.time();
				if (now - lastProgressTime >= PROGRESS_INTERVAL) {
					lastProgressTime = now;
					var elapsed = now - startTime;
					var speed:Float = elapsed > 0 ? downloadedBytes / elapsed : 0;
					var percent:Float = contentLength > 0 ? downloadedBytes / contentLength : 0;

					safeProgress(callbacks, {
						downloadedBytes: downloadedBytes,
						totalBytes: contentLength,
						percent: Math.min(percent, 1.0),
						fileName: fileName,
						speed: speed
					});
				}

				if (contentLength > 0 && downloadedBytes >= contentLength) break;
			}

			closeFileOutput(fileOutput);
			closeSocket(socket);

			if (!FileSystem.exists(savePath)) {
				finishError(callbacks, 'Dosya kaydedilemedi: $savePath');
				return;
			}

			var stat = FileSystem.stat(savePath);
			if (stat.size <= 0) {
				deleteFileSafe(savePath);
				finishError(callbacks, 'İndirilen dosya boş.');
				return;
			}

			if (looksLikeHtml(savePath)) {
				deleteFileSafe(savePath);
				finishError(callbacks,
					'Sunucu ZIP yerine HTML sayfa döndürdü. ' +
					'Bu link direkt indirme linki değil.');
				return;
			}

			var elapsed = Sys.time() - startTime;
			var speed:Float = elapsed > 0 ? downloadedBytes / elapsed : 0;
			safeProgress(callbacks, {
				downloadedBytes: downloadedBytes,
				totalBytes: downloadedBytes,
				percent: 1.0,
				fileName: fileName,
				speed: speed
			});

			_downloading = false;
			_cancelled = false;

			trace('[DownloadManager] ✓ İndirme tamamlandı: $savePath (${Std.int(downloadedBytes)} bytes, ${Std.int(speed / 1024)} KB/s)');

			if (callbacks != null && callbacks.onComplete != null)
				callbacks.onComplete(savePath);

		} catch (e:Dynamic) {
			closeFileOutput(fileOutput);
			closeSocket(socket);
			deleteFileSafe(savePath);
			finishError(callbacks, 'İndirme hatası: ${Std.string(e)}');
		}
	}

	function readHeaders(socket:Socket):Null<{statusCode:Int, headers:Map<String, String>}> {
		try {
			var statusLine = readLine(socket);
			if (statusLine == null) return null;

			var parts = statusLine.split(" ");
			if (parts.length < 2) return null;
			var parsedStatus:Null<Int> = Std.parseInt(parts[1]);
			var statusCode:Int = parsedStatus != null ? parsedStatus : 0;

			var headers = new Map<String, String>();
			while (true) {
				var line = readLine(socket);
				if (line == null || line.length == 0) break;

				var colonIdx = line.indexOf(":");
				if (colonIdx > 0) {
					var key = StringTools.trim(line.substr(0, colonIdx)).toLowerCase();
					var value = StringTools.trim(line.substr(colonIdx + 1));
					headers.set(key, value);
				}
			}

			return {statusCode: statusCode, headers: headers};
		} catch (e:Dynamic) {
			return null;
		}
	}

	function readLine(socket:Socket):Null<String> {
		var line = new StringBuf();
		try {
			while (true) {
				var byte = socket.input.readByte();
				if (byte == 10) break;
				else if (byte != 13) line.addChar(byte);
			}
		} catch (e:haxe.io.Eof) {
			if (line.length > 0) return line.toString();
			return null;
		} catch (e:Dynamic) {
			return null;
		}
		return line.toString();
	}

	function parseUrl(url:String):Null<ParsedUrl> {
		if (url == null) return null;

		var scheme = "http";
		var rest = url;

		if (StringTools.startsWith(rest, "https://")) {
			scheme = "https";
			rest = rest.substr(8);
		} else if (StringTools.startsWith(rest, "http://")) {
			scheme = "http";
			rest = rest.substr(7);
		}

		var pathStart = rest.indexOf("/");
		var hostPart:String;
		var path:String;

		if (pathStart == -1) {
			hostPart = rest;
			path = "/";
		} else {
			hostPart = rest.substr(0, pathStart);
			path = rest.substr(pathStart);
		}

		var host:String;
		var port:Int;

		var colonIdx = hostPart.indexOf(":");
		if (colonIdx != -1) {
			host = hostPart.substr(0, colonIdx);
			var parsedPort:Null<Int> = Std.parseInt(hostPart.substr(colonIdx + 1));
			port = parsedPort != null ? parsedPort : (scheme == "https" ? 443 : 80);
		} else {
			host = hostPart;
			port = scheme == "https" ? 443 : 80;
		}

		if (host.length == 0) return null;

		return {scheme: scheme, host: host, port: port, path: path};
	}

	function fixGitHubUrl(url:String):String {
		if (url == null) return url;

		if (url.indexOf("github.com") != -1 && url.indexOf("/blob/") != -1) {
			var fixed = StringTools.replace(url, "github.com", "raw.githubusercontent.com");
			fixed = StringTools.replace(fixed, "/blob/", "/");
			trace('[DownloadManager] GitHub URL düzeltildi: $fixed');
			return fixed;
		}

		return url;
	}

	function looksLikeHtml(filePath:String):Bool {
		try {
			var input = File.read(filePath, true);
			var sample = input.readString(256);
			input.close();

			var trimmed = StringTools.trim(sample).toLowerCase();
			return StringTools.startsWith(trimmed, "<!doctype html")
				|| StringTools.startsWith(trimmed, "<html")
				|| trimmed.indexOf("<head") != -1
				|| trimmed.indexOf("<body") != -1;
		} catch (e:Dynamic) {
			return false;
		}
	}

	function ensureDirectoryRecursive(path:String):Void {
		if (path == null || path.length == 0) return;
		if (FileSystem.exists(path)) return;

		var parent = Path.directory(path);
		if (parent != null && parent.length > 0 && parent != path)
			ensureDirectoryRecursive(parent);

		if (!FileSystem.exists(path))
			FileSystem.createDirectory(path);
	}

	function closeSocket(socket:Socket):Void {
		if (socket == null) return;
		try { socket.close(); } catch (_) {}
	}

	function closeFileOutput(output:FileOutput):Void {
		if (output == null) return;
		try { output.flush(); } catch (_) {}
		try { output.close(); } catch (_) {}
	}

	function deleteFileSafe(path:String):Void {
		try {
			if (FileSystem.exists(path))
				FileSystem.deleteFile(path);
		} catch (_) {}
	}

	function safeError(callbacks:DownloadCallbacks, msg:String):Void {
		if (callbacks != null && callbacks.onError != null)
			callbacks.onError(msg);
	}

	function safeProgress(callbacks:DownloadCallbacks, progress:DownloadProgress):Void {
		if (callbacks != null && callbacks.onProgress != null)
			callbacks.onProgress(progress);
	}

	function finishError(callbacks:DownloadCallbacks, msg:String):Void {
		_downloading = false;
		_cancelled = false;
		trace('[DownloadManager] ✗ $msg');
		safeError(callbacks, msg);
	}

	function finishCancel(callbacks:DownloadCallbacks):Void {
		_downloading = false;
		_cancelled = false;
		trace('[DownloadManager] İptal edildi.');
		if (callbacks != null && callbacks.onCancelled != null)
			callbacks.onCancelled();
	}

	#else

	public function new() {}
	public function isDownloading():Bool return false;
	public function cancel():Void {}

	public function download(url:String, savePath:String, callbacks:DownloadCallbacks):Void {
		if (callbacks != null && callbacks.onError != null)
			callbacks.onError("Bu platformda indirme desteklenmiyor.");
	}

	public function smartDownload(url:String, savePath:String, callbacks:DownloadCallbacks, ?expectedBytes:Float = -1):Void {
		download(url, savePath, callbacks);
	}

	public function downloadFromGitHub(url:String, savePath:String, callbacks:DownloadCallbacks):Void {
		download(url, savePath, callbacks);
	}

	public function fetchUrlText(url:String, onData:String->Void, onError:String->Void):Void {
		if (onError != null) onError("Bu platformda istek desteklenmiyor.");
	}
	#end
}
