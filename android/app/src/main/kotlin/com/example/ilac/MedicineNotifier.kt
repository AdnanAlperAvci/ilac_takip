package com.example.ilac

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.concurrent.TimeUnit

object MedicineNotifier {
    const val CHANNEL_NAME = "ilac/storage"
    const val REMINDER_CHANNEL_ID = "medicine_unlock_reminders"
    const val MONITOR_CHANNEL_ID = "medicine_unlock_monitor"

    private const val PREFS_NAME = "medicine_store"
    private const val STATE_KEY = "medicine_state"
    private const val NOTIFICATION_ID = 1107

    private val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)

    fun loadState(context: Context): String {
        return prefs(context).getString(STATE_KEY, "") ?: ""
    }

    fun saveState(context: Context, stateJson: String) {
        prefs(context).edit().putString(STATE_KEY, stateJson).apply()
    }

    fun startUnlockMonitor(context: Context): Boolean {
        val intent = Intent(context, UnlockMonitorService::class.java)
        return runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            true
        }.getOrDefault(false)
    }

    fun notifyOnUnlockAfterLimit(context: Context) {
        val state = JSONObject(loadState(context).ifBlank { "{}" })
        val now = Calendar.getInstance()
        val todayKey = dateFormat.format(now.time)

        val limitHour = state.optInt("notifyAfterHour", 8)
        val limitMinute = state.optInt("notifyAfterMinute", 0)
        if (!isAfterLimit(now, limitHour, limitMinute)) {
            return
        }

        val dueMedicines = dueMedicinesForToday(state, now, todayKey)
        if (dueMedicines.isEmpty()) {
            return
        }

        if (!canShowNotification(context)) {
            return
        }

        showNotification(context, dueMedicines)
    }

    private fun dueMedicinesForToday(
        state: JSONObject,
        today: Calendar,
        todayKey: String,
    ): List<String> {
        val routines = state.optJSONArray("routines") ?: JSONArray()
        val takenDates = state.optJSONObject("takenDates") ?: JSONObject()
        val dueMedicines = mutableListOf<String>()

        for (index in 0 until routines.length()) {
            val routine = routines.optJSONObject(index) ?: continue
            if (!routine.optBoolean("isActive", true)) {
                continue
            }

            if (!isRoutineDue(routine, today)) {
                continue
            }

            val takenForRoutine = takenDates.optJSONArray(routine.optString("id")) ?: JSONArray()
            if (containsString(takenForRoutine, todayKey)) {
                continue
            }

            dueMedicines.add(routine.optString("name", "İlaç"))
        }

        return dueMedicines
    }

    private fun isRoutineDue(routine: JSONObject, today: Calendar): Boolean {
        val startDate = dateFormat.parse(routine.optString("startDate")) ?: return false
        val start = Calendar.getInstance().apply {
            time = startDate
            clearTime()
        }
        val current = today.clone() as Calendar
        current.clearTime()

        if (current.before(start)) {
            return false
        }

        val routineType = routine.optString("routineType", "daily")
        val isPatternDue = when (routineType) {
            "everyOtherDay" -> {
                val daysBetween = TimeUnit.MILLISECONDS.toDays(
                    current.timeInMillis - start.timeInMillis,
                )
                daysBetween % 2L == 0L
            }
            "weekly" -> containsInt(
                routine.optJSONArray("weekdays") ?: JSONArray(),
                dartWeekday(current),
            )
            else -> true
        }

        if (!isPatternDue) {
            return false
        }

        val maxDoseCount = maxDoseCount(routine) ?: return true
        val doseNumber = doseNumberOn(routine, routineType, start, current) ?: return false
        return doseNumber <= maxDoseCount
    }

    private fun maxDoseCount(routine: JSONObject): Int? {
        val boxQuantity = parseDecimal(routine.optString("boxQuantity"))
        val dose = parseDecimal(routine.optString("dose"))
        if (boxQuantity == null || boxQuantity <= 0.0 || dose == null || dose <= 0.0) {
            return null
        }

        return (boxQuantity / dose).toInt()
    }

    private fun doseNumberOn(
        routine: JSONObject,
        routineType: String,
        start: Calendar,
        current: Calendar,
    ): Int? {
        val daysBetween = TimeUnit.MILLISECONDS.toDays(
            current.timeInMillis - start.timeInMillis,
        ).toInt()

        return when (routineType) {
            "everyOtherDay" -> {
                if (daysBetween % 2 != 0) {
                    null
                } else {
                    daysBetween / 2 + 1
                }
            }
            "weekly" -> weeklyDoseNumberOn(
                routine.optJSONArray("weekdays") ?: JSONArray(),
                start,
                current,
            )
            else -> daysBetween + 1
        }
    }

    private fun weeklyDoseNumberOn(
        weekdays: JSONArray,
        start: Calendar,
        current: Calendar,
    ): Int {
        val cursor = start.clone() as Calendar
        var doseCount = 0
        while (!cursor.after(current)) {
            if (containsInt(weekdays, dartWeekday(cursor))) {
                doseCount += 1
            }
            cursor.add(Calendar.DAY_OF_YEAR, 1)
        }

        return doseCount
    }

    private fun showNotification(context: Context, medicineNames: List<String>) {
        createNotificationChannel(context)

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val title = if (medicineNames.size == 1) {
            "İlaç zamanı"
        } else {
            "${medicineNames.size} ilaç bekliyor"
        }
        val text = medicineNames.take(3).joinToString(", ")

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(context, REMINDER_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            android.app.Notification.Builder(context)
        }

        val notification = builder
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(android.app.Notification.BigTextStyle().bigText(text))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val channel = NotificationChannel(
            REMINDER_CHANNEL_ID,
            "İlaç kilit açma hatırlatmaları",
            NotificationManager.IMPORTANCE_DEFAULT,
        )
        channel.description = "Belirlenen saatten sonra ilk telefon kilidi açıldığında ilaç hatırlatır."

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.createNotificationChannel(channel)
    }

    private fun isAfterLimit(now: Calendar, limitHour: Int, limitMinute: Int): Boolean {
        val currentMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        val limitMinutes = limitHour * 60 + limitMinute
        return currentMinutes >= limitMinutes
    }

    private fun canShowNotification(context: Context): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun parseDecimal(value: String): Double? {
        return value.trim().replace(',', '.').toDoubleOrNull()
    }

    private fun containsString(values: JSONArray, needle: String): Boolean {
        for (index in 0 until values.length()) {
            if (values.optString(index) == needle) {
                return true
            }
        }

        return false
    }

    private fun containsInt(values: JSONArray, needle: Int): Boolean {
        for (index in 0 until values.length()) {
            if (values.optInt(index) == needle) {
                return true
            }
        }

        return false
    }

    private fun dartWeekday(calendar: Calendar): Int {
        return when (calendar.get(Calendar.DAY_OF_WEEK)) {
            Calendar.MONDAY -> 1
            Calendar.TUESDAY -> 2
            Calendar.WEDNESDAY -> 3
            Calendar.THURSDAY -> 4
            Calendar.FRIDAY -> 5
            Calendar.SATURDAY -> 6
            else -> 7
        }
    }

    private fun Calendar.clearTime() {
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
