package backend.update;

import lime.net.HTTPRequest;
import lime.net.HTTPRequestHeader;

#if android
import lime.system.JNI;
#end

/**
 * HTTP that does not use haxe.Http / sys.net.Socket (hxcpp "Invalid socket handle").
 * Android uses system HttpURLConnection — Lime/curl often cannot resolve DNS.
 */
class SafeHttp
{
	#if android
	static var _hooks:Array<AndroidHttpHook> = [];
	#end

	public static function get(url:String, headers:Map<String, String>, onData:String->Void, onError:String->Void):Void
	{
		getFirst([url], headers, onData, onError);
	}

	public static function getFirst(urls:Array<String>, headers:Map<String, String>, onData:String->Void, onError:String->Void):Void
	{
		if (urls == null || urls.length == 0)
		{
			if (onError != null)
				onError("Empty URL");
			return;
		}

		var userAgent:String = "Further-Engine";
		if (headers != null && headers.exists("User-Agent"))
			userAgent = headers.get("User-Agent");

		tryNext(urls, 0, headers, userAgent, onData, onError, null);
	}

	static function tryNext(urls:Array<String>, index:Int, headers:Map<String, String>, userAgent:String,
		onData:String->Void, onError:String->Void, lastError:String):Void
	{
		if (index >= urls.length)
		{
			if (onError != null)
				onError(lastError != null ? lastError : "All URLs failed");
			return;
		}

		var url:String = urls[index];
		if (url == null || StringTools.trim(url) == "")
		{
			tryNext(urls, index + 1, headers, userAgent, onData, onError, lastError);
			return;
		}

		trace('[SafeHttp] GET ' + url);

		#if android
		androidGet(url, userAgent, function(data:String)
		{
			if (onData != null)
				onData(data != null ? data : "");
		}, function(err:String)
		{
			trace('[SafeHttp] fail (' + url + '): ' + err);
			tryNext(urls, index + 1, headers, userAgent, onData, onError, err);
		});
		#else
		limeGet(url, headers, userAgent, function(data:String)
		{
			if (onData != null)
				onData(data != null ? data : "");
		}, function(err:String)
		{
			trace('[SafeHttp] fail (' + url + '): ' + err);
			tryNext(urls, index + 1, headers, userAgent, onData, onError, err);
		});
		#end
	}

	#if android
	static function androidGet(url:String, userAgent:String, onData:String->Void, onError:String->Void):Void
	{
		try
		{
			var hook = new AndroidHttpHook(onData, onError);
			_hooks.push(hook);
			var fn = JNI.createStaticMethod("furtherengine/util/HttpUtil", "getAsync",
				"(Ljava/lang/String;Ljava/lang/String;ILorg/haxe/lime/HaxeObject;)V");
			fn(url, userAgent, 15000, hook);
		}
		catch (e:Dynamic)
		{
			trace('[SafeHttp] JNI HttpUtil yok, Lime HTTP deneniyor: ' + e);
			limeGet(url, null, userAgent, onData, onError);
		}
	}
	#end

	static function limeGet(url:String, headers:Map<String, String>, userAgent:String, onData:String->Void, onError:String->Void):Void
	{
		try
		{
			var req = new HTTPRequest<String>();
			req.timeout = 15000;
			req.followRedirects = true;
			req.headers = [];
			req.userAgent = userAgent;

			if (headers != null)
			{
				for (key in headers.keys())
				{
					if (key == "User-Agent")
						continue;
					req.headers.push(new HTTPRequestHeader(key, headers.get(key)));
				}
			}

			req.load(url).onComplete(function(data:String)
			{
				try
				{
					if (onData != null)
						onData(data != null ? data : "");
				}
				catch (e:Dynamic)
				{
					if (onError != null)
						onError(Std.string(e));
				}
			}).onError(function(err:Dynamic)
			{
				if (onError != null)
					onError(Std.string(err));
			});
		}
		catch (e:Dynamic)
		{
			if (onError != null)
				onError(Std.string(e));
		}
	}
}

#if android
@:keep
class AndroidHttpHook
{
	var _onData:String->Void;
	var _onError:String->Void;
	var _done:Bool = false;

	public function new(onData:String->Void, onError:String->Void)
	{
		_onData = onData;
		_onError = onError;
	}

	public function onOk(data:String):Void
	{
		if (_done)
			return;
		_done = true;
		if (_onData != null)
			_onData(data);
	}

	public function onFail(err:String):Void
	{
		if (_done)
			return;
		_done = true;
		if (_onError != null)
			_onError(err);
	}
}
#end
