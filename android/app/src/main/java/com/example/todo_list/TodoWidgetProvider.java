package com.example.todo_list;

import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.SharedPreferences;
import android.widget.RemoteViews;
import android.graphics.Color;
import android.view.View;
import android.os.Bundle;

public class TodoWidgetProvider extends AppWidgetProvider {    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        for (int appWidgetId : appWidgetIds) {
            // 获取SharedPreferences中保存的数据
            SharedPreferences prefs = context.getSharedPreferences("HomeWidgetPlugin", Context.MODE_PRIVATE);
            String todayTasks = prefs.getString("today_tasks", "暂无任务");
            String deadlines = prefs.getString("deadlines", "暂无DDL");
            String dailyTasks = prefs.getString("daily_tasks", "暂无打卡任务");

            RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.todo_widget);
            
            // 设置背景和文本样式
            views.setInt(R.id.today_tasks, "setBackgroundColor", Color.TRANSPARENT);
            views.setInt(R.id.deadlines, "setBackgroundColor", Color.TRANSPARENT);
            views.setInt(R.id.daily_tasks, "setBackgroundColor", Color.TRANSPARENT);
            
            // 更新小组件的文本内容
            views.setTextViewText(R.id.today_tasks, todayTasks.isEmpty() ? "暂无任务" : todayTasks);
            views.setTextViewText(R.id.deadlines, deadlines.isEmpty() ? "暂无DDL" : deadlines);
            views.setTextViewText(R.id.daily_tasks, dailyTasks.isEmpty() ? "暂无打卡任务" : dailyTasks);
            
            // 设置可见性
            views.setViewVisibility(R.id.today_tasks, todayTasks.isEmpty() ? View.GONE : View.VISIBLE);
            views.setViewVisibility(R.id.deadlines, deadlines.isEmpty() ? View.GONE : View.VISIBLE);
            views.setViewVisibility(R.id.daily_tasks, dailyTasks.isEmpty() ? View.GONE : View.VISIBLE);

            // 更新小部件
            appWidgetManager.updateAppWidget(appWidgetId, views);
        }
    }
    
    @Override
    public void onAppWidgetOptionsChanged(Context context, AppWidgetManager appWidgetManager, int appWidgetId, Bundle newOptions) {
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.todo_widget);
        appWidgetManager.updateAppWidget(appWidgetId, views);
    }
}
