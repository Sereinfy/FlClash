package com.follow.clash.plugins

import com.follow.clash.Service
import com.follow.clash.State
import com.follow.clash.awaitResult
import com.follow.clash.common.Components
import com.follow.clash.common.GlobalState
import com.follow.clash.service.models.VpnOptions
import com.google.gson.Gson
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit

class ServicePlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    CoroutineScope by CoroutineScope(SupervisorJob() + Dispatchers.Default) {
    private lateinit var flutterMethodChannel: MethodChannel

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        Service.bind()
        flutterMethodChannel = MethodChannel(
            flutterPluginBinding.binaryMessenger, "${Components.PACKAGE_NAME}/service"
        )
        flutterMethodChannel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        Service.unbind()
        flutterMethodChannel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) = when (call.method) {
        "init" -> {
            handleInit(result)
        }

        "invokeAction" -> {
            handleInvokeAction(call, result)
        }

        "getRunTime" -> {
            handleGetRunTime(result)
        }

        "start" -> {
            handleStart(result)
        }

        "stop" -> {
            handleStop(result)
        }

        else -> {
            result.notImplemented()
        }
    }

    private fun handleInvokeAction(call: MethodCall, result: MethodChannel.Result) {
        launch {
            val data = call.arguments<String>()!!
            Service.invokeAction(data) {
                result.success(it)
            }
        }
    }

    private fun handleStart(result: MethodChannel.Result) {
        State.handleStartService()
        result.success(true)
    }

    private fun handleServiceCrash() {

    }

    private fun handleStop(result: MethodChannel.Result) {
        State.handleStopService()
        result.success(true)
    }

    suspend fun handleGetVpnOptions(): VpnOptions? {
        val res = flutterMethodChannel.awaitResult<String>("getVpnOptions", null)
        return Gson().fromJson(res, VpnOptions::class.java)
    }

    suspend fun startService(options: VpnOptions, inApp: Boolean) {
        Service.startService(options, inApp)
    }

    suspend fun stopService() {
        Service.stopService()
    }

    val semaphore = Semaphore(10)

    fun handleSendMessage(value: String?) {
        launch(Dispatchers.Main) {
            semaphore.withPermit {
                flutterMethodChannel.invokeMethod("message", value)
            }
        }
    }

    private fun onServiceCrash() {

    }

    fun handleInit(result: MethodChannel.Result) {
        launch {
            Service.setMessageCallback {
                GlobalState.launch(Dispatchers.Main) {
                    handleSendMessage(it)
                }
            }
            result.success(true)
        }
        Service.onServiceCrash = ::onServiceCrash
    }

    private fun handleGetRunTime(result: MethodChannel.Result) {
        return result.success(State.runTime)
    }
}