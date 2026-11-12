package ir.calorielens.calorie_lens

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * ویجت «کالری باقی‌مانده». متن‌ها در Dart قالب‌بندی و ذخیره می‌شوند
 * (lib/core/platform/home_widget_service.dart)؛ اینجا فقط نمایش.
 */
class CalorieWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.calorie_widget).apply {
                setTextViewText(
                    R.id.widget_value,
                    widgetData.getString("value", null) ?: "—",
                )
                setTextViewText(
                    R.id.widget_label,
                    widgetData.getString("label", null)
                        ?: context.getString(R.string.widget_placeholder),
                )
                setTextViewText(R.id.widget_detail, widgetData.getString("detail", null) ?: "")
                setOnClickPendingIntent(
                    R.id.widget_container,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
