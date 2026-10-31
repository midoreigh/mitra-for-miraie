package com.midoreigh.mitra.ui

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Air
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntRect
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupPositionProvider
import com.midoreigh.mitra.model.Louver
import kotlinx.coroutines.delay
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/**
 * Makes something tappable, with a hint naming it on long-press: shown above it (below only
 * when there's no room), so it never covers the control, and never after a plain tap.
 */
@OptIn(ExperimentalFoundationApi::class)
fun Modifier.hinted(
    hint: String,
    hintState: HintState,
    enabled: Boolean = true,
    role: Role = Role.Button,
    onClick: () -> Unit,
): Modifier = this
    .semantics { contentDescription = hint }
    .combinedClickable(
        enabled = enabled,
        role = role,
        onClickLabel = hint,
        onLongClick = { hintState.show() },
        onClick = onClick,
    )

class HintState {
    var visible by mutableStateOf(false)
        private set
    private var shown = 0
    var pending by mutableStateOf(0)
        private set

    fun show() {
        visible = true
        pending = ++shown
    }

    fun hide() {
        visible = false
    }
}

/** Remembers a hint for one control, and draws it while it's showing. */
@Composable
fun rememberHint(text: String): HintState {
    val state = remember { HintState() }
    val haptics = LocalHapticFeedback.current
    if (state.visible) {
        LaunchedEffect(state.pending) {
            haptics.performHapticFeedback(HapticFeedbackType.LongPress)
            delay(1_800)
            state.hide()
        }
        Popup(popupPositionProvider = AboveProvider, onDismissRequest = state::hide) {
            Text(
                text,
                color = Color.White,
                fontSize = 13.sp,
                modifier = Modifier
                    .background(Color(0xF0262A36), RoundedCornerShape(8.dp))
                    .border(1.dp, MitraColors.glassBorder, RoundedCornerShape(8.dp))
                    .padding(horizontal = 10.dp, vertical = 6.dp),
            )
        }
    }
    return state
}

private object AboveProvider : PopupPositionProvider {
    override fun calculatePosition(anchorBounds: IntRect, windowSize: IntSize, layoutDirection: LayoutDirection, popupContentSize: IntSize): IntOffset {
        val gap = 12
        val x = (anchorBounds.center.x - popupContentSize.width / 2)
            .coerceIn(16, (windowSize.width - popupContentSize.width - 16).coerceAtLeast(16))
        val above = anchorBounds.top - popupContentSize.height - gap
        val y = if (above >= 0) above else anchorBounds.bottom + gap
        return IntOffset(x, y)
    }
}

/** A bar's glass capsule. */
fun Modifier.glass(shape: androidx.compose.ui.graphics.Shape = CircleShape): Modifier = this
    .clip(shape)
    .background(MitraColors.glass, shape)
    .border(1.dp, MitraColors.glassBorder, shape)

/**
 * A row of choices in one glass capsule, all the same width; a pill slides to the chosen one.
 * [prominent] fills it with [tint]; otherwise it's solid white with a dark icon, just as clear
 * without adding more colour.
 */
@Composable
fun <T> Segments(
    values: List<T>,
    selection: T,
    select: (T) -> Unit,
    hint: (T) -> String,
    modifier: Modifier = Modifier,
    tint: Color = Color.White,
    prominent: Boolean = false,
    enabled: Boolean = true,
    height: Dp = 40.dp,
    content: @Composable (value: T, color: Color) -> Unit,
) {
    BoxWithConstraints(modifier.fillMaxWidth().height(height).glass().padding(3.dp)) {
        val width = maxWidth / values.size
        val index = values.indexOf(selection)
        val offset by animateDpAsState(width * index.coerceAtLeast(0), spring(dampingRatio = 0.8f, stiffness = Spring.StiffnessMediumLow), label = "pill")
        val fill by animateColorAsState(if (prominent) tint else Color.White.copy(alpha = 0.92f), tween(250), label = "fill")
        if (index >= 0) {
            Box(Modifier.offset(x = offset).width(width).fillMaxHeight().background(fill, CircleShape))
        }
        Row(Modifier.fillMaxWidth().fillMaxHeight()) {
            values.forEach { value ->
                val isSelected = value == selection
                val hintState = rememberHint(hint(value))
                val color by animateColorAsState(
                    when {
                        !isSelected -> MitraColors.secondaryText
                        prominent -> Color.White
                        else -> Color(0xFF111318)
                    },
                    tween(200), label = "icon",
                )
                Box(
                    Modifier
                        .width(width)
                        .fillMaxHeight()
                        .clip(CircleShape)
                        .semantics { selected = isSelected }
                        .hinted(hint(value), hintState, enabled) { select(value) },
                    contentAlignment = Alignment.Center,
                ) {
                    content(value, color)
                }
            }
        }
    }
}

/** A bar with its name and current value on the left, e.g. "Fan / Auto". */
@Composable
fun LabeledBar(title: String, value: String, bar: @Composable () -> Unit) {
    // The label sits above, so the bar gets the full width of the phone.
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(Modifier.padding(start = 4.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("$title · ", fontSize = 13.sp, color = MitraColors.secondaryText, maxLines = 1)
            Text(value, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Color.White, maxLines = 1)
        }
        bar()
    }
}

/** A round glass button with an icon. */
@Composable
fun RoundButton(icon: ImageVector, hint: String, enabled: Boolean = true, size: Dp = 44.dp, onClick: () -> Unit) {
    val hintState = rememberHint(hint)
    Box(
        Modifier
            .size(size)
            .alpha(if (enabled) 1f else 0.4f)
            .clip(CircleShape)
            .background(Color(0x40000000), CircleShape)
            .border(1.dp, MitraColors.glassBorder, CircleShape)
            .hinted(hint, hintState, enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = Color.White, modifier = Modifier.size(size * 0.5f))
    }
}

/**
 * One louver position drawn as a vane: up/down tilts from level to pointing down, left/right
 * leans from far left to far right. Swing shows a double arrow instead.
 */
@Composable
fun LouverGlyph(vertical: Boolean, position: Int, color: Color) {
    Canvas(Modifier.size(16.dp)) {
        val stroke = 2.dp.toPx()
        if (position == Louver.SWING) {
            val l = size.minDimension * 0.85f
            val c = center
            val head = l * 0.28f
            val (a, b) = if (vertical) Offset(c.x, c.y - l / 2) to Offset(c.x, c.y + l / 2)
            else Offset(c.x - l / 2, c.y) to Offset(c.x + l / 2, c.y)
            drawLine(color, a, b, stroke, StrokeCap.Round)
            val arrow = Path().apply {
                if (vertical) {
                    moveTo(a.x - head, a.y + head); lineTo(a.x, a.y); lineTo(a.x + head, a.y + head)
                    moveTo(b.x - head, b.y - head); lineTo(b.x, b.y); lineTo(b.x + head, b.y - head)
                } else {
                    moveTo(a.x + head, a.y - head); lineTo(a.x, a.y); lineTo(a.x + head, a.y + head)
                    moveTo(b.x - head, b.y - head); lineTo(b.x, b.y); lineTo(b.x - head, b.y + head)
                }
            }
            drawPath(arrow, color, style = Stroke(stroke, cap = StrokeCap.Round, join = androidx.compose.ui.graphics.StrokeJoin.Round))
            return@Canvas
        }
        val length = size.minDimension * 0.85f
        if (vertical) {
            val angle = (com.midoreigh.mitra.ui.LouverAngles.vertical(position) * PI / 180).toFloat()
            val pivot = Offset((size.width - length * cos(angle)) / 2, (size.height - length * sin(angle)) / 2)
            drawLine(color, pivot, Offset(pivot.x + length * cos(angle), pivot.y + length * sin(angle)), stroke, StrokeCap.Round)
            drawCircle(color, 2.dp.toPx(), pivot)
        } else {
            val angle = (com.midoreigh.mitra.ui.LouverAngles.horizontal(position) * PI / 180).toFloat()
            val top = Offset(size.width / 2 - length / 2 * sin(angle), (size.height - length) / 2)
            drawLine(color, top, Offset(top.x + length * sin(angle), top.y + length * cos(angle)), stroke, StrokeCap.Round)
        }
    }
}

/** Three fan blades filling their space. */
@Composable
fun FanBlades(color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier.fillMaxSize()) {
        val c = center
        val r = size.minDimension / 2
        for (i in 0 until 3) {
            val a = i * 2 * PI / 3 - PI / 2
            val blade = Path().apply {
                moveTo(c.x, c.y)
                val tipX = c.x + (r * 0.95f * cos(a)).toFloat()
                val tipY = c.y + (r * 0.95f * sin(a)).toFloat()
                val side = a + 0.9
                quadraticTo(c.x + (r * cos(side)).toFloat(), c.y + (r * sin(side)).toFloat(), tipX, tipY)
                quadraticTo(c.x + (r * 0.35f * cos(a - 0.3)).toFloat(), c.y + (r * 0.35f * sin(a - 0.3)).toFloat(), c.x, c.y)
                close()
            }
            drawPath(blade, color)
        }
        drawCircle(color, r * 0.16f, c)
    }
}

/** A fan with an "A": automatic fan speed. */
@Composable
fun FanAutoGlyph(color: Color) {
    Box(Modifier.size(22.dp)) {
        Box(Modifier.size(18.dp).align(Alignment.TopStart)) { FanBlades(color) }
        Text(
            "A", color = color, fontSize = 9.sp, fontWeight = FontWeight.Black, lineHeight = 9.sp,
            modifier = Modifier.align(Alignment.BottomEnd),
        )
    }
}

/** Wind in a circle: medium fan speed. */
@Composable
fun WindCircleGlyph(color: Color) {
    Box(Modifier.size(21.dp).border(1.6.dp, color, CircleShape), contentAlignment = Alignment.Center) {
        Icon(Icons.Rounded.Air, null, tint = color, modifier = Modifier.size(13.dp))
    }
}

/** Fan blades with motion arcs sweeping round them: a fan at full speed, for high fan speed. */
@Composable
fun SpinningFanGlyph(color: Color) {
    Box(Modifier.size(22.dp), contentAlignment = Alignment.Center) {
        Box(Modifier.size(14.dp)) { FanBlades(color) }
        Canvas(Modifier.fillMaxSize()) {
            val stroke = Stroke(1.7.dp.toPx(), cap = StrokeCap.Round)
            val inset = stroke.width / 2
            val arcSize = Size(size.width - stroke.width, size.height - stroke.width)
            // Two sweeping arcs on opposite sides, so it reads as turning.
            listOf(195f to 75f, 15f to 75f).forEach { (startAngle, sweep) ->
                drawArc(color, startAngle, sweep, false, Offset(inset, inset), arcSize, style = stroke)
            }
        }
    }
}

/** One feature button: an icon, filled in the feature's colour while on. */
@Composable
fun FeatureButton(
    icon: ImageVector,
    hint: String,
    isOn: Boolean,
    tint: Color,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    /** The icon's colour while on. */
    iconColor: Color = Color.White,
    onClick: () -> Unit,
) {
    val hintState = rememberHint(hint)
    val fill by animateColorAsState(if (isOn) tint else MitraColors.glass, tween(150), label = "feature")
    val shape = RoundedCornerShape(50)
    Box(
        modifier
            .height(50.dp)
            .clip(shape)
            .background(fill, shape)
            .border(1.dp, if (isOn) Color.Transparent else MitraColors.glassBorder, shape)
            .semantics { selected = isOn }
            .hinted(hint, hintState, enabled, role = Role.Switch, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        // Disabled, the panel dims the fill, so a dark icon (the bulb's) would vanish into it.
        val onColor = if (enabled) iconColor else Color.White
        Icon(icon, null, tint = if (isOn) onColor else MitraColors.secondaryText, modifier = Modifier.size(22.dp))
    }
}
