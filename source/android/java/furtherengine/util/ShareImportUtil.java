package furtherengine.util;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.provider.OpenableColumns;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.security.MessageDigest;

import org.haxe.extension.Extension;

/**
 * ACTION_SEND / ACTION_VIEW ile gelen ZIP'i uygulama cache'ine kopyalar.
 * Android bazı cihazlarda task'ın ilk share intent'ini process yeniden açıldığında
 * tekrar verebildiği için içerik SHA-256 değeri kalıcı olarak tekilleştirilir.
 */
public class ShareImportUtil extends Extension
{
	private static volatile Intent pendingIntent = null;
	private static final String PREFS = "further_shared_imports";
	private static final String HANDLED_HASHES = "handled_sha256";
	private static final int MAX_HANDLED = 64;

	@Override public void onCreate(Bundle state)
	{
		// Soğuk açılışta share intent'i activity üzerinde bulunur.
		if (Extension.mainActivity != null) pendingIntent = Extension.mainActivity.getIntent();
	}

	@Override public void onNewIntent(Intent intent)
	{
		// Oyun arka plandayken paylaşılan yeni ZIP GameActivity tarafından bu
		// extension'a iletilir. getIntent() tek başına yeni intent'i göstermeyebilir.
		pendingIntent = intent;
		if (Extension.mainActivity != null) Extension.mainActivity.setIntent(intent);
	}

	public static String consumeSharedZip()
	{
		Activity activity = Extension.mainActivity;
		if (activity == null) return null;

		Intent intent = pendingIntent;
		if (intent == null) intent = activity.getIntent();
		if (intent == null) return null;
		// Aynı process'teki bir sonraki poll bu nesneyi tekrar tüketmesin.
		pendingIntent = null;

		String action = intent.getAction();
		Uri uri = null;
		if (Intent.ACTION_SEND.equals(action))
			uri = intent.getParcelableExtra(Intent.EXTRA_STREAM);
		else if (Intent.ACTION_VIEW.equals(action) || Intent.ACTION_EDIT.equals(action))
			uri = intent.getData();

		if (uri == null) return null;

		String name = queryDisplayName(activity, uri);
		if (name == null || name.length() < 1) name = "shared-mod.zip";
		if (!name.toLowerCase().endsWith(".zip")) name += ".zip";

		File outDir = new File(activity.getCacheDir(), "shared-import");
		if (!outDir.exists() && !outDir.mkdirs())
		{
			clearShareIntent(activity);
			return null;
		}
		File outFile = new File(outDir, sanitize(name));
		String sha256 = null;

		try
		{
			MessageDigest digest = MessageDigest.getInstance("SHA-256");
			ContentResolver resolver = activity.getContentResolver();
			InputStream input = resolver.openInputStream(uri);
			if (input == null) return null;

			OutputStream output = new FileOutputStream(outFile);
			byte[] buffer = new byte[8192];
			int read;
			while ((read = input.read(buffer)) != -1)
			{
				output.write(buffer, 0, read);
				digest.update(buffer, 0, read);
			}
			output.flush();
			output.close();
			input.close();
			sha256 = toHex(digest.digest());
		}
		catch (Exception e)
		{
			if (outFile.exists()) outFile.delete();
			return null;
		}
		finally
		{
			// Aynı process içinde focus/state poll'larının intent'i tekrar görmesini önle.
			clearShareIntent(activity);
		}

		if (sha256 == null || sha256.length() == 0)
		{
			outFile.delete();
			return null;
		}

		// Task/base intent Android tarafından sonraki process açılışında yeniden
		// teslim edilse bile aynı ZIP yalnızca bir kez installer'a gönderilir.
		if (wasHandled(activity, sha256))
		{
			outFile.delete();
			return null;
		}
		markHandled(activity, sha256);
		return outFile.getAbsolutePath();
	}

	private static void clearShareIntent(Activity activity)
	{
		try
		{
			Intent clean = new Intent(Intent.ACTION_MAIN);
			clean.setPackage(activity.getPackageName());
			activity.setIntent(clean);
		}
		catch (Exception ignored) {}
	}

	private static boolean wasHandled(Context context, String hash)
	{
		String stored = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(HANDLED_HASHES, "");
		if (stored.length() == 0) return false;
		for (String item : stored.split("\\n"))
			if (hash.equals(item)) return true;
		return false;
	}

	private static void markHandled(Context context, String hash)
	{
		SharedPreferences prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
		String stored = prefs.getString(HANDLED_HASHES, "");
		String[] old = stored.length() == 0 ? new String[0] : stored.split("\\n");
		StringBuilder next = new StringBuilder();
		int start = Math.max(0, old.length - (MAX_HANDLED - 1));
		for (int i = start; i < old.length; i++)
		{
			if (old[i].length() == 0 || old[i].equals(hash)) continue;
			if (next.length() > 0) next.append('\n');
			next.append(old[i]);
		}
		if (next.length() > 0) next.append('\n');
		next.append(hash);
		// commit senkron kullanılır: process hemen kapanırsa kayıt kaybolmasın.
		prefs.edit().putString(HANDLED_HASHES, next.toString()).commit();
	}

	private static String toHex(byte[] bytes)
	{
		StringBuilder result = new StringBuilder(bytes.length * 2);
		for (byte b : bytes) result.append(String.format("%02x", b & 0xff));
		return result.toString();
	}

	private static String queryDisplayName(Activity activity, Uri uri)
	{
		Cursor cursor = null;
		try
		{
			cursor = activity.getContentResolver().query(uri, new String[] { OpenableColumns.DISPLAY_NAME }, null, null, null);
			if (cursor != null && cursor.moveToFirst())
			{
				int index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
				if (index >= 0) return cursor.getString(index);
			}
		}
		catch (Exception ignored) {}
		finally { if (cursor != null) cursor.close(); }
		return uri.getLastPathSegment();
	}

	private static String sanitize(String name)
	{
		return name.replaceAll("[\\\\/:*?\"<>|]", "_");
	}
}
