package com.midoreigh.mitra.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Eco
import androidx.compose.material.icons.outlined.Lightbulb
import androidx.compose.material.icons.rounded.AcUnit
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Adjust
import androidx.compose.material.icons.rounded.Air
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bedtime
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.BubbleChart
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Eco
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.Lightbulb
import androidx.compose.material.icons.rounded.MoreVert
import androidx.compose.material.icons.rounded.PowerSettingsNew
import androidx.compose.material.icons.rounded.Remove
import androidx.compose.material.icons.rounded.Thermostat
import androidx.compose.material.icons.rounded.WaterDrop
import androidx.compose.material.icons.rounded.WbSunny
import androidx.compose.material.icons.rounded.WifiOff
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.midoreigh.mitra.model.ACCommand
import com.midoreigh.mitra.model.ACMode
import com.midoreigh.mitra.model.ACState
import com.midoreigh.mitra.model.Converti
import com.midoreigh.mitra.model.FanSpeed
import com.midoreigh.mitra.model.Louver
import com.midoreigh.mitra.store.ACStore
import com.midoreigh.mitra.store.UiState
import kotlinx.coroutines.launch

@Composable
fun ControlScreen(ui: UiState, store: ACStore, openSettings: () -> Unit) {
    val state = ui.state
    val controlsAlpha by animateFloatAsState(if (state.isOn) 1f else 0.55f, tween(300), label = "controls")
    BoxWithConstraints(Modifier.fillMaxSize().background(MitraColors.night)) {
        // On a typical phone everything fits on one screen, the hero taking the spare height and
        // the controls sitting low, within thumb reach. A short screen scrolls instead.
        val fits = maxHeight >= 640.dp
        val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
        Column(
            Modifier
                .fillMaxSize()
                .then(if (fits) Modifier else Modifier.verticalScroll(rememberScrollState()))
                .padding(bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()),
        ) {
            Hero(ui, store, openSettings, if (fits) Modifier.weight(1f) else Modifier.height(top + 460.dp))
            Column(
                Modifier.padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 12.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                AnimatedVisibility(!state.isOnline, enter = expandVertically() + fadeIn(), exit = shrinkVertically() + fadeOut()) {
                    OfflineBanner(ui.selected?.name ?: "The AC")
                }
                Column(Modifier.alpha(controlsAlpha), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    FanBar(state, ui.canControl) { store.send(ACCommand.Fan(it)) }
                    ModeBar(state, ui, ui.canControl) { store.send(ACCommand.Mode(it)) }
                    Features(state, ui, store)
                }
            }
        }
    }
}

// Hero

/** The AC edge to edge with its air, the set temperature over it and the louvers along the bottom. */
@Composable
private fun Hero(ui: UiState, store: ACStore, openSettings: () -> Unit, modifier: Modifier) {
    val state = ui.state
    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val shape = RoundedCornerShape(bottomStart = 28.dp, bottomEnd = 28.dp)
    val connection = connection(ui)
    Box(
        Modifier
            .fillMaxWidth()
            .then(modifier)
            .clip(shape)
            .border(1.dp, MitraColors.glassBorder, shape),
    ) {
        GraphiteBackdrop(state.isOn, Modifier.fillMaxSize())
        ACUnitScene(
            state,
            Modifier
                .fillMaxSize()
                .padding(top = top + 70.dp)
                .semantics { contentDescription = "${ui.selected?.name ?: "AC"}: ${state.summary}. ${connection.second}" },
            statusLight = connection.first,
            onStatusLightTap = if (ui.isPreviewing) store::togglePreviewOnline else null,
        )
        Column(Modifier.fillMaxSize().padding(start = 16.dp, end = 16.dp, top = top + 8.dp, bottom = 16.dp)) {
            Header(ui, store, openSettings)
            Spacer(Modifier.weight(1f))
            Temperature(state, ui.canControl) { delta ->
                store.send(ACCommand.Temperature((state.setpoint + delta).coerceIn(ACState.MIN_TEMPERATURE, ACState.MAX_TEMPERATURE)))
            }
            Spacer(Modifier.height(16.dp))
            Louvers(state, ui.canControl, store)
        }
    }
}

/** Shown by the light on the AC: its colour and what it means. */
private fun connection(ui: UiState): Pair<Color, String> {
    val preview = if (ui.isPreviewing) " · tap to go ${if (ui.state.isOnline) "offline" else "online"}" else ""
    if (!ui.state.isOnline) return MitraColors.offlineLight to "Offline$preview"
    if (!ui.isLive && !ui.isPreviewing) return MitraColors.connecting to "Connecting…"
    return MitraColors.online to "Online$preview"
}

@Composable
private fun Header(ui: UiState, store: ACStore, openSettings: () -> Unit) {
    val state = ui.state
    val scope = rememberCoroutineScope()
    Row(Modifier.fillMaxWidth().height(48.dp), verticalAlignment = Alignment.CenterVertically) {
        PowerButton(state.isOn, ui.canControl) { store.send(ACCommand.Power(!state.isOn)) }
        Spacer(Modifier.width(12.dp))
        DeviceName(ui, store, Modifier.weight(1f))
        if (ui.isPreviewing) {
            Spacer(Modifier.width(8.dp))
            val hint = rememberHint(if (ui.isDemo) "A made-up AC. Tap to leave." else "Not sending to the AC. Tap to stop.")
            Text(
                "Preview",
                color = Color.Black,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier
                    .clip(CircleShape)
                    .background(MitraColors.preview, CircleShape)
                    .hinted("Preview mode: ${if (ui.isDemo) "a made-up AC" else "not sending to the AC"}", hint) {
                        store.setPreviewing(false)
                    }
                    .padding(horizontal = 12.dp, vertical = 6.dp),
            )
        }
        var menu by remember { mutableStateOf(false) }
        Box {
            Box(
                Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .clickable(onClickLabel = "More") { menu = true }
                    .semantics { contentDescription = "More" },
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Rounded.MoreVert, null, tint = Color.White)
            }
            DropdownMenu(menu, onDismissRequest = { menu = false }) {
                if (ui.isDemo) {
                    DropdownMenuItem(text = { Text("Leave the demo") }, onClick = { menu = false; store.setPreviewing(false) })
                } else {
                    DropdownMenuItem(text = { Text("Refresh") }, onClick = { menu = false; scope.launch { store.start() } })
                    DropdownMenuItem(
                        text = { Text("Preview Mode") },
                        trailingIcon = { if (ui.isPreviewing) Icon(Icons.Rounded.Check, null) },
                        onClick = { menu = false; store.setPreviewing(!ui.isPreviewing) },
                    )
                    DropdownMenuItem(text = { Text("Settings") }, onClick = { menu = false; openSettings() })
                    HorizontalDivider()
                    DropdownMenuItem(text = { Text("Sign Out") }, onClick = { menu = false; store.signOut() })
                }
            }
        }
    }
}

/**
 * Power as a round button: solid white with a black symbol while the AC runs, plain glass
 * while it's off.
 */
@Composable
private fun PowerButton(isOn: Boolean, enabled: Boolean, onClick: () -> Unit) {
    val hint = rememberHint(if (isOn) "Turn off" else "Turn on")
    val fill by animateColorAsState(if (isOn) Color.White else MitraColors.glass, tween(200), label = "power")
    val icon by animateColorAsState(if (isOn) Color.Black else Color.White, tween(200), label = "powerIcon")
    Box(
        Modifier
            .size(40.dp)
            .alpha(if (enabled) 1f else 0.5f)
            .clip(CircleShape)
            .background(fill, CircleShape)
            .border(1.dp, if (isOn) Color.Transparent else MitraColors.glassBorder, CircleShape)
            .hinted(if (isOn) "Turn off" else "Turn on", hint, enabled, role = Role.Switch, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(Icons.Rounded.PowerSettingsNew, null, tint = icon, modifier = Modifier.size(22.dp))
    }
}

@Composable
private fun DeviceName(ui: UiState, store: ACStore, modifier: Modifier) {
    val name = ui.selected?.name ?: "Air conditioner"
    if (ui.devices.size < 2) {
        Text(name, color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.SemiBold, maxLines = 1,
            overflow = TextOverflow.Ellipsis, modifier = modifier)
        return
    }
    var open by remember { mutableStateOf(false) }
    Box(modifier) {
        Row(
            Modifier.clip(RoundedCornerShape(8.dp)).clickable(onClickLabel = "Choose an AC") { open = true }.padding(vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(name, color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Icon(Icons.Rounded.KeyboardArrowDown, null, tint = MitraColors.secondaryText)
        }
        DropdownMenu(open, onDismissRequest = { open = false }) {
            ui.devices.forEach { device ->
                DropdownMenuItem(
                    text = {
                        Column {
                            Text(device.name)
                            device.room?.let { Text(it, fontSize = 12.sp, color = MitraColors.secondaryText) }
                        }
                    },
                    trailingIcon = { if (device.id == ui.selected?.id) Icon(Icons.Rounded.Check, null) },
                    onClick = { open = false; store.select(device.id) },
                )
            }
        }
    }
}

/** The set temperature, large and centred, with the room temperature under it and − / + either side. */
@Composable
private fun Temperature(state: ACState, canControl: Boolean, step: (Double) -> Unit) {
    val alpha by animateFloatAsState(if (state.isOn) 1f else 0.6f, tween(300), label = "temperature")
    val enabled = canControl && state.mode.usesSetpoint
    Row(
        Modifier.fillMaxWidth().alpha(alpha),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        RoundButton(Icons.Rounded.Remove, "Cooler", enabled && state.setpoint > ACState.MIN_TEMPERATURE, size = 56.dp) { step(-1.0) }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            val big = if (state.mode.usesSetpoint) ACState.formatTemperature(state.setpoint).dropLast(1) else "Fan"
            val hint = rememberHint(if (state.mode.usesSetpoint) "Set temperature" else "Fan only: no set temperature")
            Box(Modifier.semantics { contentDescription = if (state.mode.usesSetpoint) "Set to $big degrees" else "Fan only" }) {
                AnimatedContent(
                    targetState = big,
                    transitionSpec = {
                        val up = (targetState.toDoubleOrNull() ?: 0.0) > (initialState.toDoubleOrNull() ?: 0.0)
                        (slideInVertically(tween(280)) { if (up) it / 2 else -it / 2 } + fadeIn(tween(280)))
                            .togetherWith(slideOutVertically(tween(280)) { if (up) -it / 2 else it / 2 } + fadeOut(tween(180)))
                    },
                    contentAlignment = Alignment.Center,
                    label = "setpoint",
                ) { value ->
                    // The degree sign hangs off the number, so the digits themselves sit centred.
                    Box {
                        Text(value, color = Color.White, fontSize = 88.sp, fontFamily = RoundedFamily,
                            fontWeight = FontWeight.ExtraLight, lineHeight = 88.sp)
                        if (state.mode.usesSetpoint) {
                            Text("°", color = Color.White, fontSize = 88.sp, fontFamily = RoundedFamily,
                                fontWeight = FontWeight.ExtraLight, lineHeight = 88.sp,
                                modifier = Modifier.align(Alignment.TopEnd).offset(x = 30.dp))
                        }
                    }
                }
                // Long-press the number to name it.
                Box(Modifier.matchParentSize().hinted("Set temperature", hint, role = Role.Image) {})
            }
            state.roomTemperatureText?.let { room ->
                val roomHint = rememberHint("Room temperature, measured by the AC")
                Row(
                    Modifier.hinted("Room temperature $room", roomHint, role = Role.Image) {},
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Rounded.Thermostat, null, tint = MitraColors.secondaryText, modifier = Modifier.size(18.dp))
                    Text("Room $room", color = MitraColors.secondaryText, fontSize = 16.sp)
                }
            }
        }
        RoundButton(Icons.Rounded.Add, "Warmer", enabled && state.setpoint < ACState.MAX_TEMPERATURE, size = 56.dp) { step(1.0) }
    }
}

/** Up/down and left/right louvers: swing, or one of five fixed positions. */
@Composable
private fun Louvers(state: ACState, canControl: Boolean, store: ACStore) {
    val alpha by animateFloatAsState(if (state.isOn) 1f else 0.6f, tween(300), label = "louvers")
    Column(Modifier.fillMaxWidth().alpha(alpha), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Segments(
            values = listOf(Louver.SWING) + Louver.positions.toList(),
            selection = state.verticalLouver,
            select = { store.send(ACCommand.VerticalLouver(it)) },
            hint = { "Up/down: ${Louver.verticalLabel(it)}" },
            modifier = Modifier.fillMaxWidth(),
            enabled = canControl,
            height = 44.dp,
        ) { position, color -> LouverGlyph(vertical = true, position = position, color = color) }
        Segments(
            values = listOf(Louver.SWING) + Louver.horizontalLeftToRight,
            selection = state.horizontalLouver,
            select = { store.send(ACCommand.HorizontalLouver(it)) },
            hint = { "Left/right: ${Louver.horizontalLabel(it)}" },
            modifier = Modifier.fillMaxWidth(),
            enabled = canControl,
            height = 44.dp,
        ) { position, color -> LouverGlyph(vertical = false, position = position, color = color) }
    }
}

// Controls

@Composable
private fun OfflineBanner(name: String) {
    val shape = RoundedCornerShape(14.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .background(MitraColors.offline.copy(alpha = 0.35f), shape)
            .border(1.dp, MitraColors.offline.copy(alpha = 0.6f), shape)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(Icons.Rounded.WifiOff, null, tint = Color.White, modifier = Modifier.size(18.dp))
        Text("$name is offline. Check its power and Wi-Fi.", color = Color.White, fontSize = 13.sp)
    }
}

@Composable
private fun FanBar(state: ACState, enabled: Boolean, select: (FanSpeed) -> Unit) {
    LabeledBar("Fan", state.fan.title) {
        Segments(FanSpeed.entries, state.fan, select, hint = { it.title }, enabled = enabled, height = 48.dp) { speed, color ->
            when (speed) {
                FanSpeed.AUTO -> FanAutoGlyph(color)
                FanSpeed.MEDIUM -> WindCircleGlyph(color)
                FanSpeed.HIGH -> TornadoGlyph(color)
                else -> Icon(speed.icon, null, tint = color, modifier = Modifier.size(21.dp))
            }
        }
    }
}

private val FanSpeed.icon: ImageVector
    get() = when (this) {
        FanSpeed.QUIET -> Icons.Rounded.Bedtime
        else -> Icons.Rounded.Air
    }

@Composable
private fun ModeBar(state: ACState, ui: UiState, enabled: Boolean, select: (ACMode) -> Unit) {
    LabeledBar("Mode", state.mode.title) {
        Segments(
            ui.selectedCapabilities.modes, state.mode, select, hint = { it.title },
            tint = state.mode.controlTint, prominent = true, enabled = enabled, height = 48.dp,
        ) { mode, color ->
            if (mode == ACMode.FAN) FanGlyph(color) else Icon(mode.icon, null, tint = color, modifier = Modifier.size(21.dp))
        }
    }
}

val ACMode.icon: ImageVector
    get() = when (this) {
        ACMode.AUTO -> Icons.Rounded.AutoAwesome
        ACMode.COOL -> Icons.Rounded.AcUnit
        ACMode.DRY -> Icons.Rounded.WaterDrop
        ACMode.FAN -> Icons.Rounded.Air
        ACMode.HEAT -> Icons.Rounded.WbSunny
    }

/** A plain three-blade fan, for Fan mode. */
@Composable
private fun FanGlyph(color: Color) {
    Box(Modifier.size(20.dp)) { FanBlades(color) }
}

/**
 * Eco, Powerful, Converti7, nanoe X and Display as separate buttons: equal widths, each filled
 * in its own colour while on, named on long-press.
 */
@Composable
private fun Features(state: ACState, ui: UiState, store: ACStore) {
    val enabled = ui.canControl
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        FeatureButton(if (state.eco) Icons.Rounded.Eco else Icons.Outlined.Eco, "Eco: ${onOff(state.eco)}",
            state.eco, MitraColors.eco, Modifier.weight(1f), enabled) { store.send(ACCommand.Eco(!state.eco)) }
        FeatureButton(Icons.Rounded.Bolt, "Powerful: ${onOff(state.powerful)}",
            state.powerful, MitraColors.powerful, Modifier.weight(1f), enabled) { store.send(ACCommand.Powerful(!state.powerful)) }
        if (ui.selectedCapabilities.converti) {
            ConvertiButton(state.converti ?: Converti.OFF, enabled, Modifier.weight(1f)) { store.send(ACCommand.ConvertiLevel(it)) }
        }
        if (ui.selectedCapabilities.nanoe) {
            val nanoe = state.nanoe ?: false
            FeatureButton(Icons.Rounded.BubbleChart, "nanoe X air purifier: ${onOff(nanoe)}",
                nanoe, MitraColors.nanoe, Modifier.weight(1f), enabled) { store.send(ACCommand.Nanoe(!nanoe)) }
        }
        // The same colour as the AC's own display.
        FeatureButton(if (state.display) Icons.Rounded.Lightbulb else Icons.Outlined.Lightbulb, "Display: ${onOff(state.display)}",
            state.display, MitraColors.bulb, Modifier.weight(1f), enabled, iconColor = MitraColors.bulbIcon,
        ) { store.send(ACCommand.Display(!state.display)) }
    }
}

/** The Converti7 button; opens a menu of cooling levels. */
@Composable
private fun ConvertiButton(level: Int, enabled: Boolean, modifier: Modifier, select: (Int) -> Unit) {
    var open by remember { mutableStateOf(false) }
    val isOn = level != Converti.OFF
    Box(modifier) {
        FeatureButton(Icons.Rounded.Adjust, if (isOn) "Converti7: $level%" else "Converti7: off",
            isOn, MitraColors.converti, Modifier.fillMaxWidth(), enabled) { open = true }
        DropdownMenu(open, onDismissRequest = { open = false }) {
            Text("Converti7 cooling", fontSize = 12.sp, color = MitraColors.secondaryText,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp))
            (listOf(Converti.OFF) + Converti.levels.reversed()).forEach { value ->
                DropdownMenuItem(
                    text = { Text(if (value == Converti.OFF) "Off" else "$value%") },
                    trailingIcon = { if (value == level) Icon(Icons.Rounded.Check, null) },
                    onClick = { open = false; select(value) },
                )
            }
        }
    }
}

private fun onOff(on: Boolean) = if (on) "on" else "off"
