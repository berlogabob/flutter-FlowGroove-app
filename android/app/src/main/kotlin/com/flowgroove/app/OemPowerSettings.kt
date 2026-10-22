package com.flowgroove.app

import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import java.util.Locale

object OemPowerSettings {
    fun family(): String {
        val device = "${Build.MANUFACTURER} ${Build.BRAND}".lowercase(Locale.ROOT)
        return when {
            listOf("huawei", "honor").any { it in device } -> "huawei"
            listOf("xiaomi", "redmi", "poco").any { it in device } -> "xiaomi"
            listOf("oppo", "realme", "oneplus").any { it in device } -> "oppo"
            listOf("vivo", "iqoo").any { it in device } -> "vivo"
            "samsung" in device -> "samsung"
            "asus" in device -> "asus"
            "meizu" in device -> "meizu"
            else -> "other"
        }
    }

    fun candidates(context: Context): List<Intent> {
        val family = family()
        val components = when (family) {
            "huawei" -> listOf(
                "com.huawei.systemmanager/.startupmgr.ui.StartupNormalAppListActivity",
                "com.huawei.systemmanager/.optimize.process.ProtectActivity"
            )
            "xiaomi" -> listOf(
                "com.miui.securitycenter/com.miui.permcenter.autostart.AutoStartManagementActivity",
                "com.miui.powerkeeper/.ui.HiddenAppsConfigActivity"
            )
            "oppo" -> listOf(
                "com.coloros.safecenter/.permission.startup.StartupAppListActivity",
                "com.oppo.safe/.permission.startup.StartupAppListActivity",
                "com.coloros.oppoguardelf/com.coloros.powermanager.fuelgaue.PowerUsageModelActivity"
            )
            "vivo" -> listOf(
                "com.vivo.permissionmanager/.activity.BgStartUpManagerActivity",
                "com.iqoo.secure/.ui.phoneoptimize.AddWhiteListActivity"
            )
            "samsung" -> listOf(
                "com.samsung.android.lool/com.samsung.android.sm.battery.ui.BatteryActivity"
            )
            "asus" -> listOf("com.asus.mobilemanager/.autostart.AutoStartActivity")
            "meizu" -> listOf("com.meizu.safe/.permission.SmartBGActivity")
            else -> emptyList()
        }
        val intents = components.map { name ->
            Intent().setComponent(ComponentName.unflattenFromString(name))
        }.toMutableList()
        if (family == "huawei") {
            intents.add(Intent(Intent.ACTION_POWER_USAGE_SUMMARY))
        }
        intents.add(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:${context.packageName}")
        })
        return intents.filter { intent ->
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.packageManager.resolveActivity(intent, 0)?.activityInfo?.exported == true
        }
    }

    fun open(context: Context): Boolean {
        for (intent in candidates(context)) {
            try {
                context.startActivity(intent)
                return true
            } catch (_: SecurityException) {
                // Try the next settings screen if this one is restricted.
            } catch (_: ActivityNotFoundException) {
                // The activity may have disappeared since it was resolved.
            }
        }
        return false
    }
}
