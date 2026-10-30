package com.midoreigh.mitra.widget

import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.widget.Toast
import com.midoreigh.mitra.miraie.MirAIeService
import com.midoreigh.mitra.model.ACCommand
import com.midoreigh.mitra.model.ACState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/** A Quick Settings tile that turns the chosen AC on or off. */
class PowerTileService : TileService() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val service by lazy { MirAIeService.get(this) }

    override fun onStartListening() {
        val device = service.shared.selectedDevice
        show(device?.name, device?.let { service.shared.state(it.id) }, signedIn = service.isSignedIn && device != null)
    }

    override fun onClick() {
        val device = service.shared.selectedDevice ?: return
        val state = service.shared.state(device.id) ?: ACState()
        val command = ACCommand.Power(!state.isOn)
        // Show the change at once; the AC's reply settles it.
        show(device.name, state.applying(command), signedIn = true)
        scope.launch {
            try {
                show(device.name, service.send(listOf(command), device), signedIn = true)
                Surfaces.refresh(this@PowerTileService)
            } catch (e: Exception) {
                show(device.name, state, signedIn = true)
                Toast.makeText(this@PowerTileService, e.message ?: "Couldn't reach the AC.", Toast.LENGTH_SHORT).show()
            }
        }
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }

    private fun show(name: String?, state: ACState?, signedIn: Boolean) {
        val tile = qsTile ?: return
        tile.label = name ?: "AC"
        tile.subtitle = when {
            !signedIn -> "Sign in first"
            state == null -> "Off"
            else -> state.summary
        }
        tile.state = when {
            !signedIn || state?.isOnline == false -> Tile.STATE_UNAVAILABLE
            state?.isOn == true -> Tile.STATE_ACTIVE
            else -> Tile.STATE_INACTIVE
        }
        tile.updateTile()
    }
}
