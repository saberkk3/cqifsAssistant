package com.cqwywsxy.timetable_app

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val shareChannelName = "com.cqwywsxy.timetable_app/share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            shareChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "shareToWechat" -> {
                    val text = call.argument<String>("text").orEmpty()
                    val title = call.argument<String>("title") ?: "支付链接"
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, text)
                        putExtra(Intent.EXTRA_SUBJECT, title)
                    }
                    val wechatIntent = Intent(intent).apply {
                        setPackage("com.tencent.mm")
                    }
                    try {
                        startActivity(wechatIntent)
                        result.success(true)
                    } catch (_: Exception) {
                        try {
                            startActivity(
                                Intent.createChooser(intent, "发送支付链接")
                            )
                            result.success(false)
                        } catch (error: Exception) {
                            result.error(
                                "share_failed",
                                error.message ?: "无法打开分享面板",
                                null
                            )
                        }
                    }
                }
                "openInWechat" -> {
                    val url = call.argument<String>("url").orEmpty()
                    if (url.isEmpty()) {
                        result.success(false)
                    } else {
                        try {
                            val encodedUrl = java.net.URLEncoder.encode(
                                url,
                                Charsets.UTF_8.name()
                            )
                            val intent = Intent(
                                Intent.ACTION_VIEW,
                                Uri.parse(
                                    "weixin://dl/businessWebview/link" +
                                        "?appid=wxb400d71e690a3a94" +
                                        "&url=$encodedUrl"
                                )
                            ).apply {
                                setPackage("com.tencent.mm")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (_: Exception) {
                            try {
                                val fallback = Intent(
                                    Intent.ACTION_VIEW,
                                    Uri.parse(url)
                                ).apply {
                                    setPackage("com.tencent.mm")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(fallback)
                                result.success(true)
                            } catch (_: Exception) {
                                result.success(false)
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
