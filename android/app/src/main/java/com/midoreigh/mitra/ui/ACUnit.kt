package com.midoreigh.mitra.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.midoreigh.mitra.model.ACMode
import com.midoreigh.mitra.model.ACState
import com.midoreigh.mitra.model.FanSpeed
import com.midoreigh.mitra.model.Louver
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.tan

/**
 * Where the louvers point at a moment in time, in degrees. Fixed positions map to fixed
 * angles; swing sweeps continuously, the way the real louvers do.
 */
data class LouverAngles(
    /** Below horizontal: about 12° (level, blowing at you) to 72° (straight down). */
    val vertical: Double,
    /** Left (negative) to right (positive). */
    val horizontal: Double,
) {
    companion object {
        fun of(state: ACState, time: Double): LouverAngles = LouverAngles(
            // Real louvers swing slowly: about 18 s for a full up-down-up sweep and 22 s for
            // left-right-left.
            vertical = if (state.verticalLouver == Louver.SWING) 42 + 28 * sin(time * 2 * PI / 18)
            else vertical(state.verticalLouver),
            horizontal = if (state.horizontalLouver == Louver.SWING) 30 * sin(time * 2 * PI / 22 + 1)
            else horizontal(state.horizontalLouver),
        )

        fun vertical(position: Int): Double = 12.0 + (position - 1) * 15
        fun horizontal(position: Int): Double = (Louver.horizontalSlot(position) - 3) * 17.0
    }
}

/**
 * One bit of air on its way from the outlet: which stream it's in, how far it has gone (0 to
 * 1), how fast it travels, and the fan speed and mode it left the unit with, which set its
 * colour and whether it sinks or rises.
 */
class AirParticle(
    val stream: Int,
    /** Varies its brightness, so the air doesn't look uniform. */
    val seed: Double,
    var progress: Double,
    val speed: Double,
    val fan: FanSpeed,
    val mode: ACMode,
)

/**
 * Carries the animation from one frame to the next, so changes ease in rather than jump:
 * the louvers travel to a new position at a brisk but visible pace (faster than they swing),
 * and each bit of air keeps the fan speed and mode it left the unit with, so a change flows
 * out from the outlet instead of the whole room changing at once.
 */
class AirMotion {
    private var vertical: Double? = null
    private var horizontal: Double? = null
    private var lastTime: Double? = null
    private val air = mutableListOf<AirParticle>()
    private var airTime: Double? = null
    /**
     * For each stream, progress towards releasing its next bit of air, and how far apart (on
     * average 1) the next release is, so the air comes out irregularly rather than in rows.
     */
    private var release = DoubleArray(0)
    private var gap = DoubleArray(0)
    private var released = 0

    fun angles(state: ACState, time: Double): LouverAngles {
        val target = LouverAngles.of(state, time)
        // A long gap (the animation was paused) shouldn't turn into one big jump.
        val elapsed = lastTime?.let { min(0.1, max(0.0, time - it)) } ?: 0.0
        lastTime = time
        val step = LOUVER_SPEED * elapsed
        fun approach(current: Double?, goal: Double): Double =
            current?.let { it + (goal - it).coerceIn(-step, step) } ?: goal
        val next = LouverAngles(approach(vertical, target.vertical), approach(horizontal, target.horizontal))
        vertical = next.vertical
        horizontal = next.horizontal
        return next
    }

    /**
     * Moves every bit of air along at its own speed, and releases new air from the outlet at
     * the current fan speed, carrying the current mode. Air already in the room carries on as
     * it left until it fades, so a change starts at the outlet and flows outward.
     */
    fun air(state: ACState, time: Double): List<AirParticle> {
        if (release.isEmpty()) {
            air += Airflow.steadyAir(state, time)
            release = DoubleArray(Airflow.STREAMS) { Airflow.noise(it * 13 + 5) }
            gap = DoubleArray(Airflow.STREAMS) { 0.4 + 1.2 * Airflow.noise(it * 29 + 3) }
        }
        val elapsed = airTime?.let { min(0.1, max(0.0, time - it)) } ?: 0.0
        airTime = time
        val speed = Airflow.speed(state.fan, time)

        for (particle in air) particle.progress += particle.speed * elapsed
        air.removeAll { it.progress >= 1 }

        // At a steady speed each stream holds PARTICLES_PER_STREAM bits of air.
        val perStream = Airflow.PARTICLES_PER_STREAM.toDouble()
        for (stream in release.indices) {
            release[stream] += speed * elapsed * perStream
            while (release[stream] >= gap[stream]) {
                release[stream] -= gap[stream]
                released++
                val seed = Airflow.noise(released * 17 + stream)
                gap[stream] = 0.4 + 1.2 * Airflow.noise(released * 23 + stream * 7)
                // Already a little way out if it was due part-way through this frame; each bit
                // travels a touch faster or slower than the next.
                air += AirParticle(stream, seed, release[stream] / perStream, speed * (0.9 + 0.2 * seed), state.fan, state.mode)
            }
        }
        return air
    }

    private companion object {
        /** Degrees per second when moving to a new position; swinging tops out near 10. */
        const val LOUVER_SPEED = 40.0
    }
}

object Airflow {
    const val STREAMS = 13
    const val PARTICLES_PER_STREAM = 7

    /** Cool air sinks and warm air rises a little as it travels. */
    fun buoyancy(mode: ACMode): Double = when (mode) {
        ACMode.COOL, ACMode.DRY -> 0.22
        ACMode.HEAT -> -0.18
        else -> 0.05
    }

    /** Air travelled per second at each fixed speed: Quiet a slow drift, High more than four times as fast. */
    private fun pace(fan: FanSpeed): Double = when (fan) {
        FanSpeed.QUIET -> 0.18
        FanSpeed.LOW -> 0.32
        FanSpeed.MEDIUM -> 0.5
        else -> 0.8
    }

    /**
     * How far along the air has travelled. Auto moves at a gentle, medium pace that slowly
     * speeds up and eases off (MirAIe doesn't report the speed the AC picks in Auto).
     */
    private fun phase(fan: FanSpeed, time: Double): Double {
        val t = time % 3600
        return if (fan == FanSpeed.AUTO) t * 0.36 + 0.08 / 0.5 * sin(t * 0.5) else t * pace(fan)
    }

    /** How fast air leaves the outlet right now. */
    fun speed(fan: FanSpeed, time: Double): Double =
        if (fan == FanSpeed.AUTO) 0.36 + 0.08 * cos((time % 3600) * 0.5) else pace(fan)

    /** In Auto the air also brightens and fades a little, so it reads differently from a fixed speed. */
    fun breath(fan: FanSpeed, time: Double): Double =
        if (fan == FanSpeed.AUTO) 0.75 + 0.25 * sin((time % 3600) * 0.9) else 1.0

    /** The air as it is when the fan has been steady: evenly spread along each stream. */
    fun steadyAir(state: ACState, time: Double): List<AirParticle> {
        val phase = phase(state.fan, time)
        val speed = speed(state.fan, time)
        return (0 until STREAMS).flatMap { stream ->
            (0 until PARTICLES_PER_STREAM).map { index ->
                val seed = noise(stream * 31 + index * 7)
                val progress = (phase + index.toDouble() / PARTICLES_PER_STREAM + seed) % 1.0
                AirParticle(stream, seed, progress, speed, state.fan, state.mode)
            }
        }
    }

    /** Stable pseudo-random value in 0..<1, so particles don't march in lockstep. */
    fun noise(seed: Int): Double {
        val value = sin(seed * 12.9898) * 43758.5453
        return value - floor(value)
    }
}

/** Seconds on a clock that runs only while [running], updated every frame. */
@Composable
fun rememberFrameClock(running: Boolean): State<Double> {
    val time = remember { mutableDoubleStateOf(System.nanoTime() / 1e9) }
    LaunchedEffect(running) {
        while (running) {
            androidx.compose.runtime.withFrameNanos { time.doubleValue = it / 1e9 }
        }
    }
    return time
}

/** The unit's width as a share of the scene's; the air fans out across the rest. */
private const val UNIT_WIDTH = 0.64f

/**
 * The indoor unit seen from the front, with air streaming out that follows both louvers:
 * the vertical louver sets how far down the air goes, the horizontal one steers it left or
 * right, and swing animates either. The air's colour follows the mode and its speed the fan.
 */
@Composable
fun ACUnitScene(
    state: ACState,
    modifier: Modifier = Modifier,
    statusLight: Color? = null,
    onStatusLightTap: (() -> Unit)? = null,
) {
    val airAlpha by animateFloatAsState(if (state.isOn) 1f else 0f, tween(600), label = "air")
    val clock = rememberFrameClock(state.isOn || airAlpha > 0f)
    val motion = remember { AirMotion() }

    BoxWithConstraints(modifier) {
        val unitWidth = maxWidth * UNIT_WIDTH
        val unitHeight = min((maxHeight * 0.34f).value, (unitWidth / 3.9f).value).dp
        val unitLeft = (maxWidth - unitWidth) / 2

        // The air, from under the unit to the bottom of the scene, drawn first so the flap
        // hangs over its start.
        Canvas(Modifier.fillMaxSize().graphicsLayer { alpha = airAlpha }) {
            val time = clock.value
            val angles = motion.angles(state, time)
            val air = motion.air(state, time)
            translate(0f, unitHeight.toPx()) {
                drawAir(air, angles, time, Size(size.width, size.height - unitHeight.toPx()))
            }
        }
        Canvas(Modifier.offset(x = unitLeft).size(unitWidth, unitHeight)) {
            // The air already advanced the angles to this frame; this reads the same ones.
            drawUnitShell(state.isOn, motion.angles(state, clock.value))
        }

        // The set temperature glowing through the casing, lit while the AC runs with its display on.
        val lit = state.isOn && state.display
        val displayAlpha by animateFloatAsState(if (lit) 1f else 0f, tween(300), label = "display")
        Box(
            Modifier
                .offset(x = unitLeft, y = unitHeight * 0.1f)
                .size(unitWidth * 0.95f, unitHeight * 0.38f)
                .alpha(displayAlpha),
            contentAlignment = Alignment.CenterEnd,
        ) {
            UnitReadout(state, unitHeight * 0.3f)
        }

        val light = statusLight ?: if (state.isOn && state.display) MitraColors.online else null
        val lightAlpha by animateFloatAsState(if (light == null) 0f else 1f, tween(300), label = "light")
        val diameter = unitHeight * 0.09f
        // A target bigger than the light itself, so it's easy to tap.
        Box(
            Modifier
                .offset(x = unitLeft + unitWidth * 0.06f - 14.dp + diameter / 2, y = unitHeight * 0.245f - 14.dp + diameter / 2)
                .size(28.dp)
                .clip(CircleShape)
                .then(
                    if (onStatusLightTap != null) Modifier.clickable(
                        interactionSource = remember { MutableInteractionSource() }, indication = null, onClick = onStatusLightTap,
                    ) else Modifier
                ),
            contentAlignment = Alignment.Center,
        ) {
            StatusLight(light ?: Color.Transparent, diameter, Modifier.alpha(lightAlpha))
        }
    }
}

@Composable
private fun UnitReadout(state: ACState, height: Dp) {
    val text = if (state.mode.usesSetpoint) ACState.formatTemperature(state.setpoint).dropLast(1) else "FAN"
    AnimatedContent(
        targetState = text,
        transitionSpec = {
            val up = (targetState.toDoubleOrNull() ?: 0.0) > (initialState.toDoubleOrNull() ?: 0.0)
            (slideInVertically(tween(300)) { if (up) it else -it } + fadeIn(tween(300)))
                .togetherWith(slideOutVertically(tween(300)) { if (up) -it else it } + fadeOut(tween(200)))
        },
        label = "readout",
    ) { value ->
        Text(
            value,
            style = TextStyle(
                fontFamily = RoundedFamily, fontWeight = FontWeight.SemiBold,
                fontSize = (height.value * 1.05f).sp, color = MitraColors.acDisplay, textAlign = TextAlign.End,
                shadow = androidx.compose.ui.graphics.Shadow(MitraColors.acDisplay.copy(alpha = 0.35f), blurRadius = height.value * 0.4f),
            ),
            maxLines = 1,
        )
    }
}

/** A small steady light on the casing, with a soft glow so it stands out on white. */
@Composable
private fun StatusLight(color: Color, diameter: Dp, modifier: Modifier = Modifier) {
    Box(
        modifier
            .size(diameter)
            .drawBehind {
                drawCircle(Brush.radialGradient(listOf(color.copy(alpha = 0.55f), Color.Transparent), radius = size.minDimension * 1.3f),
                    radius = size.minDimension * 1.3f)
            }
            .background(
                Brush.radialGradient(
                    listOf(color.mix(Color.White, 0.45f), color),
                    center = Offset.Unspecified, radius = Float.POSITIVE_INFINITY,
                ),
                CircleShape,
            ),
    )
}

/**
 * The casing and its flap, like a real split unit: the flap is the lower front strip of the
 * casing, flush and closed while the AC is off. Running, it swings away from the casing to
 * open the outlet behind it: level, it shows its whole face and hangs a little below the
 * unit; pointing down, it's seen almost edge-on, a thin blade with a wide gap above it.
 */
private fun DrawScope.drawUnitShell(isOn: Boolean, angles: LouverAngles) {
    val w = size.width
    val h = size.height
    val radius = h * 0.28f
    val seam = h * 0.76f          // where the front panel meets the flap
    val cap = w * 0.06f           // the casing's end caps, either side of the flap
    val strip = h - seam          // the flap's height when closed

    // 1 when the flap is level (seen from below, its whole face shows), 0 when it points
    // straight down (seen almost edge-on, with the outlet wide open above it).
    val level = (1 - ((angles.vertical - 12) / 60).coerceIn(0.0, 1.0)).toFloat()
    val gap = if (isOn) h * (0.15f - 0.07f * level) else 0f
    val face = if (isOn) strip * (0.4f + 0.75f * level) else strip

    val casing = Path().apply { addRoundRect(RoundRect(0f, 0f, w, h, CornerRadius(radius))) }

    // A soft shadow under the unit.
    drawRoundRect(
        Brush.verticalGradient(listOf(Color.Black.copy(alpha = 0.35f), Color.Transparent), startY = h * 0.6f, endY = h * 1.35f),
        topLeft = Offset(w * 0.02f, h * 0.2f), size = Size(w * 0.96f, h * 1.15f), cornerRadius = CornerRadius(radius),
    )
    drawPath(casing, Brush.verticalGradient(listOf(Color(0xFFFCFCFC), Color(0xFFDEDEDE)), 0f, h))

    // The outlet: dark where the flap has moved away, with the left/right vanes in it.
    val outlet = Rect(cap, seam, w - cap, h)
    clipPath(casing) {
        drawRect(Color(0xFF242424), outlet.topLeft, outlet.size)
        if (isOn) {
            val lean = (tan(angles.horizontal * PI / 180) * gap * 1.2).toFloat()
            for (index in 1 until 12) {
                val x = outlet.left + outlet.width * index / 12
                drawLine(
                    Color(0xFF8C8C8C), Offset(x - lean / 2, seam + 1), Offset(x + lean / 2, seam + gap - 1),
                    strokeWidth = 1.dp.toPx(), cap = StrokeCap.Round,
                )
            }
        }
    }

    // The flap. Closed, it's clipped to the casing's rounded bottom so it reads as part of it;
    // open, it's its own rounded blade.
    val top = seam + gap
    val blade = Rect(cap + 0.5f, top, w - cap - 0.5f, top + face)
    val bladeBrush = Brush.verticalGradient(listOf(Color(0xFFF7F7F7), Color(0xFFCCCCCC)), top, top + face)
    if (isOn) {
        val corner = min(face / 2, h * 0.08f)
        drawRoundRect(bladeBrush, blade.topLeft, blade.size, CornerRadius(corner))
        // The leading edge catches the light.
        drawLine(Color.White, Offset(blade.left + 3, top + 0.6f), Offset(blade.right - 3, top + 0.6f), strokeWidth = 1.dp.toPx())
    } else {
        clipPath(casing) { drawRect(bladeBrush, blade.topLeft, blade.size) }
        // A fine seam between the panel and the closed flap.
        drawLine(Color(0xFFB8B8B8), Offset(cap, seam), Offset(w - cap, seam), strokeWidth = 0.75.dp.toPx())
    }

    // Gloss across the top of the front panel, and a crisp outline.
    drawRoundRect(
        Brush.verticalGradient(listOf(Color.White.copy(alpha = 0.9f), Color.White.copy(alpha = 0f)), 0f, h * 0.45f),
        topLeft = Offset(2f, 2f), size = Size(w - 4, h * 0.45f), cornerRadius = CornerRadius(radius - 2),
    )
    drawPath(casing, Color(0xFFB8B8B8).copy(alpha = 0.6f), style = Stroke(0.75.dp.toPx()))
}

/**
 * Streams of air particles. Each particle travels out of the outlet in 3D (down, towards the
 * viewer, sideways) and is projected for a viewer slightly above the unit.
 */
private fun DrawScope.drawAir(air: List<AirParticle>, angles: LouverAngles, time: Double, area: Size) {
    val tilt = angles.vertical * PI / 180
    val steer = angles.horizontal * PI / 180
    val reach = area.height * 1.05
    val unit = density.toDouble()
    // Across the outlet: 84% of the unit's width, centred.
    val outlet = UNIT_WIDTH * 0.84
    for (particle in air) {
        val u = particle.stream.toDouble() / (Airflow.STREAMS - 1)
        val originX = area.width * (0.5 + (u - 0.5) * outlet)
        val fan = (u - 0.5) * 0.55 // streams spread out a little from the centre
        val buoyancy = Airflow.buoyancy(particle.mode)
        val progress = particle.progress
        val head = point(progress, originX, tilt, steer + fan, reach, buoyancy, area, unit)
        val tail = point(max(0.0, progress - 0.12), originX, tilt, steer + fan, reach, buoyancy, area, unit)
        val fade = (sin(PI * progress) * (0.55 + 0.35 * particle.seed) * Airflow.breath(particle.fan, time)).toFloat()
        drawLine(
            Brush.linearGradient(
                listOf(particle.mode.tint.copy(alpha = 0f), particle.mode.glow.copy(alpha = fade.coerceIn(0f, 1f))),
                start = tail.first, end = head.first,
            ),
            tail.first, head.first,
            strokeWidth = ((1.2 + 2.4 * head.second) * unit).toFloat(),
            cap = StrokeCap.Round,
            blendMode = BlendMode.Plus,
        )
    }
}

private fun point(
    progress: Double, originX: Double, tilt: Double, steer: Double,
    reach: Double, buoyancy: Double, area: Size, unit: Double,
): Pair<Offset, Double> {
    val distance = progress * reach
    val forward = cos(tilt) * distance
    val down = sin(tilt) * distance + buoyancy * distance * progress
    val sideways = sin(steer) * distance * 0.9
    val depth = forward / reach // 0 at the unit, ~1 right in front of the viewer
    // Closer air spreads out from the centre, as perspective would have it.
    val x = originX + sideways + (originX - area.width / 2) * depth * 0.35
    val y = 2 * unit + down * 0.85 + forward * 0.32
    return Offset(x.toFloat(), y.toFloat()) to depth
}

/**
 * The night sky behind the AC: a graphite glow, lighter where the air comes out and fading to
 * near black at the bottom. The same in every mode (the air carries the mode's colour), dimmer
 * while the AC is off, and slowly drifting while it runs.
 */
@Composable
fun GraphiteBackdrop(isOn: Boolean, modifier: Modifier = Modifier) {
    val clock = rememberFrameClock(isOn)
    val dim by animateFloatAsState(if (isOn) 0f else 0.08f, tween(800), label = "dim")
    Canvas(modifier.fillMaxWidth()) {
        val t = clock.value
        val tint = ACMode.FAN.tint
        val glow = ACMode.FAN.glow
        val night = MitraColors.night
        drawRect(night)
        // The top edge, lighter in the middle.
        drawRect(
            Brush.verticalGradient(
                listOf(tint.mix(night, 0.74f + dim), tint.mix(night, 0.8f + dim), night),
                startY = 0f, endY = size.height,
            ),
        )
        drawRect(
            Brush.radialGradient(
                listOf(glow.mix(night, 0.62f + dim).copy(alpha = 0.9f), Color.Transparent),
                center = Offset(size.width * 0.5f, 0f), radius = size.width * 0.6f,
            ),
        )
        // The drifting bright patch where the air comes out.
        val cx = size.width * (0.5f + 0.12f * sin(t * 0.21).toFloat())
        val cy = size.height * (0.42f + 0.1f * cos(t * 0.17).toFloat())
        drawRect(
            Brush.radialGradient(
                listOf(tint.mix(night, 0.55f + dim).copy(alpha = 0.85f), Color.Transparent),
                center = Offset(cx, cy), radius = size.width * 0.62f,
            ),
        )
        drawRect(
            Brush.radialGradient(
                listOf(glow.mix(night, 0.82f + dim).copy(alpha = 0.6f), Color.Transparent),
                center = Offset(size.width, size.height * 0.5f), radius = size.width * 0.45f,
            ),
        )
    }
}
