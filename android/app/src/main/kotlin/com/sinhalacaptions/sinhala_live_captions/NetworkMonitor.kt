package com.sinhalacaptions.sinhala_live_captions

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities

/// Reports whether the phone has a default network that can reach the internet.
class NetworkMonitor(
    context: Context,
    private val emit: (Boolean) -> Unit,
) {
    private val connectivity =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private var callback: ConnectivityManager.NetworkCallback? = null

    fun current(): Boolean = hasInternet(connectivity.activeNetwork)

    fun start() {
        if (callback != null) {
            return
        }
        val created = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                emit(hasInternet(network))
            }

            override fun onCapabilitiesChanged(
                network: Network,
                networkCapabilities: NetworkCapabilities,
            ) {
                emit(networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET))
            }

            override fun onLost(network: Network) {
                emit(current())
            }
        }
        callback = created
        connectivity.registerDefaultNetworkCallback(created)
        emit(current())
    }

    fun stop() {
        val active = callback ?: return
        callback = null
        connectivity.unregisterNetworkCallback(active)
    }

    private fun hasInternet(network: Network?): Boolean {
        if (network == null) {
            return false
        }
        val capabilities = connectivity.getNetworkCapabilities(network) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }
}
