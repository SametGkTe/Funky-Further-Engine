package furtherengine.util;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

import org.haxe.extension.Extension;
import org.haxe.lime.HaxeObject;

/**
 * Android system HTTP. Lime/curl on hxcpp often fails with
 * "Couldn't resolve host name" even when the phone is online.
 */
public class HttpUtil
{
	public static void getAsync(final String url, final String userAgent, final int timeoutMs, final HaxeObject callback)
	{
		new Thread(new Runnable()
		{
			@Override
			public void run()
			{
				String body = null;
				String error = null;
				try
				{
					body = getSync(url, userAgent, timeoutMs);
				}
				catch (Exception e)
				{
					error = e.getMessage();
					if (error == null || error.length() == 0)
						error = e.getClass().getSimpleName();
				}

				final String okBody = body;
				final String errMsg = error;
				if (Extension.callbackHandler == null)
					return;

				Extension.callbackHandler.post(new Runnable()
				{
					@Override
					public void run()
					{
						if (callback == null)
							return;
						try
						{
							if (errMsg != null)
								callback.call("onFail", new Object[] { errMsg });
							else
								callback.call("onOk", new Object[] { okBody != null ? okBody : "" });
						}
						catch (Exception ignored)
						{
						}
					}
				});
			}
		}).start();
	}

	public static String getSync(String urlString, String userAgent, int timeoutMs) throws Exception
	{
		if (urlString == null || urlString.length() == 0)
			throw new Exception("Empty URL");

		HttpURLConnection conn = null;
		int hops = 0;
		String current = urlString;

		while (hops < 8)
		{
			URL url = new URL(current);
			conn = (HttpURLConnection) url.openConnection();
			conn.setInstanceFollowRedirects(false);
			conn.setConnectTimeout(timeoutMs);
			conn.setReadTimeout(timeoutMs);
			conn.setRequestMethod("GET");
			conn.setUseCaches(false);
			conn.setDoInput(true);
			if (userAgent != null && userAgent.length() > 0)
				conn.setRequestProperty("User-Agent", userAgent);
			conn.setRequestProperty("Accept", "*/*");

			int code = conn.getResponseCode();
			if (code >= 300 && code < 400)
			{
				String loc = conn.getHeaderField("Location");
				conn.disconnect();
				if (loc == null || loc.length() == 0)
					throw new Exception("HTTP " + code + " redirect without Location");
				current = loc;
				hops++;
				continue;
			}

			InputStream stream = (code >= 200 && code < 300) ? conn.getInputStream() : conn.getErrorStream();
			String text = readAll(stream);
			conn.disconnect();

			if (code < 200 || code >= 300)
				throw new Exception("HTTP " + code + (text != null && text.length() > 0 ? (": " + text) : ""));

			return text != null ? text : "";
		}

		if (conn != null)
			conn.disconnect();
		throw new Exception("Too many redirects");
	}

	private static String readAll(InputStream stream) throws Exception
	{
		if (stream == null)
			return "";
		BufferedReader reader = new BufferedReader(new InputStreamReader(stream, StandardCharsets.UTF_8));
		StringBuilder sb = new StringBuilder();
		char[] buf = new char[4096];
		int n;
		while ((n = reader.read(buf)) != -1)
			sb.append(buf, 0, n);
		reader.close();
		return sb.toString();
	}
}
