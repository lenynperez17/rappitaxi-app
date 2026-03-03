package com.rapiteam.app

import android.app.Activity
import android.content.Intent
import android.util.Log
import com.google.gson.Gson
import com.izipay.izipay_pw_sdk.data.model.*
import com.izipay.izipay_pw_sdk.ui.fullscreend.ContainerActivity
import com.izipay.izipay_pw_sdk.utils.Response
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

/// Plugin nativo para integrar el SDK de Izipay v2.3.0 con Flutter
/// Abre la pantalla nativa de pago del SDK y retorna el resultado
class IzipayPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware,
    PluginRegistry.ActivityResultListener {

    private var channel: MethodChannel? = null
    private var channelResult: MethodChannel.Result? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var transactionStartDatetime: String = ""

    companion object {
        const val CHANNEL_NAME = "com.rapiteam.app/izipay"
        const val REQUEST_CODE = 1001
        private const val TAG = "IzipayPlugin"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        activityBinding?.addActivityResultListener(this)
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        channel?.setMethodCallHandler(null)
        channelResult = null
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startPayment" -> {
                transactionStartDatetime = getCurrentTimestamp()
                channelResult = result

                val args = call.arguments as? Map<String, Any> ?: run {
                    result.error("INVALID_ARGUMENTS", "Argumentos inválidos recibidos desde Dart", null)
                    return
                }

                Log.d(TAG, "Iniciando pago Izipay v2.3.0: $args")

                val environment = args["environment"] as? String ?: "TEST"
                val action = args["action"] as? String ?: "pay"
                // authorization = publicKey completa (ej: "69012033:testpublickey_...")
                val authorization = args["clientId"] as? String ?: ""
                val merchantCode = args["merchantId"] as? String ?: ""
                val orderTimestamp = System.currentTimeMillis().toString()

                val order = args["order"] as? Map<String, Any> ?: mapOf()
                val billing = args["billing"] as? Map<String, Any> ?: mapOf()
                val appearance = args["appearance"] as? Map<String, Any> ?: mapOf()

                val listPayMethod = arrayListOf(PayOption.CARD)

                val request = buildConfigRequest(
                    listPayMethod = listPayMethod,
                    environment = environment,
                    action = action,
                    authorization = authorization,
                    transactionId = "RT$orderTimestamp",
                    merchantId = merchantCode,
                    order = order,
                    billing = billing,
                    appearance = appearance
                )

                Log.d(TAG, "ConfigRequest v2.3.0: env=${request.environment}, action=${request.action}, " +
                    "authorization=${request.authorization}, merchantCode=${request.merchantCode}, " +
                    "transactionId=${request.transactionId}, " +
                    "order=[number=${request.order?.orderNumber}, currency=${request.order?.currency}, " +
                    "amount=${request.order?.amount}, processType=${request.order?.processType}, " +
                    "merchantBuyerId=${request.order?.merchantBuyerId}, " +
                    "dateTime=${request.order?.dateTimeTransaction}]")

                val intent = Intent(activity, ContainerActivity::class.java).apply {
                    putExtra(Response.REQUEST, request)
                }
                activity?.startActivityForResult(intent, REQUEST_CODE)
            }
            else -> result.notImplemented()
        }
    }

    private fun buildConfigRequest(
        listPayMethod: ArrayList<PayOption>,
        environment: String,
        action: String,
        authorization: String,
        transactionId: String,
        merchantId: String,
        order: Map<String, Any>,
        billing: Map<String, Any>,
        appearance: Map<String, Any>
    ): ConfigRequest {
        // orderNumber debe tener 13 dígitos según la documentación del SDK
        val orderNumber = SimpleDateFormat("yyMMddHHmmssS", Locale.getDefault()).format(Date())
            .take(13)
        // SDK v2.3.0: ConfigRequest(environment, authorization, action, transactionId,
        //   merchantCode, facilitatorCode, order, token, billing, shipping, appearance,
        //   urlIPN, cardSelector, customFields)
        return ConfigRequest(
            environment,
            authorization,
            action,
            transactionId,
            merchantId,
            "",
            OrderPaymentIzipay(
                orderNumber,
                order["currency"] as? String ?: "PEN",
                order["amount"] as? String ?: "10.00",
                listPayMethod,
                "authorize",
                "RT$orderNumber",
                System.currentTimeMillis().toString()
            ),
            TokenPaymentIzipay(""),
            BillingPaymentIzipay(
                billing["firstName"] as? String ?: "Cliente",
                billing["lastName"] as? String ?: "RapiTeam",
                billing["email"] as? String ?: "cliente@rapiteam.app",
                billing["phone"] as? String ?: "999999999",
                billing["address"] as? String ?: "Lima",
                billing["city"] as? String ?: "Lima",
                billing["region"] as? String ?: "Lima",
                billing["country"] as? String ?: "PE",
                billing["postalCode"] as? String ?: "15001",
                billing["idType"] as? String ?: "DNI",
                billing["idNumber"] as? String ?: "00000000"
            ),
            null,
            AppearencePaymentIzipay(
                appearance["language"] as? String ?: "ESP",
                AppearenceControlsPaymentIzipay(true, false),
                AppearenceVisualSettingsPaymentIzipay(true),
                appearance["themeColor"] as? String ?: "green",
                CustomThemePaymentIzipay(
                    appearance["primaryColor"] as? String ?: "#6C63FF",
                    appearance["secondaryColor"] as? String ?: "#6C63FF",
                    appearance["tertiaryColor"] as? String ?: "#6C63FF"
                ),
                appearance["logoUrl"] as? String ?: ""
            ),
            "",
            null,
            null
        )
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQUEST_CODE) {
            try {
                val dataPayLoad = data?.extras?.getString(Response.RESPONSEPAYLOAD)

                if (dataPayLoad.isNullOrEmpty()) {
                    channelResult?.error("NO_DATA", "No se recibió respuesta del SDK Izipay", null)
                    return true
                }

                val jsonData = JSONObject(dataPayLoad)
                val code = jsonData.optString("code", "")
                val message = jsonData.optString("message", "")
                val response = jsonData.optJSONObject("response")
                val merchant = response?.optJSONObject("merchant")
                val card = response?.optJSONObject("card")
                val token = response?.optJSONObject("token")
                val orderArray = response?.optJSONArray("order")
                val order = orderArray?.optJSONObject(0)

                val dataMap = mapOf(
                    "code" to code,
                    "message" to message,
                    "header" to mapOf(
                        "transactionStartDatetime" to transactionStartDatetime,
                        "transactionEndDatetime" to getCurrentTimestamp(),
                        "millis" to calculateMillis(transactionStartDatetime, getCurrentTimestamp())
                    ),
                    "response" to if (response != null) {
                        mapOf(
                            "merchantCode" to (merchant?.optString("merchantCode", "") ?: ""),
                            "merchantBuyerId" to (token?.optString("merchantBuyerId", "") ?: ""),
                            "card" to mapOf(
                                "brand" to (card?.optString("brand", "") ?: ""),
                                "pan" to (card?.optString("pan", "") ?: "")
                            ),
                            "token" to mapOf(
                                "cardToken" to (token?.optString("cardToken", "") ?: "")
                            ),
                            "transactionId" to (jsonData.optString("transactionId", "")),
                            "orderNumber" to (order?.optString("orderNumber", "") ?: "")
                        )
                    } else {
                        emptyMap()
                    },
                    "payload" to jsonData.optString("payloadHttp", ""),
                    "result" to mapOf(
                        "messageFriendly" to jsonData.optString("messageUser", "")
                    )
                )

                val gson = Gson()
                val jsonGson = gson.toJson(dataMap)

                Log.d(TAG, "Resultado pago: code=$code, resultCode=$resultCode")

                if (resultCode == Activity.RESULT_OK) {
                    channelResult?.success(jsonGson)
                } else {
                    // Incluso con RESULT_CANCELED, enviar la data para que Flutter procese
                    channelResult?.success(jsonGson)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error procesando resultado Izipay: ${e.message}", e)
                channelResult?.error("PARSE_ERROR", "Error procesando respuesta: ${e.message}", null)
            }
            return true
        }
        return false
    }

    private fun getCurrentTimestamp(): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.getDefault())
        return formatter.format(Date())
    }

    private fun calculateMillis(start: String, end: String): Int {
        val formatter = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.getDefault())
        return try {
            val startDate = formatter.parse(start)
            val endDate = formatter.parse(end)
            if (startDate != null && endDate != null) {
                (endDate.time - startDate.time).toInt()
            } else 0
        } catch (e: Exception) { 0 }
    }
}
