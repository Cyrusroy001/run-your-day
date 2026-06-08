package com.cyrus.daily_command_center

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

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
            // home_widget stores data in its own "HomeWidgetPreferences" file with
            // raw keys (no "flutter." prefix). Use the plugin's accessor so we read
            // the same file HomeWidget.saveWidgetData() writes to.
            val prefs = HomeWidgetPlugin.getData(context)
            val currentAction = prefs.getString("currentAction", "Loading…") ?: "Loading…"
            val nextAction    = prefs.getString("nextAction", "") ?: ""
            val dayLabel      = prefs.getString("dayLabel", "") ?: ""
            val progressPct   = prefs.getInt("progressPct", 0)

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
