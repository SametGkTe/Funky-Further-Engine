package furtherengine.util;

import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;

import org.haxe.extension.Extension;

/**
 * Opens the All Files Access settings page with the package URI.
 * A missing package: URI is a common reason the toggle appears disabled.
 */
public class StoragePermissionUtil
{
	public static void openAllFilesSettings()
	{
		if (Extension.mainActivity == null)
			return;

		String pkg = Extension.mainActivity.getPackageName();

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R)
		{
			try
			{
				Intent intent = new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION);
				intent.setData(Uri.parse("package:" + pkg));
				intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
				Extension.mainActivity.startActivity(intent);
				return;
			}
			catch (Exception ignored)
			{
			}

			try
			{
				Intent intent = new Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION);
				intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
				Extension.mainActivity.startActivity(intent);
				return;
			}
			catch (Exception ignored)
			{
			}
		}

		try
		{
			Intent intent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
			intent.setData(Uri.parse("package:" + pkg));
			intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
			Extension.mainActivity.startActivity(intent);
		}
		catch (Exception ignored)
		{
		}
	}
}
