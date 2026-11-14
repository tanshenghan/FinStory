package com.yohji.ledger_app

import android.content.Intent
import android.util.Base64
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.yohji.ledger_app/export",
        ).setMethodCallHandler { call, result ->
            if (call.method != "shareFile") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val name = call.argument<String>("name") ?: "jianzhang-backup.json"
                val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                val contentBase64 = call.argument<String>("contentBase64") ?: ""
                val chooserTitle = call.argument<String>("chooserTitle") ?: "导出 finstory 数据"
                val exportDir = File(cacheDir, "exports").apply { mkdirs() }
                val safeName = name.replace(Regex("[^a-zA-Z0-9._\\-\\u4e00-\\u9fff]"), "_")
                val exportFile = File(exportDir, safeName)
                exportFile.writeBytes(Base64.decode(contentBase64, Base64.DEFAULT))
                val uri = FileProvider.getUriForFile(
                    this,
                    "$packageName.fileprovider",
                    exportFile,
                )
                val sendIntent = Intent(Intent.ACTION_SEND).apply {
                    type = mimeType
                    putExtra(Intent.EXTRA_STREAM, uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                startActivity(Intent.createChooser(sendIntent, chooserTitle))
                result.success(null)
            } catch (error: Exception) {
                result.error("EXPORT_FAILED", error.message, null)
            }
        }
    }
}
