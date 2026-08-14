package furtherengine.util;

import android.content.Intent;
import android.net.Uri;
import android.provider.DocumentsContract;

import java.io.File;

import org.haxe.extension.Extension;

/**
 * Opens the system Files / DocumentsUI root for Further Engine,
 * matching official FNF's "Open Data Folder" flow.
 */
public class DataFolderUtil
{
	public static void openDataFolder()
	{
		if (Extension.mainActivity == null || Extension.mainContext == null)
			return;

		File filesDir = Extension.mainContext.getExternalFilesDir(null);
		if (filesDir == null)
			return;

		File parent = filesDir.getParentFile();
		File root = parent != null ? parent : filesDir;
		String rootId = root.getAbsolutePath();
		String authority = "::APP_PACKAGE::.documentsprovider";

		Uri rootUri = DocumentsContract.buildRootUri(authority, rootId);

		Intent intent = new Intent(Intent.ACTION_VIEW);
		intent.setDataAndType(rootUri, DocumentsContract.Root.MIME_TYPE_ITEM);
		intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
		intent.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
		intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);

		try
		{
			Extension.mainActivity.startActivity(intent);
			return;
		}
		catch (Exception ignored)
		{
		}

		intent = new Intent(Intent.ACTION_VIEW);
		intent.setDataAndType(DocumentsContract.buildRootUri(authority, ""), "vnd.android.document/directory");
		intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
		intent.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
		intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);

		try
		{
			Extension.mainActivity.startActivity(intent);
			return;
		}
		catch (Exception ignored)
		{
		}

		try
		{
			Intent picker = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
			picker.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
			picker.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
			picker.addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
			Extension.mainActivity.startActivity(picker);
		}
		catch (Exception ignored)
		{
		}
	}
}
