package com.cqwywsxy.timetable_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class TodayWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.today_widget_layout).apply {
                setTextViewText(
                    R.id.widget_date,
                    widgetData.getString("widget_date", "今天"),
                )
                setTextViewText(
                    R.id.widget_week,
                    widgetData.getString("widget_week", ""),
                )
                setTextViewText(
                    R.id.widget_courses,
                    widgetData.getString("widget_courses", "打开应用同步课表"),
                )
                setTextViewText(
                    R.id.widget_tasks,
                    widgetData.getString("widget_tasks", "暂无待办日程"),
                )
                setTextViewText(
                    R.id.widget_water,
                    widgetData.getString("widget_water", "水表  未授权"),
                )
                setTextViewText(
                    R.id.widget_electricity,
                    widgetData.getString("widget_electricity", "电表  未授权"),
                )
                setTextViewText(
                    R.id.widget_updated,
                    widgetData.getString("widget_updated", ""),
                )
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
