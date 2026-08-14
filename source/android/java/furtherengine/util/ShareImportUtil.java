package furtherengine.util;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.provider.OpenableColumns;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

import org.haxe.extension.Extension;

/**
 * Copies a shared/opened ZIP from ACTION_SEND / ACTION_VIEW into app cache
 * and returns the local path. Clears the intent so it is not imported twice.
 */
public class ShareImportUtil
{
	public static String consumeSharedZip()
	{
		Activity activity = Extension.mainActivity;
		if (activity == null)
			return null;

		Intent intent = activity.getIntent();
		if (intent == null)
			return null;

		String action = intent.getAction();
		Uri uri = null;

		if (Intent.ACTION_SEND.equals(action))
		{
			uri = intent.getParcelableExtra(Intent.EXTRA_STREAM);
		}
		else if (Intent.ACTION_VIEW.equals(action) || Intent.ACTION_EDIT.equals(action))
		{
			uri = intent.getData();
		}

		if (uri == null)
			return null;

		String name = queryDisplayName(activity, uri);
		if (name == null || name.length() < 1)
			name = "shared-mod.zip";
		if (!name.toLowerCase().endsWith(".zip"))
			name = name + ".zip";

		File outDir = new File(activity.getCacheDir(), "shared-import");
		if (!outDir.exists() && !outDir.mkdirs())
			return null;

		File outFile = new File(outDir, sanitize(name));

		try
		{
			ContentResolver resolver = activity.getContentResolver();
			InputStream input = resolver.openInputStream(uri);
			if (input == null)
				return null;

			OutputStream output = new FileOutputStream(outFile);
			byte[] buffer = new byte[8192];
			int read;
			while ((read = input.read(buffer)) != -1)
				output.write(buffer, 0, read);
			output.flush();
			output.close();
			input.close();
		}
		catch (Exception e)
		{
			return null;
		}

		intent.setAction(null);
		intent.setData(null);
		intent.removeExtra(Intent.EXTRA_STREAM);
		activity.setIntent(intent);

		return outFile.getAbsolutePath();
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
				if (index >= 0)
					return cursor.getString(index);
			}
		}
		catch (Exception ignored)
		{
		}
		finally
		{
			if (cursor != null)
				cursor.close();
		}

		String path = uri.getLastPathSegment();
		return path;
	}

	private static String sanitize(String name)
	{
		return name.replaceAll("[\\\\/:*?\"<>|]", "_");
	}
}
