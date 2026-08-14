package org.haxe.lime;

import android.content.res.AssetFileDescriptor;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.graphics.Point;
import android.os.CancellationSignal;
import android.os.ParcelFileDescriptor;
import android.provider.DocumentsContract.Document;
import android.provider.DocumentsContract.Root;
import android.provider.DocumentsProvider;
import android.webkit.MimeTypeMap;

import ::APP_PACKAGE::.R;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.Collections;
import java.util.LinkedList;

/**
 * DocumentsProvider that exposes Android/data/::APP_PACKAGE::/
 * in the system Files app sidebar (same approach as official FNF).
 */
public class StorageProvider extends DocumentsProvider
{
	private static File BASE_DIR;
	private static String BASE_DIR_PATH;

	private static final String[] DEFAULT_ROOT_PROJECTION = new String[] {
		Root.COLUMN_ROOT_ID,
		Root.COLUMN_MIME_TYPES,
		Root.COLUMN_FLAGS,
		Root.COLUMN_ICON,
		Root.COLUMN_TITLE,
		Root.COLUMN_SUMMARY,
		Root.COLUMN_DOCUMENT_ID,
		Root.COLUMN_AVAILABLE_BYTES
	};

	private static final String[] DEFAULT_DOCUMENT_PROJECTION = new String[] {
		Document.COLUMN_DOCUMENT_ID,
		Document.COLUMN_MIME_TYPE,
		Document.COLUMN_DISPLAY_NAME,
		Document.COLUMN_LAST_MODIFIED,
		Document.COLUMN_FLAGS,
		Document.COLUMN_SIZE
	};

	public static File getBaseDir()
	{
		return BASE_DIR;
	}

	@Override
	public boolean onCreate()
	{
		File filesDir = getContext().getExternalFilesDir(null);
		if (filesDir == null)
			return false;

		File parent = filesDir.getParentFile();
		BASE_DIR = parent != null ? parent : filesDir;

		try
		{
			BASE_DIR_PATH = BASE_DIR.getCanonicalPath();
		}
		catch (IOException e)
		{
			BASE_DIR_PATH = BASE_DIR.getAbsolutePath();
		}

		return true;
	}

	@Override
	public Cursor queryRoots(String[] projection)
	{
		final MatrixCursor result = new MatrixCursor(projection != null ? projection : DEFAULT_ROOT_PROJECTION);

		if (BASE_DIR == null)
			return result;

		final MatrixCursor.RowBuilder row = result.newRow();
		row.add(Root.COLUMN_ROOT_ID, getDocIdForFile(BASE_DIR));
		row.add(Root.COLUMN_DOCUMENT_ID, getDocIdForFile(BASE_DIR));
		row.add(Root.COLUMN_SUMMARY, "Data Folder");
		row.add(Root.COLUMN_FLAGS, Root.FLAG_SUPPORTS_CREATE | Root.FLAG_SUPPORTS_SEARCH | Root.FLAG_SUPPORTS_IS_CHILD);
		row.add(Root.COLUMN_TITLE, "::APP_TITLE::");
		row.add(Root.COLUMN_MIME_TYPES, "*/*");
		row.add(Root.COLUMN_AVAILABLE_BYTES, BASE_DIR.getFreeSpace());
		row.add(Root.COLUMN_ICON, R.drawable.icon);

		return result;
	}

	@Override
	public Cursor queryDocument(String documentId, String[] projection) throws FileNotFoundException
	{
		final MatrixCursor result = new MatrixCursor(projection != null ? projection : DEFAULT_DOCUMENT_PROJECTION);
		includeFile(result, documentId, null);
		return result;
	}

	@Override
	public Cursor queryChildDocuments(String parentDocumentId, String[] projection, String sortOrder) throws FileNotFoundException
	{
		final MatrixCursor result = new MatrixCursor(projection != null ? projection : DEFAULT_DOCUMENT_PROJECTION);
		File parent = getFileForDocId(parentDocumentId);

		if (parent != null)
		{
			File[] children = null;
			try
			{
				children = parent.listFiles();
			}
			catch (SecurityException e)
			{
				children = new File[0];
			}

			if (children != null)
			{
				for (File file : children)
					includeFile(result, null, file);
			}
		}

		return result;
	}

	@Override
	public ParcelFileDescriptor openDocument(String documentId, String mode, CancellationSignal signal) throws FileNotFoundException
	{
		return ParcelFileDescriptor.open(getFileForDocId(documentId), ParcelFileDescriptor.parseMode(mode));
	}

	@Override
	public AssetFileDescriptor openDocumentThumbnail(String documentId, Point sizeHint, CancellationSignal signal) throws FileNotFoundException
	{
		final File file = getFileForDocId(documentId);
		final ParcelFileDescriptor pfd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY);
		return new AssetFileDescriptor(pfd, 0, file.length());
	}

	@Override
	public String createDocument(String parentDocumentId, String mimeType, String displayName) throws FileNotFoundException
	{
		File parentFile = getFileForDocId(parentDocumentId);
		File newFile = new File(parentFile, displayName);

		int noConflictId = 2;
		while (newFile.exists())
			newFile = new File(parentFile, displayName + " (" + noConflictId++ + ")");

		try
		{
			boolean succeeded;
			if (Document.MIME_TYPE_DIR.equals(mimeType))
				succeeded = newFile.mkdir();
			else
				succeeded = newFile.createNewFile();

			if (!succeeded)
				throw new FileNotFoundException("Failed to create document with id " + newFile.getPath());
		}
		catch (IOException e)
		{
			throw new FileNotFoundException("Failed to create document with id " + newFile.getPath());
		}

		return getDocIdForFile(newFile);
	}

	@Override
	public void deleteDocument(String documentId) throws FileNotFoundException
	{
		if (!deleteRecursive(getFileForDocId(documentId)))
			throw new FileNotFoundException("Failed to delete document with id " + documentId);
	}

	@Override
	public String getDocumentType(String documentId) throws FileNotFoundException
	{
		return getMimeType(getFileForDocId(documentId));
	}

	@Override
	public Cursor querySearchDocuments(String rootId, String query, String[] projection) throws FileNotFoundException
	{
		final MatrixCursor result = new MatrixCursor(projection != null ? projection : DEFAULT_DOCUMENT_PROJECTION);
		final LinkedList<File> pending = new LinkedList<File>();
		pending.add(getFileForDocId(rootId));

		final int MAX_SEARCH_RESULTS = 50;
		final String needle = query != null ? query.toLowerCase() : "";

		while (!pending.isEmpty() && result.getCount() < MAX_SEARCH_RESULTS)
		{
			final File file = pending.removeFirst();
			boolean isInsideHome;

			try
			{
				isInsideHome = file.getCanonicalPath().startsWith(BASE_DIR_PATH);
			}
			catch (IOException e)
			{
				isInsideHome = true;
			}

			if (!isInsideHome)
				continue;

			if (file.isDirectory())
			{
				try
				{
					File[] children = file.listFiles();
					if (children != null)
						Collections.addAll(pending, children);
				}
				catch (SecurityException e)
				{
				}
			}
			else if (file.getName().toLowerCase().contains(needle))
			{
				includeFile(result, null, file);
			}
		}

		return result;
	}

	@Override
	public boolean isChildDocument(String parentDocumentId, String documentId)
	{
		try
		{
			File parent = getFileForDocId(parentDocumentId).getCanonicalFile();
			File child = getFileForDocId(documentId).getCanonicalFile();
			return child.getPath().startsWith(parent.getPath() + "/");
		}
		catch (IOException e)
		{
			return documentId != null && parentDocumentId != null && documentId.startsWith(parentDocumentId);
		}
	}

	private boolean deleteRecursive(File file)
	{
		if (file.isDirectory())
		{
			File[] children = file.listFiles();
			if (children != null)
			{
				for (File child : children)
				{
					if (!deleteRecursive(child))
						return false;
				}
			}
		}

		return file.delete();
	}

	private static String getDocIdForFile(File file)
	{
		return file.getAbsolutePath();
	}

	private static File getFileForDocId(String docId) throws FileNotFoundException
	{
		if (BASE_DIR == null)
			throw new FileNotFoundException("Base directory not available");

		final File f = (docId == null || docId.length() == 0) ? BASE_DIR : new File(docId);
		if (!f.exists())
			throw new FileNotFoundException(f.getAbsolutePath() + " not found");

		return f;
	}

	private static String getMimeType(File file)
	{
		if (file == null || file.isDirectory())
			return Document.MIME_TYPE_DIR;

		String name = file.getName();
		int lastDot = name.lastIndexOf('.');
		if (lastDot >= 0)
		{
			String extension = name.substring(lastDot + 1).toLowerCase();
			String mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension);
			if (mime != null)
				return mime;
		}

		return "application/octet-stream";
	}

	private void includeFile(MatrixCursor result, String docId, File file) throws FileNotFoundException
	{
		if (docId == null)
			docId = getDocIdForFile(file);
		else
			file = getFileForDocId(docId);

		int flags = 0;
		if (file.isDirectory())
		{
			if (file.canWrite())
				flags |= Document.FLAG_DIR_SUPPORTS_CREATE;
		}
		else if (file.canWrite())
		{
			flags |= Document.FLAG_SUPPORTS_WRITE;
		}

		File parent = file.getParentFile();
		if (parent != null && parent.canWrite())
			flags |= Document.FLAG_SUPPORTS_DELETE;

		final String mimeType = getMimeType(file);
		if (mimeType.startsWith("image/"))
			flags |= Document.FLAG_SUPPORTS_THUMBNAIL;

		final MatrixCursor.RowBuilder row = result.newRow();
		row.add(Document.COLUMN_DOCUMENT_ID, docId);
		row.add(Document.COLUMN_DISPLAY_NAME, file.getName());
		row.add(Document.COLUMN_SIZE, file.length());
		row.add(Document.COLUMN_MIME_TYPE, mimeType);
		row.add(Document.COLUMN_LAST_MODIFIED, file.lastModified());
		row.add(Document.COLUMN_FLAGS, flags);
		row.add(Document.COLUMN_ICON, R.drawable.icon);
	}
}
