package com.pos.pos_android

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.pos.pos_android/ubii_pos"
    private val UBII_REQUEST_CODE = 1001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "processPayment" -> {
                    val amount = call.argument<String>("amount")
                    val logon = call.argument<String>("logon")
                    
                    if (amount != null && logon != null) {
                        pendingResult = result
                        launchUbiiPOS(amount, logon)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Amount and logon are required", null)
                    }
                }
                "processSettlement" -> {
                    val settleType = call.argument<String>("settleType")
                    
                    if (settleType != null) {
                        pendingResult = result
                        launchUbiiSettlement(settleType)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Settle type is required", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun launchUbiiPOS(amount: String, logon: String) {
        try {
            val intent = Intent().apply {
                action = "com.ubiipagos.pos.views.activity.MainActivityView.launchFromOutside"
                putExtra("TRANS_TYPE", "PAYMENT")
                putExtra("TRANS_AMOUNT", amount)
                putExtra("LOGON", logon)
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            
            startActivityForResult(intent, UBII_REQUEST_CODE)
        } catch (e: Exception) {
            pendingResult?.error("LAUNCH_ERROR", "Error launching Ubii POS: ${e.message}", null)
            pendingResult = null
        }
    }

    private fun launchUbiiSettlement(settleType: String) {
        try {
            val intent = Intent().apply {
                action = "com.ubiipagos.pos.views.activity.MainActivityView.launchFromOutside"
                putExtra("TRANS_TYPE", "SETTLEMENT")
                putExtra("SETTLE_TYPE", settleType)
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            
            startActivityForResult(intent, UBII_REQUEST_CODE)
        } catch (e: Exception) {
            pendingResult?.error("LAUNCH_ERROR", "Error launching Ubii settlement: ${e.message}", null)
            pendingResult = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        // ========================================
        // LOGS INICIALES - SIEMPRE SE MUESTRAN
        // ========================================
        android.util.Log.e("UbiiPOS", "╔════════════════════════════════════════╗")
        android.util.Log.e("UbiiPOS", "║   onActivityResult LLAMADO             ║")
        android.util.Log.e("UbiiPOS", "╚════════════════════════════════════════╝")
        android.util.Log.e("UbiiPOS", "Request Code: $requestCode")
        android.util.Log.e("UbiiPOS", "Expected Code: $UBII_REQUEST_CODE")
        android.util.Log.e("UbiiPOS", "Match: ${requestCode == UBII_REQUEST_CODE}")
        android.util.Log.e("UbiiPOS", "Result Code: $resultCode")
        android.util.Log.e("UbiiPOS", "Result Code Name: ${when(resultCode) {
            Activity.RESULT_OK -> "RESULT_OK"
            Activity.RESULT_CANCELED -> "RESULT_CANCELED"
            else -> "UNKNOWN ($resultCode)"
        }}")
        android.util.Log.e("UbiiPOS", "Data is null: ${data == null}")
        android.util.Log.e("UbiiPOS", "Extras is null: ${data?.extras == null}")
        android.util.Log.e("UbiiPOS", "Pending Result is null: ${pendingResult == null}")
        android.util.Log.e("UbiiPOS", "========================================")
        
        if (requestCode == UBII_REQUEST_CODE) {
            if (pendingResult == null) {
                android.util.Log.e("UbiiPOS", "⚠️ WARNING: pendingResult is null, cannot send response to Flutter")
                return
            }
            
            when (resultCode) {
                Activity.RESULT_OK -> {
                    android.util.Log.e("UbiiPOS", "")
                    android.util.Log.e("UbiiPOS", "╔════════════════════════════════════════╗")
                    android.util.Log.e("UbiiPOS", "║   RESULT_OK - Procesando respuesta     ║")
                    android.util.Log.e("UbiiPOS", "╚════════════════════════════════════════╝")
                    // Transacción exitosa - extraer datos
                    val responseData = mutableMapOf<String, Any?>()
                    
                    if (data?.extras != null) {
                        val bundle = data.extras!!
                        
                        // Log TODOS los keys disponibles CON MÁXIMO DETALLE
                        android.util.Log.e("UbiiPOS", "========================================")
                        android.util.Log.e("UbiiPOS", "BUNDLE COMPLETO - TODOS LOS DATOS:")
                        android.util.Log.e("UbiiPOS", "Total keys: ${bundle.keySet().size}")
                        android.util.Log.e("UbiiPOS", "========================================")
                        for (key in bundle.keySet()) {
                            val value = bundle.get(key)
                            val valueStr = if (value == null) "NULL" else value.toString()
                            val isEmpty = valueStr.isEmpty() || valueStr == "null" || valueStr == "NULL"
                            android.util.Log.e("UbiiPOS", "KEY: '$key'")
                            android.util.Log.e("UbiiPOS", "  VALUE: '$valueStr'")
                            android.util.Log.e("UbiiPOS", "  TYPE: ${value?.javaClass?.simpleName ?: "null"}")
                            android.util.Log.e("UbiiPOS", "  IS_EMPTY: $isEmpty")
                            android.util.Log.e("UbiiPOS", "  LENGTH: ${valueStr.length}")
                            android.util.Log.e("UbiiPOS", "----------------------------------------")
                        }
                        android.util.Log.e("UbiiPOS", "========================================")
                        
                        // Extraer datos según documentación oficial de Ubii
                        val code = bundle.getString("TRANS_CODE_RESULT", "")
                        val message = bundle.getString("TRANS_MESSAGE_RESULT", "")
                        val authCode = bundle.getString("TRANS_CONFIRM_NUM", "")
                        val reference = bundle.getString("REFERENCIA", "")
                        val trace = bundle.getString("TRACE", "")
                        val date = bundle.getString("FECHA", "")
                        val terminal = bundle.getString("TERMINAL", "")
                        val lote = bundle.getString("LOTE", "")
                        
                        responseData["code"] = code
                        responseData["message"] = message
                        responseData["authCode"] = authCode
                        responseData["reference"] = reference
                        responseData["trace"] = trace
                        responseData["date"] = date
                        responseData["bin"] = bundle.getString("BIN", "")
                        responseData["terminal"] = terminal
                        responseData["merchantId"] = bundle.getString("AFILIADO", "")
                        responseData["lote"] = lote
                        responseData["cardType"] = bundle.getString("TIPO_TARJETA", "")
                        responseData["entryMethod"] = bundle.getString("METODO_ENTRADA", "")
                        
                        // Log para debugging CON MÁXIMO DETALLE
                        android.util.Log.e("UbiiPOS", "========================================")
                        android.util.Log.e("UbiiPOS", "DATOS EXTRAÍDOS:")
                        android.util.Log.e("UbiiPOS", "  code: '$code' (length: ${code.length}, isEmpty: ${code.isEmpty()})")
                        android.util.Log.e("UbiiPOS", "  message: '$message' (length: ${message.length}, isEmpty: ${message.isEmpty()})")
                        android.util.Log.e("UbiiPOS", "  reference: '$reference' (length: ${reference.length}, isEmpty: ${reference.isEmpty()})")
                        android.util.Log.e("UbiiPOS", "  authCode: '$authCode' (length: ${authCode.length}, isEmpty: ${authCode.isEmpty()})")
                        android.util.Log.e("UbiiPOS", "  trace: '$trace' (length: ${trace.length}, isEmpty: ${trace.isEmpty()})")
                        android.util.Log.e("UbiiPOS", "  date: '$date' (length: ${date.length}, isEmpty: ${date.isEmpty()})")
                        android.util.Log.e("UbiiPOS", "  terminal: '$terminal' (length: ${terminal.length}, isEmpty: ${terminal.isEmpty()})")
                        android.util.Log.e("UbiiPOS", "  lote: '$lote' (length: ${lote.length}, isEmpty: ${lote.isEmpty()})")
                        android.util.Log.e("UbiiPOS", "========================================")
                        
                        // IMPORTANTE: Detectar si REALMENTE es una cancelación
                        // Solo considerar cancelación si TODOS los campos críticos están vacíos
                        val allCriticalFieldsEmpty = code.isEmpty() && 
                                                     message.isEmpty() && 
                                                     reference.isEmpty() && 
                                                     authCode.isEmpty() &&
                                                     trace.isEmpty() &&
                                                     date.isEmpty() &&
                                                     terminal.isEmpty() &&
                                                     lote.isEmpty()
                        
                        android.util.Log.e("UbiiPOS", "ANÁLISIS DE CANCELACIÓN:")
                        android.util.Log.e("UbiiPOS", "  code.isEmpty(): ${code.isEmpty()}")
                        android.util.Log.e("UbiiPOS", "  message.isEmpty(): ${message.isEmpty()}")
                        android.util.Log.e("UbiiPOS", "  reference.isEmpty(): ${reference.isEmpty()}")
                        android.util.Log.e("UbiiPOS", "  authCode.isEmpty(): ${authCode.isEmpty()}")
                        android.util.Log.e("UbiiPOS", "  trace.isEmpty(): ${trace.isEmpty()}")
                        android.util.Log.e("UbiiPOS", "  date.isEmpty(): ${date.isEmpty()}")
                        android.util.Log.e("UbiiPOS", "  terminal.isEmpty(): ${terminal.isEmpty()}")
                        android.util.Log.e("UbiiPOS", "  lote.isEmpty(): ${lote.isEmpty()}")
                        android.util.Log.e("UbiiPOS", "  allCriticalFieldsEmpty: $allCriticalFieldsEmpty")
                        android.util.Log.e("UbiiPOS", "========================================")
                        
                        if (allCriticalFieldsEmpty) {
                            android.util.Log.w("UbiiPOS", "⚠️ TODOS LOS CAMPOS CRÍTICOS VACÍOS - DETECTANDO COMO CANCELACIÓN")
                            responseData["code"] = "CANCELLED"
                            responseData["message"] = "Transacción cancelada por el usuario"
                        } else {
                            android.util.Log.i("UbiiPOS", "✅ AL MENOS UN CAMPO TIENE DATOS - NO ES CANCELACIÓN")
                        }
                    } else {
                        // Ubii POS no retornó datos - esto puede pasar en algunas versiones
                        android.util.Log.w("UbiiPOS", "No data received from Ubii POS")
                        responseData["code"] = "NO_DATA"
                        responseData["message"] = "Ubii POS no retornó datos. La transacción puede haberse procesado."
                    }
                    
                    pendingResult?.success(responseData)
                }
                Activity.RESULT_CANCELED -> {
                    android.util.Log.e("UbiiPOS", "")
                    android.util.Log.e("UbiiPOS", "╔════════════════════════════════════════╗")
                    android.util.Log.e("UbiiPOS", "║   RESULT_CANCELED - Usuario canceló    ║")
                    android.util.Log.e("UbiiPOS", "╚════════════════════════════════════════╝")
                    android.util.Log.e("UbiiPOS", "Data is null: ${data == null}")
                    android.util.Log.e("UbiiPOS", "Extras is null: ${data?.extras == null}")
                    
                    // Verificar si hay datos incluso en RESULT_CANCELED
                    if (data?.extras != null) {
                        val bundle = data.extras!!
                        android.util.Log.e("UbiiPOS", "⚠️ RESULT_CANCELED pero HAY DATOS en el bundle!")
                        android.util.Log.e("UbiiPOS", "Total keys: ${bundle.keySet().size}")
                        android.util.Log.e("UbiiPOS", "Keys: ${bundle.keySet().joinToString(", ")}")
                        
                        // Mostrar todos los datos
                        for (key in bundle.keySet()) {
                            val value = bundle.get(key)
                            android.util.Log.e("UbiiPOS", "  $key = $value")
                        }
                    } else {
                        android.util.Log.e("UbiiPOS", "✓ No hay datos en el bundle (esperado para cancelación)")
                    }
                    
                    android.util.Log.e("UbiiPOS", "Enviando código CANCELLED a Flutter")
                    android.util.Log.e("UbiiPOS", "========================================")
                    
                    pendingResult?.success(mapOf(
                        "code" to "CANCELLED",
                        "message" to "Transaction cancelled by user"
                    ))
                }
                else -> {
                    android.util.Log.e("UbiiPOS", "")
                    android.util.Log.e("UbiiPOS", "╔════════════════════════════════════════╗")
                    android.util.Log.e("UbiiPOS", "║   RESULTADO DESCONOCIDO                ║")
                    android.util.Log.e("UbiiPOS", "╚════════════════════════════════════════╝")
                    android.util.Log.e("UbiiPOS", "Result Code: $resultCode")
                    android.util.Log.e("UbiiPOS", "Data is null: ${data == null}")
                    android.util.Log.e("UbiiPOS", "Extras is null: ${data?.extras == null}")
                    
                    // Verificar si hay datos
                    if (data?.extras != null) {
                        val bundle = data.extras!!
                        android.util.Log.e("UbiiPOS", "⚠️ Resultado desconocido pero HAY DATOS!")
                        android.util.Log.e("UbiiPOS", "Total keys: ${bundle.keySet().size}")
                        android.util.Log.e("UbiiPOS", "Keys: ${bundle.keySet().joinToString(", ")}")
                        
                        // Mostrar todos los datos
                        for (key in bundle.keySet()) {
                            val value = bundle.get(key)
                            android.util.Log.e("UbiiPOS", "  $key = $value")
                        }
                    }
                    
                    android.util.Log.e("UbiiPOS", "Enviando error UNKNOWN_ERROR a Flutter")
                    android.util.Log.e("UbiiPOS", "========================================")
                    
                    pendingResult?.error(
                        "UNKNOWN_ERROR",
                        "Unknown result code: $resultCode",
                        null
                    )
                }
            }
            
            android.util.Log.e("UbiiPOS", "")
            android.util.Log.e("UbiiPOS", "╔════════════════════════════════════════╗")
            android.util.Log.e("UbiiPOS", "║   FINALIZANDO onActivityResult         ║")
            android.util.Log.e("UbiiPOS", "╚════════════════════════════════════════╝")
            android.util.Log.e("UbiiPOS", "Limpiando pendingResult")
            pendingResult = null
            android.util.Log.e("UbiiPOS", "✓ Proceso completado")
            android.util.Log.e("UbiiPOS", "========================================")
        } else {
            android.util.Log.e("UbiiPOS", "⚠️ Request code no coincide, ignorando")
            android.util.Log.e("UbiiPOS", "  Expected: $UBII_REQUEST_CODE")
            android.util.Log.e("UbiiPOS", "  Received: $requestCode")
        }
    }
}
