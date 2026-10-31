package com.midoreigh.mitra.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.midoreigh.mitra.model.ACCapabilities
import com.midoreigh.mitra.model.ACMode
import com.midoreigh.mitra.model.SleepProfile
import com.midoreigh.mitra.store.ACStore
import com.midoreigh.mitra.store.UiState

@Composable
fun SettingsScreen(ui: UiState, store: ACStore, username: String?, close: () -> Unit) {
    var editing by remember { mutableStateOf<SleepProfile?>(null) }
    editing?.let { profile ->
        SleepProfileEditor(
            profile, isNew = ui.sleepProfiles.none { it.id == profile.id },
            save = store::save, delete = { store.deleteSleepProfile(profile.id) }, close = { editing = null },
        )
    }
    Column(
        Modifier
            .fillMaxSize()
            .background(MitraColors.night)
            .padding(top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding())
            .verticalScroll(rememberScrollState())
            .padding(bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + 24.dp),
    ) {
        Row(Modifier.padding(horizontal = 4.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = close) { Icon(Icons.AutoMirrored.Rounded.ArrowBack, "Back", tint = Color.White) }
            Text("Settings", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.SemiBold)
        }

        Section("Account") {
            Row(Modifier.padding(16.dp)) {
                Text("MirAIe account", color = Color.White, modifier = Modifier.weight(1f))
                Text(username ?: "Not signed in", color = MitraColors.secondaryText)
            }
            HorizontalDivider(color = MitraColors.glassBorder)
            Text(
                "Sign Out",
                color = Color(0xFFFF6B60),
                modifier = Modifier.fillMaxWidth().clickable { store.signOut(); close() }.padding(16.dp),
            )
        }

        if (ui.devices.size > 1) {
            Section("AC for the widget and Quick Settings", footer = "Also the AC the app opens on.") {
                ui.devices.forEach { device ->
                    Row(
                        Modifier.fillMaxWidth().clickable { store.select(device.id) }.padding(horizontal = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        RadioButton(device.id == ui.selected?.id, onClick = { store.select(device.id) })
                        Text(device.name, color = Color.White)
                        device.room?.let { Text("  $it", color = MitraColors.secondaryText, fontSize = 13.sp) }
                    }
                }
            }
        }

        Section(
            "Sleep profiles",
            footer = "Set a temperature for each hour of the night, then start the profile with the Sleep button. " +
                "Your AC runs it by itself. Gentle is built into the AC and works from whatever temperature it's set to.",
        ) {
            SleepProfileList(ui.sleepProfiles) { editing = it }
        }

        ui.devices.forEach { device ->
            val capabilities = ui.capabilities[device.id] ?: ACCapabilities()
            Section(
                "${device.name} features",
                footer = "MirAIe doesn't say which features an AC has. Mitra for MirAIe turns Heating and nanoe X on " +
                    "when the AC reports using them; switch features on or off to match your model.",
            ) {
                Toggle("Heating", capabilities.heat) { store.setCapabilities(capabilities.copy(heat = it), device.id) }
                HorizontalDivider(color = MitraColors.glassBorder)
                Toggle("nanoe X air purifier", capabilities.nanoe) { store.setCapabilities(capabilities.copy(nanoe = it), device.id) }
                HorizontalDivider(color = MitraColors.glassBorder)
                Toggle("Converti7 cooling levels", capabilities.converti) {
                    store.setCapabilities(capabilities.copy(converti = it), device.id)
                }
            }
        }

        Section(
            "Widget and Quick Settings",
            footer = "Long-press your home screen, tap Widgets and find Mitra for MirAIe. For the power tile, " +
                "edit your Quick Settings panel and drag in the AC tile. Long-press the app icon for shortcuts.",
        ) {}

        Section("About") {
            Text(
                "Mitra for MirAIe is an unofficial, open-source controller for MirAIe air conditioners. " +
                    "It talks only to MirAIe's servers, with no analytics.",
                color = MitraColors.secondaryText, fontSize = 14.sp, modifier = Modifier.padding(16.dp),
            )
        }
    }
}

@Composable
private fun Section(title: String, footer: String? = null, content: @Composable () -> Unit) {
    Column(Modifier.padding(horizontal = 16.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(title, color = MitraColors.secondaryText, fontSize = 13.sp, fontWeight = FontWeight.Medium,
            modifier = Modifier.padding(start = 4.dp))
        Column(Modifier.fillMaxWidth().background(MitraColors.surface, RoundedCornerShape(16.dp))) { content() }
        footer?.let { Text(it, color = MitraColors.secondaryText, fontSize = 12.sp, modifier = Modifier.padding(horizontal = 4.dp)) }
    }
}

@Composable
private fun Toggle(title: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable { onChange(!checked) }.padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, color = Color.White, modifier = Modifier.weight(1f))
        Switch(
            checked, onChange,
            colors = SwitchDefaults.colors(checkedTrackColor = ACMode.COOL.controlTint, checkedThumbColor = Color.White),
        )
    }
}
