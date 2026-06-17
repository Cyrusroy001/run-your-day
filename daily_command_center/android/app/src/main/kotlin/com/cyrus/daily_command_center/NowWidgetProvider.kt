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
            val progressPct    = prefs.getInt("progressPct", 0)
            val minutesLeft    = prefs.getInt("minutesLeft", 0)
            val budgetMinutes  = prefs.getInt("budgetMinutes", 0)

            val views = RemoteViews(context.packageName, R.layout.now_widget)

            // Painted arc (rendered by the app). Decode defensively: any failure
            // falls back to the native-only ripe card (ADR-022 §7 risk control).
            val hasArc = prefs.getBoolean("hasArcImage", false)
            val arcPath = prefs.getString("arcImage", null)
            val nightMode = prefs.getBoolean("nightMode", false)
            var arcShown = false
            if (hasArc && arcPath != null) {
                try {
                    val bmp = android.graphics.BitmapFactory.decodeFile(arcPath)
                    if (bmp != null) {
                        views.setImageViewBitmap(R.id.widget_arc, bmp)
                        views.setViewVisibility(R.id.widget_arc, android.view.View.VISIBLE)
                        arcShown = true
                    }
                } catch (_: Exception) { /* fall through to native card */ }
            }
            if (!arcShown) views.setViewVisibility(R.id.widget_arc, android.view.View.GONE)

            // Night = stars + bud image only, no text rows (pure metaphor).
            views.setViewVisibility(
                R.id.widget_text_strip,
                if (nightMode && arcShown) android.view.View.GONE else android.view.View.VISIBLE
            )

            // Current block name (● RIPE NOW is static in the layout — no stat tiles)
            views.setTextViewText(R.id.widget_title, currentAction)

            // Progress
            views.setProgressBar(R.id.widget_progress, 100, progressPct, false)

            // Minutes left (only with an active, budgeted block)
            views.setTextViewText(
                R.id.widget_time_left,
                if (budgetMinutes > 0 && minutesLeft > 0) "${minutesLeft}m left" else ""
            )

            // Next stop
            views.setTextViewText(
                R.id.widget_next,
                if (nextAction.isNotEmpty()) "next · $nextAction" else ""
            )

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
