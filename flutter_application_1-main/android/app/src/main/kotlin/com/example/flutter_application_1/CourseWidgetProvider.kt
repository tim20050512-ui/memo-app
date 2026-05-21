package com.example.flutter_application_1

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class CourseWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.course_widget)

            val hasClass = widgetData.getBoolean("has_class", false)
            
            // 時間主動防錯：如果小工具中有課，但今天時間已經過了這堂課的結束時間，則主動改為無課狀態顯示
            var actualHasClass = hasClass
            if (actualHasClass) {
                val timeStr = widgetData.getString("course_time", "")
                if (!timeStr.isNullOrEmpty() && timeStr.contains("-")) {
                    try {
                        val parts = timeStr.split("-")
                        val endTimeStr = parts[1].trim() // 例如 "12:00"
                        val endParts = endTimeStr.split(":")
                        val endHour = endParts[0].toInt()
                        val endMin = endParts[1].toInt()
                        
                        val now = java.util.Calendar.getInstance()
                        val nowHour = now.get(java.util.Calendar.HOUR_OF_DAY)
                        val nowMin = now.get(java.util.Calendar.MINUTE)
                        
                        // 如果當前小時已過，或同小時但分鐘已過，則將 actualHasClass 設為 false
                        if (nowHour > endHour || (nowHour == endHour && nowMin >= endMin)) {
                            actualHasClass = false
                        }
                    } catch (e: Exception) {
                        // 容錯機制：若解析失敗，維持原來的 hasClass 狀態
                    }
                }
            }

            if (actualHasClass) {
                // 顯示有課 Layout，隱藏無課 Layout
                views.setViewVisibility(R.id.layout_active, View.VISIBLE)
                views.setViewVisibility(R.id.layout_empty, View.GONE)

                // 設定莫蘭迪藍色漸層背景
                views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.widget_bg_active)

                // 綁定資料
                val title = widgetData.getString("course_title", "")
                views.setTextViewText(R.id.widget_course_title, title)

                val time = widgetData.getString("course_time", "")
                views.setTextViewText(R.id.widget_course_time, time)

                val room = widgetData.getString("course_room", "")
                views.setTextViewText(R.id.widget_course_room, room)
                views.setViewVisibility(R.id.widget_course_room, if (room.isNullOrEmpty()) View.GONE else View.VISIBLE)
            } else {
                // 顯示無課 Layout，隱藏有課 Layout
                views.setViewVisibility(R.id.layout_active, View.GONE)
                views.setViewVisibility(R.id.layout_empty, View.VISIBLE)

                // 設定莫蘭迪綠色漸層背景
                views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.widget_bg_empty)

                // 顯示「今天的課程都完畢嘍!」
                val emptyText = widgetData.getString("empty_text", "今天的課程都完畢嘍!")
                views.setTextViewText(R.id.widget_empty_text, emptyText)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
