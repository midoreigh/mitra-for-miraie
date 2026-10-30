package com.midoreigh.mitra

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.midoreigh.mitra.miraie.MirAIeService
import com.midoreigh.mitra.model.ACCommand
import com.midoreigh.mitra.store.ACStore
import com.midoreigh.mitra.store.Phase
import com.midoreigh.mitra.ui.ControlScreen
import com.midoreigh.mitra.ui.MitraColors
import com.midoreigh.mitra.ui.MitraTheme
import com.midoreigh.mitra.ui.SettingsScreen
import com.midoreigh.mitra.ui.SignInScreen

class MainActivity : ComponentActivity() {
    private val store by lazy { ACStore.get(this) }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
        )
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) handleShortcut(intent)
        setContent {
            MitraTheme {
                val ui by store.ui.collectAsStateWithLifecycle()
                var settings by rememberSaveable { mutableStateOf(false) }
                val signedIn = ui.phase == Phase.READY
                BackHandler(settings && signedIn) { settings = false }
                val screen = when {
                    ui.phase == Phase.LOADING -> "loading"
                    !signedIn -> "signIn"
                    settings && !ui.isDemo -> "settings"
                    else -> "control"
                }
                AnimatedContent(screen, transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "screen") { current ->
                    when (current) {
                        "loading" -> Box(Modifier.fillMaxSize().background(MitraColors.night), Alignment.Center) {
                            CircularProgressIndicator(color = Color.White)
                        }
                        "signIn" -> SignInScreen(ui, store)
                        "settings" -> SettingsScreen(ui, store, MirAIeService.get(this@MainActivity).secrets.credentials?.username) {
                            settings = false
                        }
                        else -> ControlScreen(ui, store) { settings = true }
                    }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleShortcut(intent)
    }

    /** App shortcuts (long-press the icon, or ask Assistant) open the app with a command. */
    private fun handleShortcut(intent: Intent?) {
        val ui = store.ui.value
        if (ui.phase != Phase.READY || ui.isDemo) return
        val state = ui.state
        val command = when (intent?.action) {
            ACTION_POWER_ON -> ACCommand.Power(true)
            ACTION_POWER_OFF -> ACCommand.Power(false)
            ACTION_COOLER -> ACCommand.Temperature((state.setpoint - 1).coerceAtLeast(16.0))
            ACTION_WARMER -> ACCommand.Temperature((state.setpoint + 1).coerceAtMost(30.0))
            else -> return
        }
        store.send(command)
    }

    companion object {
        const val ACTION_POWER_ON = "com.midoreigh.mitra.POWER_ON"
        const val ACTION_POWER_OFF = "com.midoreigh.mitra.POWER_OFF"
        const val ACTION_COOLER = "com.midoreigh.mitra.COOLER"
        const val ACTION_WARMER = "com.midoreigh.mitra.WARMER"
    }
}
