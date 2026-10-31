package com.midoreigh.mitra.ui

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectVerticalDragGestures
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.midoreigh.mitra.model.ACState
import com.midoreigh.mitra.model.SleepProfile
import kotlin.math.roundToInt

/**
 * Edits one profile, full screen: its name, a bar for each hour (drag to set the temperature)
 * and whether the AC turns off at the end.
 */
@Composable
fun SleepProfileEditor(initial: SleepProfile, isNew: Boolean, save: (SleepProfile) -> Unit, delete: () -> Unit, close: () -> Unit) {
    var profile by remember { mutableStateOf(initial) }
    Dialog(close, DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
        Column(
            Modifier
                .fillMaxSize()
                .background(MitraColors.night)
                .padding(top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding())
                .verticalScroll(rememberScrollState())
                .padding(bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + 24.dp),
        ) {
            Row(Modifier.padding(horizontal = 4.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                IconButton(close) { Icon(Icons.Rounded.Close, "Cancel", tint = Color.White) }
                Text(if (isNew) "New profile" else "Edit profile", color = Color.White, fontSize = 22.sp,
                    fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                TextButton({ save(profile.copy(name = profile.name.trim())); close() }, enabled = profile.name.isNotBlank()) {
                    Text("Save", fontSize = 16.sp)
                }
            }
            Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
                OutlinedTextField(profile.name, { profile = profile.copy(name = it) }, label = { Text("Name") },
                    singleLine = true, modifier = Modifier.fillMaxWidth())
                HourBars(profile.temperatures) { profile = profile.copy(temperatures = it) }
                Text("Drag a bar up or down to set that hour's temperature. Long-press a bar to remove it.",
                    color = MitraColors.secondaryText, fontSize = 13.sp)
                Row(
                    Modifier.fillMaxWidth().clickable { profile = profile.copy(turnsOffAtEnd = !profile.turnsOffAtEnd) },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text("Turn the AC off when the profile ends", color = Color.White, modifier = Modifier.weight(1f))
                    Switch(
                        profile.turnsOffAtEnd, { profile = profile.copy(turnsOffAtEnd = it) },
                        colors = SwitchDefaults.colors(checkedTrackColor = MitraColors.sleep, checkedThumbColor = Color.White),
                    )
                }
                if (!isNew) {
                    TextButton({ delete(); close() }) { Text("Delete profile", color = Color(0xFFFF6B60), fontSize = 15.sp) }
                }
            }
        }
    }
}

/** One bar per hour, up to eight, with a + after the last to add another. */
@Composable
private fun HourBars(temperatures: List<Double>, change: (List<Double>) -> Unit) {
    val height = 220.dp
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.Bottom) {
        temperatures.forEachIndexed { index, value ->
            Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                HourBar(value, height, canRemove = temperatures.size > 1, label = "Hour ${index + 1}",
                    set = { change(temperatures.toMutableList().apply { this[index] = it }) },
                    remove = { change(temperatures.toMutableList().apply { removeAt(index) }) })
                Text("${index + 1} h", color = MitraColors.secondaryText, fontSize = 12.sp, modifier = Modifier.padding(top = 6.dp))
            }
        }
        if (temperatures.size < SleepProfile.HOURS.last) {
            Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                Box(
                    Modifier
                        .fillMaxWidth()
                        .height(52.dp)
                        .border(1.dp, MitraColors.secondaryText.copy(alpha = 0.5f), RoundedCornerShape(10.dp))
                        .clickable(onClickLabel = "Add an hour") { change(temperatures + (temperatures.lastOrNull() ?: 26.0)) },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Rounded.Add, "Add an hour", tint = MitraColors.secondaryText)
                }
                Text("${temperatures.size + 1} h", color = MitraColors.secondaryText.copy(alpha = 0.5f), fontSize = 12.sp,
                    modifier = Modifier.padding(top = 6.dp))
            }
        }
        // Keeps bars the same width however many hours there are.
        repeat(SleepProfile.HOURS.last - temperatures.size - 1) { Spacer(Modifier.weight(1f)) }
    }
}

@Composable
private fun HourBar(value: Double, height: Dp, canRemove: Boolean, label: String,
                    set: (Double) -> Unit, remove: () -> Unit) {
    val range = ACState.MIN_TEMPERATURE..ACState.MAX_TEMPERATURE
    val share = 0.12f + 0.88f * ((value - range.start) / (range.endInclusive - range.start)).toFloat()
    val barHeight by animateDpAsState(height * share, tween(120), label = "bar")
    var menu by remember { mutableStateOf(false) }
    val currentSet by rememberUpdatedState(set)
    BoxWithConstraints(Modifier.fillMaxWidth().height(height)) {
        val total = constraints.maxHeight.toFloat()
        fun at(y: Float) {
            val picked = 1 - (y / total).coerceIn(0f, 1f)
            val degrees = range.start + (picked - 0.12) / 0.88 * (range.endInclusive - range.start)
            currentSet(degrees.roundToInt().toDouble().coerceIn(range.start, range.endInclusive))
        }
        Box(
            Modifier
                .fillMaxSize()
                .pointerInput(canRemove) {
                    detectTapGestures(onTap = { at(it.y) }, onLongPress = { if (canRemove) menu = true })
                }
                .pointerInput(Unit) {
                    detectVerticalDragGestures { change, _ -> at(change.position.y) }
                },
            contentAlignment = Alignment.BottomCenter,
        ) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(barHeight)
                    .background(
                        Brush.verticalGradient(listOf(Color(0xFF6B5CDB), Color(0xFF8CBFFF))),
                        RoundedCornerShape(topStart = 10.dp, topEnd = 10.dp, bottomStart = 4.dp, bottomEnd = 4.dp),
                    ),
                contentAlignment = Alignment.TopCenter,
            ) {
                Text("${value.toInt()}°", color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.padding(top = 6.dp))
            }
            DropdownMenu(menu, onDismissRequest = { menu = false }) {
                DropdownMenuItem(text = { Text("Remove $label") }, onClick = { menu = false; remove() })
            }
        }
    }
}

/** Settings' list of the user's sleep profiles. */
@Composable
fun SleepProfileList(profiles: List<SleepProfile>, edit: (SleepProfile) -> Unit) {
    profiles.forEach { profile ->
        Row(
            Modifier.fillMaxWidth().clickable(onClickLabel = "Edit") { edit(profile) }.padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f)) {
                Text(profile.name, color = Color.White)
                Text(profile.summary, color = MitraColors.secondaryText, fontSize = 13.sp)
            }
            Text("Edit", color = ACModeAccent, fontSize = 14.sp)
        }
        HorizontalDivider(color = MitraColors.glassBorder)
    }
    Row(
        Modifier.fillMaxWidth().clickable { edit(SleepProfile.new()) }.padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Rounded.Add, null, tint = ACModeAccent, modifier = Modifier.padding(end = 8.dp))
        Text("New profile", color = ACModeAccent)
    }
}

private val ACModeAccent = Color(0xFF8CB8FF)
