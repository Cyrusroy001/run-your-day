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
            val prefs = HomeWidgetPlugin.getData(context)
            val currentAction  = prefs.getString("currentAction", "Loading…") ?: "Loading…"
            val nextAction     = prefs.getString("nextAction", "") ?: ""
            val dayLabel       = prefs.getString("dayLabel", "") ?: ""
            val progressPct    = prefs.getInt("progressPct", 0)
            val minutesLeft    = prefs.getInt("minutesLeft", 0)
            val budgetMinutes  = prefs.getInt("budgetMinutes", 0)
            val doneCount      = prefs.getInt("doneCount", 0)
            val totalCount     = prefs.getInt("totalCount", 0)

            val views = RemoteViews(context.packageName, R.layout.now_widget)

            // Top row
            views.setTextViewText(R.id.widget_day, dayLabel.uppercase())
            views.setTextViewText(
                R.id.widget_done,
                if (totalCount > 0) "$doneCount/$totalCount done" else ""
            )

            // Current task
            views.setTextViewText(R.id.widget_title, currentAction)

            // Progress bar
            views.setProgressBar(R.id.widget_progress, 100, progressPct, false)

            // Time left (only when there's an active block with a budget)
            views.setTextViewText(
                R.id.widget_time_left,
                if (budgetMinutes > 0 && minutesLeft > 0) "${minutesLeft}m left" else ""
            )

            // Next task
            views.setTextViewText(R.id.widget_next, nextAction)

            // Tap opens the app
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
