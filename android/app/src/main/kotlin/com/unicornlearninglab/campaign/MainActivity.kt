package com.unicornlearninglab.campaign

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter UI and a small Storage Access Framework bridge
 * (channel "ull/storage") so operators can pick any folder for CSV exports
 * and open it in the file manager. No storage permissions are needed:
 * access is granted per-folder by the user through the system picker.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "ull/storage"
    private val pickDirRequestCode = 4711
    private var pendingPickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result -> handle(call, result) }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "pickDirectory" -> pickDirectory(result)
                "labelFor" -> result.success(labelFor(Uri.parse(call.argument<String>("uri")!!)))
                "hasAccess" -> result.success(hasAccess(call.argument<String>("uri")!!))
                "writeFiles" -> writeFiles(call, result)
                "openDirectory" -> result.success(openDirectory(Uri.parse(call.argument<String>("uri")!!)))
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("STORAGE_ERROR", e.message ?: e.toString(), null)
        }
    }

    private fun pickDirectory(result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("BUSY", "A folder picker is already open", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
            )
        }
        pendingPickResult = result
        try {
            startActivityForResult(intent, pickDirRequestCode)
        } catch (e: ActivityNotFoundException) {
            pendingPickResult = null
            result.error("NO_PICKER", "No file manager is available on this device", null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickDirRequestCode) return
        val result = pendingPickResult ?: return
        pendingPickResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
        } catch (_: SecurityException) {
            // Some providers don't offer persistable grants; access still works this session.
        }
        result.success(mapOf("uri" to uri.toString(), "label" to labelFor(uri)))
    }

    private fun hasAccess(uriString: String): Boolean {
        return contentResolver.persistedUriPermissions.any {
            it.uri.toString() == uriString && it.isWritePermission
        }
    }

    /** "primary:Download/Exports" -> "Internal storage/Download/Exports". */
    private fun labelFor(treeUri: Uri): String {
        return try {
            val docId = DocumentsContract.getTreeDocumentId(treeUri)
            val parts = docId.split(":", limit = 2)
            val volume = if (parts[0].equals("primary", ignoreCase = true)) "Internal storage" else parts[0]
            val path = if (parts.size > 1) parts[1] else ""
            if (path.isEmpty()) volume else "$volume/$path"
        } catch (_: Exception) {
            treeUri.lastPathSegment ?: "Selected folder"
        }
    }

    private fun writeFiles(call: MethodCall, result: MethodChannel.Result) {
        val treeUri = Uri.parse(call.argument<String>("uri")!!)
        val mimeType = call.argument<String>("mimeType") ?: "text/csv"
        val files = call.argument<List<Map<String, String>>>("files") ?: emptyList()
        val parentDoc = DocumentsContract.buildDocumentUriUsingTree(
            treeUri, DocumentsContract.getTreeDocumentId(treeUri)
        )
        val written = mutableListOf<String>()
        for (file in files) {
            val name = file["name"] ?: continue
            val content = file["content"] ?: ""
            val docUri = DocumentsContract.createDocument(contentResolver, parentDoc, mimeType, name)
                ?: throw IllegalStateException("Could not create $name in the selected folder")
            contentResolver.openOutputStream(docUri, "w").use { out ->
                requireNotNull(out) { "Could not open $name for writing" }
                // UTF-8 BOM so Excel shows Indian names / symbols correctly.
                out.write(byteArrayOf(0xEF.toByte(), 0xBB.toByte(), 0xBF.toByte()))
                out.write(content.toByteArray(Charsets.UTF_8))
            }
            written.add(name)
        }
        result.success(written)
    }

    private fun openDirectory(treeUri: Uri): Boolean {
        val docUri = DocumentsContract.buildDocumentUriUsingTree(
            treeUri, DocumentsContract.getTreeDocumentId(treeUri)
        )
        val attempts = listOf(
            Intent(Intent.ACTION_VIEW).setDataAndType(docUri, DocumentsContract.Document.MIME_TYPE_DIR),
            Intent(Intent.ACTION_VIEW).setDataAndType(docUri, "resource/folder"),
            // Fallback: open the system Files app at that folder via the picker.
            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                type = "*/*"
                addCategory(Intent.CATEGORY_OPENABLE)
                putExtra(DocumentsContract.EXTRA_INITIAL_URI, docUri)
            },
        )
        for (intent in attempts) {
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                startActivity(intent)
                return true
            } catch (_: ActivityNotFoundException) {
            } catch (_: SecurityException) {
            }
        }
        return false
    }
}
