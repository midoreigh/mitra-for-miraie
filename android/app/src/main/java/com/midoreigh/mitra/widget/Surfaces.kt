package com.midoreigh.mitra.widget

import android.content.ComponentName
import android.content.Context
import android.service.quicksettings.TileService
import androidx.glance.appwidget.updateAll

/** The widget and Quick Settings tile: what shows the AC outside the app. */
object Surfaces {
    suspend fun refresh(context: Context) {
        runCatching { ACWidget().updateAll(context) }
        TileService.requestListeningState(context, ComponentName(context, PowerTileService::class.java))
    }
}
