package com.resqmesh.resqmesh

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.nearby.Nearby
import com.google.android.gms.nearby.connection.AdvertisingOptions
import com.google.android.gms.nearby.connection.ConnectionInfo
import com.google.android.gms.nearby.connection.ConnectionLifecycleCallback
import com.google.android.gms.nearby.connection.ConnectionResolution
import com.google.android.gms.nearby.connection.ConnectionsClient
import com.google.android.gms.nearby.connection.DiscoveredEndpointInfo
import com.google.android.gms.nearby.connection.DiscoveryOptions
import com.google.android.gms.nearby.connection.EndpointDiscoveryCallback
import com.google.android.gms.nearby.connection.Payload
import com.google.android.gms.nearby.connection.PayloadCallback
import com.google.android.gms.nearby.connection.PayloadTransferUpdate
import com.google.android.gms.nearby.connection.Strategy
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentHashMap

/**
 * Native transport for Google Nearby Connections.
 *
 * This class deliberately contains no relay, dedupe, trust, expiry or routing
 * logic. It advertises, discovers, accepts connections and transfers opaque
 * byte payloads. Dart owns all message semantics.
 */
class NearbyMeshPlugin : FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private val pendingEvents = mutableListOf<Map<String, Any?>>()
    private val mainHandler = Handler(Looper.getMainLooper())

    private var client: ConnectionsClient? = null
    private var started = false
    private var autoConnect = true
    private var localName = "ResQMesh device"

    private val connected = ConcurrentHashMap<String, String>()
    private val connectionNames = ConcurrentHashMap<String, String>()
    private val pendingConnections = ConcurrentHashMap.newKeySet<String>()

    companion object {
        private const val SERVICE_ID = "com.resqmesh.p2p.v1"
        private const val CHANNEL = "com.resqmesh/nearby"
        private const val EVENTS = "com.resqmesh/nearby/events"
        private val STRATEGY = Strategy.P2P_CLUSTER
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, CHANNEL)
        eventChannel = EventChannel(binding.binaryMessenger, EVENTS)
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
        client = Nearby.getConnectionsClient(context)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopEverything()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        client = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        flushPending()
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(statusMap())
            "initialize" -> result.success(true)
            "start" -> {
                val name = call.argument<String>("name")?.trim().orEmpty()
                if (name.isEmpty()) {
                    result.error("invalid_name", "Device name is required", null)
                    return
                }
                localName = name.take(48)
                autoConnect = call.argument<Boolean>("autoConnect") ?: true
                startMesh(result)
            }
            "stop" -> {
                stopEverything()
                result.success(true)
            }
            "connect" -> {
                val endpointId = call.argument<String>("endpointId")
                if (endpointId.isNullOrBlank()) {
                    result.error("invalid_endpoint", "endpointId is required", null)
                    return
                }
                requestConnection(endpointId)
                result.success(true)
            }
            "send" -> send(call, result)
            else -> result.notImplemented()
        }
    }

    private fun statusMap(): Map<String, Any?> {
        val code = GoogleApiAvailability.getInstance()
            .isGooglePlayServicesAvailable(context)
        val playServices = code == ConnectionResult.SUCCESS
        val reason = when {
            playServices -> "Google Play services ready"
            code == ConnectionResult.SERVICE_MISSING ->
                "Google Play services is not installed; Nearby Connections cannot run on this device."
            code == ConnectionResult.SERVICE_VERSION_UPDATE_REQUIRED ->
                "Google Play services must be updated for Nearby Connections."
            code == ConnectionResult.SERVICE_DISABLED ->
                "Google Play services is disabled."
            else -> "Google Play services unavailable (code $code)."
        }
        return mapOf(
            "available" to playServices,
            "googlePlayServices" to playServices,
            "reason" to reason
        )
    }

    private fun hasNearbyPermissions(): Boolean {
        fun granted(permission: String): Boolean =
            context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
        return if (Build.VERSION.SDK_INT >= 31) {
            granted(Manifest.permission.BLUETOOTH_SCAN) &&
                granted(Manifest.permission.BLUETOOTH_CONNECT) &&
                granted(Manifest.permission.BLUETOOTH_ADVERTISE) &&
                (Build.VERSION.SDK_INT < 33 ||
                    granted(Manifest.permission.NEARBY_WIFI_DEVICES))
        } else {
            granted(Manifest.permission.ACCESS_FINE_LOCATION)
        }
    }

    @Suppress("MissingPermission")
    private fun startMesh(result: MethodChannel.Result) {
        val nearby = client
        if (nearby == null) {
            result.error("not_attached", "Nearby client not attached", null)
            return
        }
        if (!hasNearbyPermissions()) {
            result.error(
                "permission_denied",
                "Nearby permissions are missing. Grant location and Bluetooth / Wi-Fi nearby permissions in app settings, then start the mesh again.",
                null
            )
            return
        }
        if (started) {
            result.success(true)
            return
        }
        try {
            nearby.stopAdvertising()
            nearby.stopDiscovery()
            nearby.stopAllEndpoints()
            connected.clear()
            connectionNames.clear()
            pendingConnections.clear()

            val advertisingOptions = AdvertisingOptions.Builder()
                .setStrategy(STRATEGY)
                .build()
            nearby.startAdvertising(
                localName,
                SERVICE_ID,
                connectionLifecycleCallback,
                advertisingOptions
            ).addOnFailureListener { error ->
                emitError("Advertising failed: ${error.message}")
            }

            val discoveryOptions = DiscoveryOptions.Builder()
                .setStrategy(STRATEGY)
                .build()
            nearby.startDiscovery(
                SERVICE_ID,
                endpointDiscoveryCallback,
                discoveryOptions
            ).addOnFailureListener { error ->
                emitError("Discovery failed: ${error.message}")
            }
            started = true
            emitStatus("Advertising and discovering nearby devices")
            result.success(true)
        } catch (error: SecurityException) {
            result.error(
                "permission_denied",
                "Nearby permissions are missing: ${error.message}",
                null
            )
        } catch (error: Exception) {
            result.error("start_failed", error.message, null)
        }
    }

    @Suppress("MissingPermission")
    private fun stopEverything() {
        val nearby = client ?: return
        try {
            nearby.stopAdvertising()
            nearby.stopDiscovery()
            nearby.stopAllEndpoints()
        } catch (_: SecurityException) {
            // Permissions can be revoked while the app is running.
        } catch (_: Exception) {
            // Best effort shutdown.
        }
        started = false
        connected.clear()
        connectionNames.clear()
        pendingConnections.clear()
        emitStatus("Nearby transport stopped")
    }

    @Suppress("MissingPermission")
    private fun requestConnection(endpointId: String) {
        val nearby = client ?: return
        if (connected.containsKey(endpointId) || !pendingConnections.add(endpointId)) return
        try {
            nearby.requestConnection(
                localName,
                endpointId,
                connectionLifecycleCallback
            ).addOnFailureListener { error ->
                pendingConnections.remove(endpointId)
                emitError("Connection request to $endpointId failed: ${error.message}")
            }
        } catch (error: SecurityException) {
            pendingConnections.remove(endpointId)
            emitError("Connection permission denied: ${error.message}")
        }
    }

    private val endpointDiscoveryCallback = object : EndpointDiscoveryCallback() {
        override fun onEndpointFound(endpointId: String, info: DiscoveredEndpointInfo) {
            connectionNames[endpointId] = info.endpointName
            emit(
                mapOf(
                    "type" to "peerFound",
                    "endpointId" to endpointId,
                    "name" to info.endpointName
                )
            )
            if (autoConnect) requestConnection(endpointId)
        }

        override fun onEndpointLost(endpointId: String) {
            emit(mapOf("type" to "peerLost", "endpointId" to endpointId))
        }
    }

    private val connectionLifecycleCallback = object : ConnectionLifecycleCallback() {
        @Suppress("MissingPermission")
        override fun onConnectionInitiated(endpointId: String, info: ConnectionInfo) {
            connectionNames[endpointId] = info.endpointName
            // Accepting an incoming link lets a user-initiated connection work
            // even when automatic outbound requests are disabled. Auto-connect
            // controls whether this app initiates requests on discovery.
            client?.acceptConnection(endpointId, payloadCallback)
                ?.addOnFailureListener { error ->
                    emitError("Could not accept ${info.endpointName}: ${error.message}")
                }
        }

        override fun onConnectionResult(endpointId: String, resolution: ConnectionResolution) {
            pendingConnections.remove(endpointId)
            if (resolution.status.isSuccess) {
                val name = connectionNames[endpointId] ?: "Nearby device"
                connected[endpointId] = name
                emit(
                    mapOf(
                        "type" to "connected",
                        "endpointId" to endpointId,
                        "name" to name
                    )
                )
                emitStatus("Connected to $name")
            } else {
                emitError("Connection to $endpointId failed with status ${resolution.status.statusCode}")
            }
        }

        override fun onDisconnected(endpointId: String) {
            val name = connected.remove(endpointId) ?: connectionNames[endpointId] ?: "Peer"
            pendingConnections.remove(endpointId)
            emit(
                mapOf(
                    "type" to "disconnected",
                    "endpointId" to endpointId,
                    "name" to name
                )
            )
            emitStatus("Disconnected from $name")
        }
    }

    private val payloadCallback = object : PayloadCallback() {
        override fun onPayloadReceived(endpointId: String, payload: Payload) {
            if (payload.type != Payload.Type.BYTES) {
                return
            }
            val bytes = payload.asBytes() ?: return
            emit(
                mapOf(
                    "type" to "payload",
                    "endpointId" to endpointId,
                    "name" to (connectionNames[endpointId] ?: "Nearby device"),
                    "data" to bytes
                )
            )
        }

        override fun onPayloadTransferUpdate(
            endpointId: String,
            update: PayloadTransferUpdate
        ) {
            if (update.status == PayloadTransferUpdate.Status.FAILURE) {
                emitError("Payload transfer to $endpointId failed")
            }
        }
    }

    @Suppress("MissingPermission")
    private fun send(call: MethodCall, result: MethodChannel.Result) {
        val endpointId = call.argument<String>("endpointId")
        val data = call.argument<ByteArray>("data")
        if (endpointId.isNullOrBlank() || data == null) {
            result.error("invalid_send", "endpointId and data are required", null)
            return
        }
        if (!connected.containsKey(endpointId)) {
            result.success(false)
            emitError("Cannot send: $endpointId is not connected")
            return
        }
        if (data.size > 512 * 1024) {
            result.error("payload_too_large", "Frame exceeds 512 KiB safety limit", null)
            return
        }
        try {
            val payload = Payload.fromBytes(data)
            client?.sendPayload(endpointId, payload)
                ?.addOnSuccessListener {
                    result.success(true)
                }
                ?.addOnFailureListener { error ->
                    emitError("Send to $endpointId failed: ${error.message}")
                    result.success(false)
                }
        } catch (error: SecurityException) {
            result.error("permission_denied", error.message, null)
        } catch (error: Exception) {
            result.error("send_failed", error.message, null)
        }
    }

    private fun emit(event: Map<String, Any?>) {
        mainHandler.post {
            val sink = eventSink
            if (sink == null) {
                if (pendingEvents.size > 128) pendingEvents.removeAt(0)
                pendingEvents.add(event)
            } else {
                sink.success(event)
            }
        }
    }

    private fun flushPending() {
        val sink = eventSink ?: return
        val snapshot = pendingEvents.toList()
        pendingEvents.clear()
        for (event in snapshot) sink.success(event)
    }

    private fun emitStatus(message: String) {
        emit(mapOf("type" to "status", "message" to message))
    }

    private fun emitError(message: String) {
        emit(mapOf("type" to "error", "message" to message))
    }
}
