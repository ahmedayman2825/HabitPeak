package com.openhabit.app

import android.content.Context
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.action.ActionParameters
import androidx.glance.action.clickable
import androidx.glance.action.actionParametersOf
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

class HabitWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = HabitWidget()
}

class HabitWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            GlanceTheme {
                HabitWidgetContent(context)
            }
        }
    }
}

private val HabitIdKey = ActionParameters.Key<String>("habitId")

class QuickCompleteAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        val habitId = parameters[HabitIdKey] ?: return
        val intent = HomeWidgetBackgroundIntent.getBroadcast(
            context,
            Uri.parse("openhabit://complete?habitId=$habitId")
        )
        intent.send()
    }
}

@Composable
private fun HabitWidgetContent(context: Context) {
    val habits = readHabits(context)
    val prefs = HomeWidgetPlugin.getData(context)
    val completed = prefs.getInt("completed_count", 0)
    val total = prefs.getInt("habit_count", habits.size)

    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(ColorProvider(R.color.widget_background))
            .padding(14.dp)
    ) {
        Row(modifier = GlanceModifier.fillMaxWidth()) {
            Text(
                text = "OpenHabit",
                style = TextStyle(
                    color = ColorProvider(R.color.widget_text),
                    fontWeight = FontWeight.Bold
                )
            )
            Spacer(modifier = GlanceModifier.width(12.dp))
            Text(
                text = "$completed/$total",
                style = TextStyle(
                    color = ColorProvider(R.color.widget_primary),
                    fontWeight = FontWeight.Bold
                )
            )
        }

        if (habits.isEmpty()) {
            Text(
                text = "No habits today",
                modifier = GlanceModifier.padding(top = 18.dp),
                style = TextStyle(
                    color = ColorProvider(R.color.widget_muted)
                )
            )
        } else {
            habits.take(4).forEach { habit ->
                Row(
                    modifier = GlanceModifier
                        .fillMaxWidth()
                        .padding(top = 10.dp)
                        .clickable(
                            actionRunCallback<QuickCompleteAction>(
                                actionParametersOf(HabitIdKey to habit.id)
                            )
                        ),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = if (habit.completed) "[x]" else "[ ]",
                        style = TextStyle(
                            color = ColorProvider(R.color.widget_primary),
                            fontWeight = FontWeight.Bold
                        )
                    )
                    Spacer(modifier = GlanceModifier.width(8.dp))
                    Text(
                        text = habit.name,
                        maxLines = 1,
                        style = TextStyle(
                            color = ColorProvider(R.color.widget_text)
                        )
                    )
                }
            }
        }
    }
}

private data class WidgetHabit(
    val id: String,
    val name: String,
    val completed: Boolean
)

private fun readHabits(context: Context): List<WidgetHabit> {
    val prefs = HomeWidgetPlugin.getData(context)
    val json = prefs.getString("habits_json", "[]") ?: "[]"
    val array = JSONArray(json)
    return List(array.length()) { index ->
        val item = array.getJSONObject(index)
        WidgetHabit(
            id = item.getString("id"),
            name = item.getString("name"),
            completed = item.optBoolean("completed", false)
        )
    }
}
