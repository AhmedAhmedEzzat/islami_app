package com.ahmedezzat.sakina

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject

/**
 * Home screen widget: the next prayer with a live countdown, and the day's
 * five prayer times.
 *
 * The app writes the next fourteen days of times (already localised) to its
 * shared preferences whenever it reschedules notifications, including from
 * its daily background task. The widget reads them, lets the Chronometer
 * count down on its own, and sets an alarm for the moment that prayer comes
 * in, to move on to the next one. No Dart runs for any of this.
 */
class PrayerWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        updateAll(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_REFRESH) updateAll(context)
    }

    override fun onDisabled(context: Context) {
        alarmManager(context).cancel(refreshIntent(context))
    }

    private class Prayer(val time: Long, val name: String, val label: String, val day: String)

    companion object {
        const val ACTION_REFRESH = "com.ahmedezzat.sakina.widget.REFRESH"

        /** Written by lib/core/services/prayer_widget.dart. */
        private const val PREFS = "FlutterSharedPreferences"
        private const val KEY = "flutter.widget.prayers"

        private val NAME_IDS = intArrayOf(R.id.p1_name, R.id.p2_name, R.id.p3_name, R.id.p4_name, R.id.p5_name)
        private val TIME_IDS = intArrayOf(R.id.p1_time, R.id.p2_time, R.id.p3_time, R.id.p4_time, R.id.p5_time)
        private val CELL_IDS = intArrayOf(R.id.p1, R.id.p2, R.id.p3, R.id.p4, R.id.p5)

        /** Redraws every placed widget and sets the alarm for the next prayer. */
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, PrayerWidget::class.java))
            if (ids.isEmpty()) return
            val data = read(context)
            val now = System.currentTimeMillis()
            val next = data?.second?.firstOrNull { it.time > now }
            val views = build(context, data?.first, data?.second ?: emptyList(), next, now)
            for (id in ids) manager.updateAppWidget(id, views)
            if (next != null) schedule(context, next.time + 1000)
        }

        private fun read(context: Context): Pair<JSONObject, List<Prayer>>? {
            val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null) ?: return null
            return try {
                val json = JSONObject(raw)
                val list = json.getJSONArray("prayers")
                val prayers = (0 until list.length()).map {
                    val p = list.getJSONObject(it)
                    Prayer(p.getLong("t"), p.getString("n"), p.getString("s"), p.getString("d"))
                }
                json to prayers
            } catch (e: Exception) {
                null
            }
        }

        private fun build(
            context: Context,
            json: JSONObject?,
            prayers: List<Prayer>,
            next: Prayer?,
            now: Long,
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.prayer_widget)
            views.setOnClickPendingIntent(R.id.widget_root, openApp(context))
            if (json != null) {
                views.setInt(
                    R.id.widget_root,
                    "setLayoutDirection",
                    if (json.optBoolean("rtl")) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR,
                )
            }

            if (json == null || next == null) {
                // Never opened, or the saved times have run out.
                views.setViewVisibility(R.id.widget_main, View.GONE)
                views.setViewVisibility(R.id.widget_row, View.GONE)
                views.setViewVisibility(R.id.widget_stale, View.VISIBLE)
                views.setTextViewText(
                    R.id.widget_stale,
                    json?.optString("stale")?.takeIf { it.isNotEmpty() }
                        ?: context.getString(R.string.widget_open_app),
                )
                return views
            }

            views.setViewVisibility(R.id.widget_main, View.VISIBLE)
            views.setViewVisibility(R.id.widget_row, View.VISIBLE)
            views.setViewVisibility(R.id.widget_stale, View.GONE)
            val place = json.optString("place")
            val heading = json.optString("next")
            views.setTextViewText(R.id.widget_label, if (place.isEmpty()) heading else "$heading · $place")
            views.setTextViewText(R.id.widget_name, next.name)
            views.setTextViewText(R.id.widget_time, next.label)

            // The Chronometer counts down by itself, with no updates needed.
            val base = SystemClock.elapsedRealtime() + (next.time - now)
            views.setChronometer(R.id.widget_countdown, base, null, true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                views.setChronometerCountDown(R.id.widget_countdown, true)
            }

            // The five prayers of the day the next one falls on.
            val day = prayers.filter { it.day == next.day }.take(CELL_IDS.size)
            for (i in CELL_IDS.indices) {
                val p = day.getOrNull(i)
                views.setViewVisibility(CELL_IDS[i], if (p == null) View.GONE else View.VISIBLE)
                if (p == null) continue
                views.setTextViewText(NAME_IDS[i], p.name)
                views.setTextViewText(TIME_IDS[i], p.label)
                views.setInt(CELL_IDS[i], "setBackgroundResource", if (p === next) R.drawable.widget_chip else 0)
            }
            return views
        }

        private fun openApp(context: Context): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            return PendingIntent.getActivity(
                context, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }

        private fun refreshIntent(context: Context): PendingIntent {
            val intent = Intent(context, PrayerWidget::class.java).setAction(ACTION_REFRESH)
            return PendingIntent.getBroadcast(
                context, 7, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }

        private fun alarmManager(context: Context) =
            context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        /** Wakes the widget when the next prayer comes in, to show the one after. */
        private fun schedule(context: Context, at: Long) {
            val alarms = alarmManager(context)
            val pending = refreshIntent(context)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarms.canScheduleExactAlarms()) {
                    // Without the exact-alarm permission Android may run it a
                    // few minutes late; the countdown then reads 00:00 till it does.
                    alarms.setAndAllowWhileIdle(AlarmManager.RTC, at, pending)
                } else {
                    alarms.setExactAndAllowWhileIdle(AlarmManager.RTC, at, pending)
                }
            } catch (e: SecurityException) {
                alarms.set(AlarmManager.RTC, at, pending)
            }
        }
    }
}
