package se.kandenas.parkeringsvaljaren

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "parkering/appar")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installerade" -> result.success(
                        (call.argument<List<String>>("packages") ?: emptyList())
                            .filter(::isInstalled)
                    )
                    "oppna" -> result.success(
                        open(call.argument<String>("package")!!, call.argument<String>("url"))
                    )
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Öppnar appen med paketnamnet. Har appen en länk den tar emot skickas
     * den direkt till appen (setPackage), annars startas appen som vanligt.
     * Returnerar false om appen inte finns, så att Dart kan öppna Google Play.
     */
    private fun open(pkg: String, url: String?): Boolean {
        if (!isInstalled(pkg)) return false
        if (url != null) {
            val view = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                .setPackage(pkg)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                startActivity(view)
                return true
            } catch (e: ActivityNotFoundException) {
                // Appen tar inte emot länken. Starta den som vanligt.
            }
        }
        val launch = packageManager.getLaunchIntentForPackage(pkg) ?: return false
        startActivity(launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        return true
    }

    private fun isInstalled(pkg: String): Boolean = try {
        packageManager.getPackageInfo(pkg, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }
}
