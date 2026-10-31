package com.midoreigh.mitra.ui

import android.text.format.DateFormat
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Bed
import androidx.compose.material.icons.outlined.Timer
import androidx.compose.material.icons.rounded.Bed
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.midoreigh.mitra.model.ACCommand
import com.midoreigh.mitra.model.ACState
import com.midoreigh.mitra.model.SleepProfile
import com.midoreigh.mitra.store.ACStore
import com.midoreigh.mitra.store.UiState
import kotlinx.coroutines.delay
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Timer and Sleep get a row of their own, named and showing what's set: few apps offer these,
 * so they're easy to find. Each opens a sheet.
 */
@Composable
fun ScheduleButtons(ui: UiState, store: ACStore, editProfiles: (() -> Unit)?) {
    val state = ui.state
    val clock = rememberClock()
    val now = rememberNow()
    var sheet by remember { mutableStateOf<String?>(null) }
    val offTimer = state.offTimer?.takeIf { it > now }
    val onTimer = state.onTimer?.takeIf { it > now }
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        val timers = listOfNotNull(offTimer?.let { "Off at ${clock.time(it, now)}" }, onTimer?.let { "On at ${clock.time(it, now)}" })
        // The sooner timer; both are listed under the AC.
        val next = listOfNotNull(offTimer?.let { "Off" to it }, onTimer?.let { "On" to it }).minByOrNull { it.second }
        ScheduleButton(
            title = "Timer",
            detail = next?.let { "${it.first} at ${clock.time(it.second, now)}" } ?: "Off or on later",
            hint = timers.joinToString(" · ").ifEmpty { "Turn the AC off or on at a set time" },
            icon = if (next != null) Icons.Rounded.Timer else Icons.Outlined.Timer,
            isOn = next != null, tint = MitraColors.timer, enabled = ui.canControl, modifier = Modifier.weight(1f),
        ) { sheet = "timer" }
        val running = ui.runningSleepProfile
        ScheduleButton(
            title = "Sleep",
            detail = when {
                state.sleepProfile == null -> "Hour by hour"
                else -> running?.name ?: "Profile on"
            },
            hint = when {
                state.sleepProfile == null -> "A set temperature for each hour of the night"
                running == null -> "A profile started in the MirAIe app is on"
                else -> "${running.name}: ${running.progress(state.sleepHour).lowercase()}"
            },
            icon = if (state.sleepProfile != null) Icons.Rounded.Bed else Icons.Outlined.Bed,
            isOn = state.sleepProfile != null, tint = MitraColors.sleep, enabled = ui.canControl, modifier = Modifier.weight(1f),
        ) { sheet = "sleep" }
    }
    when (sheet) {
        "timer" -> TimerSheet(state, store) { sheet = null }
        "sleep" -> SleepSheet(ui, store, editProfiles?.let { edit -> { sheet = null; edit() } }) { sheet = null }
    }
}

/**
 * A wide button with its name and what's set. While something is set, its icon sits in a
 * disc of the feature's colour and the button takes a tint of it.
 */
@Composable
private fun ScheduleButton(
    title: String,
    detail: String,
    hint: String,
    icon: ImageVector,
    isOn: Boolean,
    tint: Color,
    enabled: Boolean,
    modifier: Modifier,
    onClick: () -> Unit,
) {
    val hintState = rememberHint(hint)
    val shape = RoundedCornerShape(50)
    val wash by animateColorAsState(if (isOn && enabled) tint.copy(alpha = 0.22f) else Color.Transparent, tween(200), label = "wash")
    val disc by animateColorAsState(if (isOn) tint else Color(0x1FFFFFFF), tween(200), label = "disc")
    Row(
        modifier
            .height(56.dp)
            .glass(shape)
            .background(wash, shape)
            .hinted("$title: $detail", hintState, enabled, onClick = onClick)
            .padding(start = 8.dp, end = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier.size(38.dp).background(
                if (isOn) Brush.verticalGradient(listOf(disc.mix(Color.White, 0.18f), disc)) else Brush.linearGradient(listOf(disc, disc)),
                CircleShape,
            ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, null, tint = Color.White, modifier = Modifier.size(21.dp))
        }
        Spacer(Modifier.width(10.dp))
        Column {
            Text(title, color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
            AnimatedContent(detail, transitionSpec = { fadeIn(tween(200)) togetherWith fadeOut(tween(150)) }, label = "detail") {
                Text(it, color = MitraColors.secondaryText, fontSize = 12.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

/** What the AC will do by itself, as glass capsules under it: its sleep profile and timers. */
@Composable
fun ScheduleLabels(ui: UiState, modifier: Modifier = Modifier) {
    val state = ui.state
    val clock = rememberClock()
    val now = rememberNow()
    val labels = buildList {
        if (state.sleepProfile != null) {
            // A profile started in the MirAIe app: its name and length aren't sent to the AC,
            // so which hour it's on means little.
            val known = ui.runningSleepProfile
            val hour = state.sleepHour?.let { " · hour ${minOf(it + 1, known?.temperatures?.size ?: 0)} of ${known?.temperatures?.size}" }
            add(Icons.Rounded.Bed to if (known != null) known.name + (hour.takeIf { !known.isGentle } ?: "") else "Sleep profile on")
        }
        state.offTimer?.takeIf { it > now }?.let { add(Icons.Rounded.Timer to "Off at ${clock.time(it, now)}") }
        state.onTimer?.takeIf { it > now }?.let { add(Icons.Rounded.Timer to "On at ${clock.time(it, now)}") }
    }
    if (labels.isEmpty() || !state.isOnline) return
    // Three long ones don't fit across a phone, so they wrap.
    FlowRow(
        modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        labels.forEach { (icon, text) ->
            val shape = CircleShape
            Row(
                Modifier
                    .background(Color(0x66101420), shape)
                    .glass(shape)
                    .padding(horizontal = 10.dp, vertical = 5.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(5.dp),
            ) {
                Icon(icon, null, tint = Color.White, modifier = Modifier.size(14.dp))
                Text(text, color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Medium, maxLines = 1)
            }
        }
    }
}

// Timer

/**
 * When the AC should turn itself off and on. Both live in the AC, so they work with the
 * phone off. Changes go to the AC a moment after the last edit, or when the sheet closes.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TimerSheet(initial: ACState, store: ACStore, dismiss: () -> Unit) {
    val now = rememberNow()
    var off by remember { mutableStateOf(initial.offTimer?.takeIf { it > now }) }
    var on by remember { mutableStateOf(initial.onTimer?.takeIf { it > now }) }
    fun flush() {
        val state = store.ui.value.state
        if (same(off, state.offTimer) && same(on, state.onTimer)) return
        store.send(ACCommand.Timers(off?.let(::upcoming), on?.let(::upcoming)))
    }
    LaunchedEffect(off, on) {
        delay(800)
        flush()
    }
    DisposableEffect(Unit) { onDispose { flush() } }

    ModalBottomSheet(onDismissRequest = dismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = MitraColors.surface) {
        Column(Modifier.padding(start = 24.dp, end = 24.dp, bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text("Timer", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.SemiBold)
            TimerRow("Turn off", off, { off = it }, suggested = { System.currentTimeMillis() + 3_600_000 }, quickPicks = listOf(30, 60, 120, 240))
            HorizontalDivider(color = MitraColors.glassBorder)
            TimerRow("Turn on", on, { on = it }, suggested = { next(7, 0) }, quickPicks = emptyList())
            Text("Your AC keeps its timers itself, so they work even while your phone is off.",
                color = MitraColors.secondaryText, fontSize = 13.sp)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TimerRow(
    title: String,
    date: Long?,
    set: (Long?) -> Unit,
    suggested: () -> Long,
    /** Minutes from now. */
    quickPicks: List<Int>,
) {
    val clock = rememberClock()
    val now = rememberNow()
    var picking by remember { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(title, color = Color.White, fontSize = 17.sp, fontWeight = FontWeight.Medium)
                Text(date?.let { clock.relative(it, now) } ?: "Not set", color = MitraColors.secondaryText, fontSize = 13.sp)
            }
            val shown = date ?: toMinute(suggested())
            Text(
                clock.time(shown, now, withDay = false),
                color = Color.White, fontSize = 17.sp, fontWeight = FontWeight.Medium,
                modifier = Modifier
                    .alpha(if (date != null) 1f else 0.45f)
                    .glass(RoundedCornerShape(12.dp))
                    .clickable(enabled = date != null, onClickLabel = "Change the time") { picking = true }
                    .padding(horizontal = 14.dp, vertical = 8.dp),
            )
            Spacer(Modifier.width(14.dp))
            Switch(
                date != null, { set(if (it) toMinute(suggested()) else null) },
                colors = SwitchDefaults.colors(checkedTrackColor = MitraColors.timer, checkedThumbColor = Color.White),
            )
        }
        if (quickPicks.isNotEmpty()) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                quickPicks.forEach { minutes ->
                    Text(
                        if (minutes < 60) "$minutes min" else "${minutes / 60} h",
                        color = Color.White, fontSize = 14.sp,
                        modifier = Modifier
                            .glass()
                            .clickable { set(toMinute(System.currentTimeMillis() + minutes * 60_000L)) }
                            .padding(horizontal = 14.dp, vertical = 7.dp),
                    )
                }
            }
        }
    }
    if (picking) {
        val zoned = Instant.ofEpochMilli(date ?: suggested()).atZone(ZoneId.systemDefault())
        val picker = rememberTimePickerState(zoned.hour, zoned.minute, clock.is24Hour)
        AlertDialog(
            onDismissRequest = { picking = false },
            confirmButton = { TextButton({ picking = false; set(next(picker.hour, picker.minute)) }) { Text("OK") } },
            dismissButton = { TextButton({ picking = false }) { Text("Cancel") } },
            title = { Text(title) },
            text = { TimePicker(picker) },
            containerColor = MitraColors.surface,
        )
    }
}

/** Equal to the minute, or both unset: the AC's clock can be a few seconds out. */
private fun same(a: Long?, b: Long?): Boolean =
    if (a == null || b == null) a == b else abs(a - b) < 60_000

private fun toMinute(ms: Long): Long = (ms / 60_000.0).roundToInt() * 60_000L

/** The next time it's this time of day: today if that's still ahead, otherwise tomorrow. */
private fun upcoming(ms: Long): Long {
    val time = Instant.ofEpochMilli(ms).atZone(ZoneId.systemDefault())
    return next(time.hour, time.minute)
}

private fun next(hour: Int, minute: Int): Long {
    val now = System.currentTimeMillis()
    val today = LocalDate.now().atTime(hour, minute).atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
    return if (today > now + 30_000) today else today + 24 * 3_600_000L
}

// Sleep

/** Start or stop a profile. Profiles are made in Settings. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SleepSheet(ui: UiState, store: ACStore, editProfiles: (() -> Unit)?, dismiss: () -> Unit) {
    val state = ui.state
    ModalBottomSheet(onDismissRequest = dismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = MitraColors.surface) {
        Column(Modifier.padding(start = 16.dp, end = 16.dp, bottom = 16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("Sleep", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(start = 8.dp, bottom = 8.dp))
            val profiles = ui.allSleepProfiles + listOfNotNull(
                // Started from the MirAIe app: Mitra doesn't know its name or hours.
                state.sleepProfile?.takeIf { ui.runningSleepProfile == null }?.let { SleepProfile.unknown(it) },
            )
            profiles.forEach { profile -> SleepRow(profile, state, store) }
            if (!state.isOn) {
                Text("Turn your AC on to start a profile.", color = MitraColors.secondaryText, fontSize = 13.sp,
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 6.dp))
            }
            if (editProfiles != null) {
                HorizontalDivider(color = MitraColors.glassBorder, modifier = Modifier.padding(vertical = 6.dp))
                TextButton(editProfiles) { Text("Edit profiles…", fontSize = 15.sp) }
            }
        }
    }
}

@Composable
private fun SleepRow(profile: SleepProfile, state: ACState, store: ACStore) {
    val running = state.sleepProfile == profile.id
    val shape = RoundedCornerShape(16.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .background(if (running) MitraColors.sleep.copy(alpha = 0.35f) else Color.Transparent, shape)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(profile.name, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Medium)
            Text(
                if (running && !profile.isGentle) profile.progress(state.sleepHour) else profile.summary,
                color = MitraColors.secondaryText, fontSize = 13.sp, maxLines = 2,
            )
        }
        Spacer(Modifier.width(12.dp))
        if (running) {
            OutlinedButton(store::stopSleep) { Text("Stop") }
        } else {
            Button(
                { store.send(ACCommand.StartSleep(profile)) }, enabled = state.isOn,
                colors = ButtonDefaults.buttonColors(containerColor = MitraColors.sleep, contentColor = Color.White),
            ) { Text("Start") }
        }
    }
}

// Time

/** Formats times the way the phone is set: 12- or 24-hour. */
class Clock(val is24Hour: Boolean) {
    private val pattern = if (is24Hour) "HH:mm" else "h:mm a"
    private val timeOnly = DateTimeFormatter.ofPattern(pattern)
    private val withWeekday = DateTimeFormatter.ofPattern("EEE $pattern")

    /** "9:20 PM", or "Tue 7:00 AM" when it's not in the next day. */
    fun time(ms: Long, now: Long, withDay: Boolean = true): String {
        val zoned = Instant.ofEpochMilli(ms).atZone(ZoneId.systemDefault())
        return if (!withDay || ms - now < 20 * 3_600_000L) timeOnly.format(zoned) else withWeekday.format(zoned)
    }

    /** "In 3 h 50 min, at 9:20 PM" or "Tomorrow at 7:00 AM". */
    fun relative(ms: Long, now: Long): String {
        val minutes = ((ms - now) / 60_000.0).roundToInt().coerceAtLeast(0)
        val time = time(ms, now, withDay = false)
        val day = Instant.ofEpochMilli(ms).atZone(ZoneId.systemDefault()).toLocalDate()
        val today = LocalDate.now()
        if (minutes >= 12 * 60 && day != today) return if (day == today.plusDays(1)) "Tomorrow at $time" else time
        val hours = minutes / 60
        val rest = minutes % 60
        val span = when {
            hours == 0 -> "$rest min"
            rest == 0 -> "$hours h"
            else -> "$hours h $rest min"
        }
        return "In $span, at $time"
    }
}

@Composable
fun rememberClock(): Clock {
    val context = LocalContext.current
    return remember(context) { Clock(DateFormat.is24HourFormat(context)) }
}

/** The time now, updated every half minute, so countdowns and passed timers stay current. */
@Composable
fun rememberNow(): Long {
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(30_000 - now % 30_000)
            now = System.currentTimeMillis()
        }
    }
    return now
}
