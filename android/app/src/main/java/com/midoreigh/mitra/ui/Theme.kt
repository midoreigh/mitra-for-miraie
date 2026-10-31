package com.midoreigh.mitra.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import com.midoreigh.mitra.R
import com.midoreigh.mitra.model.ACMode

object MitraColors {
    val night = Color(0xFF080A14)
    val surface = Color(0xFF12151F)
    val glass = Color(0x1FFFFFFF)
    val glassBorder = Color(0x14FFFFFF)
    /** The controls' panel: dark frosted glass that lets the air show through. */
    val panel = Color(0xB80E111C)
    val secondaryText = Color(0x99FFFFFF)

    /** The AC's display: the digits on the unit. */
    val acDisplay = Color(0xFF1A73F2)

    val eco = Color(0xFF1C8045)
    val powerful = Color(0xFFCC570F)
    val converti = Color(0xFF007380)
    val nanoe = Color(0xFF6B52D1)
    /** A lit bulb: warm incandescent amber, light enough that its icon is dark. */
    val bulb = Color(0xFFFFBD5C)
    val bulbIcon = Color(0xFF4D2B00)

    val offline = Color(0xFFB86A00)
    val preview = Color(0xFFFFD60A)
    val online = Color(0xFF34C759)
    val connecting = Color(0xFFFFCC00)
    val offlineLight = Color(0xFFFF3B30)
}

/** The colour of the air in this mode. */
val ACMode.tint: Color
    get() = when (this) {
        ACMode.COOL -> Color(0xFF54ADFF)
        ACMode.AUTO -> Color(0xFF9E8CFF)
        ACMode.DRY -> Color(0xFF38D4C2)
        ACMode.FAN -> Color(0xFFC7D6ED)
        ACMode.HEAT -> Color(0xFFFF8C3D)
    }

/** A lighter companion to [tint], for the air's bright head. */
val ACMode.glow: Color
    get() = when (this) {
        ACMode.COOL -> Color(0xFF7DE3FF)
        ACMode.AUTO -> Color(0xFFDB9EFF)
        ACMode.DRY -> Color(0xFF8CF2CC)
        ACMode.FAN -> Color(0xFFF2F7FF)
        ACMode.HEAT -> Color(0xFFFFC76B)
    }

/**
 * A deeper shade for controls showing this mode, so white icons read clearly on it.
 * ([tint] is the air's colour, too light for that in Dry and Fan.)
 */
val ACMode.controlTint: Color
    get() = when (this) {
        ACMode.COOL -> Color(0xFF1F6BE6)
        ACMode.AUTO -> Color(0xFF6B52D9)
        ACMode.DRY -> Color(0xFF007A70)
        ACMode.FAN -> Color(0xFF546685)
        ACMode.HEAT -> Color(0xFFD15C14)
    }

/** [this] mixed with [other]: 0 is all this, 1 all other. */
fun Color.mix(other: Color, by: Float): Color = lerp(this, other, by.coerceIn(0f, 1f))

/** A rounded face for the big temperature, close to the Mac app's SF Rounded. */
val RoundedFamily = FontFamily(
    Font(R.font.nunito, FontWeight.ExtraLight, variationSettings = FontVariation.Settings(FontVariation.weight(200))),
    Font(R.font.nunito, FontWeight.Normal, variationSettings = FontVariation.Settings(FontVariation.weight(400))),
    Font(R.font.nunito, FontWeight.SemiBold, variationSettings = FontVariation.Settings(FontVariation.weight(600))),
    Font(R.font.nunito, FontWeight.Bold, variationSettings = FontVariation.Settings(FontVariation.weight(700))),
)

@Composable
fun MitraTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = ACMode.COOL.controlTint,
            onPrimary = Color.White,
            background = MitraColors.night,
            onBackground = Color.White,
            surface = MitraColors.surface,
            onSurface = Color.White,
            surfaceContainer = MitraColors.surface,
            onSurfaceVariant = MitraColors.secondaryText,
            error = Color(0xFFFF6B60),
        ),
        content = content,
    )
}
