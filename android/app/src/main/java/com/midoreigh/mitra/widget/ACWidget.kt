package com.midoreigh.mitra.widget

import android.content.Context
import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.ColorFilter
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.midoreigh.mitra.MainActivity
import com.midoreigh.mitra.R
import com.midoreigh.mitra.miraie.MirAIeService
import com.midoreigh.mitra.model.ACCommand
import com.midoreigh.mitra.model.ACState
import com.midoreigh.mitra.model.Device

/** The chosen AC on the home screen: what it's doing, with power and − / +. */
class ACWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val service = MirAIeService.get(context)
        val device = service.shared.selectedDevice
        val state = device?.let { service.shared.state(it.id) }
        provideContent { Content(device, state, service.isSignedIn) }
    }

    @Composable
    private fun Content(device: Device?, state: ACState?, signedIn: Boolean) {
        val white = ColorProvider(Color.White)
        val dim = ColorProvider(Color.White.copy(alpha = 0.6f))
        Box(
            GlanceModifier
                .fillMaxSize()
                .background(ImageProvider(R.drawable.widget_background))
                .cornerRadius(24.dp)
                .padding(14.dp)
                .clickable(actionStartActivity(Intent().setClassName("com.midoreigh.mitra", MainActivity::class.java.name))),
        ) {
            if (!signedIn || device == null) {
                Text("Open Mitra for MirAIe to sign in.", style = TextStyle(color = white, fontSize = 14.sp))
                return@Box
            }
            val s = state ?: ACState()
            Column(GlanceModifier.fillMaxSize()) {
                Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        GlanceModifier
                            .size(36.dp)
                            .background(ImageProvider(if (s.isOn) R.drawable.widget_power_on else R.drawable.widget_power_off))
                            .clickable(actionRunCallback<CommandAction>(actionParametersOf(CommandAction.key to if (s.isOn) "off" else "on"))),
                        contentAlignment = Alignment.Center,
                    ) {
                        Image(
                            ImageProvider(R.drawable.ic_power), contentDescription = if (s.isOn) "Turn off" else "Turn on",
                            colorFilter = ColorFilter.tint(ColorProvider(if (s.isOn) Color.Black else Color.White)),
                            modifier = GlanceModifier.size(20.dp),
                        )
                    }
                    Spacer(GlanceModifier.width(10.dp))
                    Column(GlanceModifier.defaultWeight()) {
                        Text(device.name, style = TextStyle(color = white, fontSize = 15.sp, fontWeight = FontWeight.Bold), maxLines = 1)
                        Text(s.summary, style = TextStyle(color = dim, fontSize = 12.sp), maxLines = 1)
                    }
                }
                Spacer(GlanceModifier.defaultWeight())
                Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom) {
                    Column(GlanceModifier.defaultWeight()) {
                        Text(
                            if (s.mode.usesSetpoint) ACState.formatTemperature(s.setpoint) else "Fan",
                            style = TextStyle(color = if (s.isOn) white else dim, fontSize = 40.sp),
                        )
                        s.roomTemperatureText?.let { Text("Room $it", style = TextStyle(color = dim, fontSize = 12.sp)) }
                    }
                    StepButton("−", "cooler", "Cooler")
                    Spacer(GlanceModifier.width(8.dp))
                    StepButton("+", "warmer", "Warmer")
                }
            }
        }
    }

    @Composable
    private fun StepButton(label: String, command: String, description: String) {
        Box(
            GlanceModifier
                .size(40.dp)
                .background(ImageProvider(R.drawable.widget_round_button))
                .clickable(actionRunCallback<CommandAction>(actionParametersOf(CommandAction.key to command))),
            contentAlignment = Alignment.Center,
        ) {
            Text(label, style = TextStyle(color = ColorProvider(Color.White), fontSize = 22.sp))
        }
    }
}

/** Runs a widget button's command against the chosen AC. */
class CommandAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val service = MirAIeService.get(context)
        val device = service.shared.selectedDevice ?: return
        val state = service.shared.state(device.id) ?: ACState()
        val command = when (parameters[key]) {
            "on" -> ACCommand.Power(true)
            "off" -> ACCommand.Power(false)
            "cooler" -> ACCommand.Temperature((state.setpoint - 1).coerceAtLeast(ACState.MIN_TEMPERATURE))
            "warmer" -> ACCommand.Temperature((state.setpoint + 1).coerceAtMost(ACState.MAX_TEMPERATURE))
            else -> return
        }
        // Show the change at once, then whatever the AC confirms.
        service.shared.save(state.applying(command), device.id)
        ACWidget().update(context, glanceId)
        runCatching { service.send(listOf(command), device) }.onFailure { service.shared.save(state, device.id) }
        Surfaces.refresh(context)
    }

    companion object {
        val key = ActionParameters.Key<String>("command")
    }
}

class ACWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = ACWidget()
}
