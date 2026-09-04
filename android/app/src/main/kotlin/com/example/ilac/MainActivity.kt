package com.example.ilac

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var notificationPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MedicineNotifier.CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "loadState" -> result.success(MedicineNotifier.loadState(this))
                    "saveState" -> {
                        MedicineNotifier.saveState(this, call.arguments as? String ?: "")
                        MedicineNotifier.startUnlockMonitor(this)
                        result.success(null)
                    }
                    "requestNotificationPermission" -> requestNotificationPermission(result)
                    "startUnlockMonitor" -> {
                        result.success(MedicineNotifier.startUnlockMonitor(this))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onResume() {
        super.onResume()
        MedicineNotifier.startUnlockMonitor(this)
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }

        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }

        notificationPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == NOTIFICATION_PERMISSION_REQUEST) {
            val isGranted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
            if (isGranted) {
                MedicineNotifier.startUnlockMonitor(this)
            }
            notificationPermissionResult?.success(isGranted)
            notificationPermissionResult = null
        }
    }

    companion object {
        private const val NOTIFICATION_PERMISSION_REQUEST = 501
    }
}
