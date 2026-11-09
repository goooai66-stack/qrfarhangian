package ir.calorielens.calorie_lens

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // درخواست امتیاز در کافه‌بازار یا مایکت (lib/core/platform/store_rating.dart)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "calorielens/store")
            .setMethodCallHandler { call, result ->
                if (call.method == "rate") {
                    result.success(openRating(call.argument<String>("store")))
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun openRating(store: String?): Boolean {
        val pkg = packageName
        val (appIntent, webUrl) = when (store) {
            "bazaar" -> Intent(Intent.ACTION_EDIT, Uri.parse("bazaar://details?id=$pkg"))
                .setPackage("com.farsitel.bazaar") to "https://cafebazaar.ir/app/$pkg"
            "myket" -> Intent(Intent.ACTION_VIEW, Uri.parse("myket://comment?id=$pkg"))
                .setPackage("ir.mservices.market") to "https://myket.ir/app/$pkg"
            else -> return false
        }
        return try {
            startActivity(appIntent)
            true
        } catch (e: ActivityNotFoundException) {
            // فروشگاه نصب نیست ← صفحه‌ی وب اپ.
            try {
                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(webUrl)))
                true
            } catch (e2: ActivityNotFoundException) {
                false
            }
        }
    }
}
