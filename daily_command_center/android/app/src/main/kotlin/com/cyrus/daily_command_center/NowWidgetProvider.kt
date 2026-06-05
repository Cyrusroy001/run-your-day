package com.cyrus.daily_command_center

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class NowWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    companion object {
        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            // Keys stored with "flutter." prefix by the home_widget package
            val currentAction = prefs.getString("flutter.currentAction", "Loading…") ?: "Loading…"
            val nextAction    = prefs.getString("flutter.nextAction", "") ?: ""
            val dayLabel      = prefs.getString("flutter.dayLabel", "") ?: ""
            val progressPct   = prefs.getInt("flutter.progressPct", 0)

            val views = RemoteViews(context.packageName, R.layout.now_widget)
            views.setTextViewText(R.id.widget_label, "Right now · $dayLabel")
            views.setTextViewText(R.id.widget_title, currentAction)
            views.setTextViewText(R.id.widget_next, nextAction)

            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
