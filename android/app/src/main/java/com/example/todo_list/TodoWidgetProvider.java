package com.example.todo_list;

import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.SharedPreferences;
import android.widget.RemoteViews;

public class TodoWidgetProvider extends AppWidgetProvider {
    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        for (int appWidgetId : appWidgetIds) {
            // 获取SharedPreferences中保存的数据
            SharedPreferences prefs = context.getSharedPreferences("HomeWidgetPlugin", Context.MODE_PRIVATE);
            String todayTasks = prefs.getString("today_tasks", "暂无任务");
            String deadlines = prefs.getString("deadlines", "暂无DDL");
            String dailyTasks = prefs.getString("daily_tasks", "暂无打卡任务");

            RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.todo_widget);
            
            // 更新小组件的文本内容
            views.setTextViewText(R.id.today_tasks, todayTasks);
            views.setTextViewText(R.id.deadlines, deadlines);
            views.setTextViewText(R.id.daily_tasks, dailyTasks);

            appWidgetManager.updateAppWidget(appWidgetId, views);
        }
    }
}
