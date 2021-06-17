package com.chuangdun.flutter.plugin.JyFp

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaPlayer
import android.os.Handler
import android.util.Base64
import android.util.Log
import androidx.annotation.NonNull
import com.jy.finger.Common.Finger
import com.jy.finger.Common.FpCommon
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.ByteArrayOutputStream
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit

private const val TAG = "JyFpPlugin"
private const val SDK_EVENT_REGISTRY_NAME = "JyFpEvent"
private const val EVENT_ON_FP_IMAGE_RECEIVED = 0
private const val EVENT_ON_FEATURE_RECEIVED = 1
private const val EVENT_ON_FINGER_RECEIVED = 2

/** JyFpPlugin */
class JyFpPlugin: FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
  private lateinit var context: Context
  private lateinit var channel : MethodChannel
  private lateinit var eventChannel: EventChannel
  private var eventSink: EventChannel.EventSink? = null
  private var mMediaPlayer: MediaPlayer? = null
  private lateinit var threadPool:ThreadPoolExecutor
  private val uiHandler = Handler()

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    threadPool = ThreadPoolExecutor(
            1, 1, 0L, TimeUnit.MILLISECONDS, LinkedBlockingQueue<Runnable>())
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "JyFp")
    channel.setMethodCallHandler(this)
    eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, SDK_EVENT_REGISTRY_NAME)
    eventChannel.setStreamHandler(this)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    Log.i(TAG, "JyFpPlugin:onMethodCall:${call.method}")
    when(call.method){
      "init" -> {
        FpCommon.init(context)
      }
      "openFpModule" -> {
        var isOpen = FpCommon.openFpModule() == 0
        if (!isOpen) {
          FpCommon.init(context)
          isOpen = FpCommon.openFpModule() == 0
        }
        result.success(isOpen)
      }
      "closeFpModule" -> {
        FpCommon.closeFpModule()
      }
      "getFpImage" -> {
        val taskGetFpImage = Runnable {
          playSound(R.raw.finger_collect, 2500)
          val fpBitmap = FpCommon.getFpImage()
          FpCommon.stopGetImge()
          val byteArray: ByteArray? = if (fpBitmap != null) {
            playSound(R.raw.finger_success, 1500)
            val outputStream = ByteArrayOutputStream()
            fpBitmap.compress(Bitmap.CompressFormat.JPEG, 100, outputStream)
            outputStream.toByteArray()
          } else null
          uiHandler.post {
            eventSink?.success(mapOf(
                    "event" to EVENT_ON_FP_IMAGE_RECEIVED,
                    "bitmap" to byteArray
            ))
          }
        }
        threadPool.submit(taskGetFpImage)
      }
      "getFpFeature" -> {
        val taskGetFeature = Runnable {
          playSound(R.raw.finger_collect, 2500)
          val feature = FpCommon.getFpFeature()
          val base64Feature: String? = if (feature != null) {
            playSound(R.raw.finger_success, 1500)
            Base64.encodeToString(feature, Base64.DEFAULT)
          } else null
          uiHandler.post {
            eventSink?.success(mapOf(
                    "event" to EVENT_ON_FEATURE_RECEIVED,
                    "feature" to base64Feature
            ))
          }
        }
        threadPool.submit(taskGetFeature)
      }
      "getFingerInfo" -> {
        val taskGetFinger = Runnable {
          playSound(R.raw.finger_collect, 2500)
          val finger = FpCommon.getFingerObj(0)
          val event = if (finger != null) {
            playSound(R.raw.finger_success, 1500)
            val base64Feature = Base64.encodeToString(finger.fpFeature, Base64.DEFAULT)
            val outputStream = ByteArrayOutputStream()
            finger.fpBitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
            outputStream.toByteArray()
            mapOf(
                    "event" to EVENT_ON_FINGER_RECEIVED,
                    "feature" to base64Feature,
                    "bitmap" to outputStream.toByteArray(),
                    "quality" to finger.quality
            )
          } else {
            mapOf(
                    "event" to EVENT_ON_FINGER_RECEIVED,
                    "feature" to null,
                    "bitmap" to null,
                    "quality" to 0
            )
          }
          uiHandler.post { eventSink?.success(event) }
        }
        threadPool.submit(taskGetFinger)
      }
      "compareFpFeature" -> {
        val arguments = call.arguments as Map<*, *>
        if (arguments.containsKey("threshold")){
          FpCommon.setFingerMatchValue(arguments["threshold"] as Int)
        }
        val src = Base64.decode(arguments["src"] as String, Base64.DEFAULT)
        val dest = Base64.decode(arguments["dest"] as String, Base64.DEFAULT)
        val match = FpCommon.compareFpFeature(src, dest)
        result.success(match)
      }
      "setFingerMatchValue" -> {
        val threshold = call.arguments as Int
        FpCommon.setFingerMatchValue(threshold)
      }
      "getFingerMatchValue" -> {
        val value = FpCommon.getFingerMatchValue()
        result.success(value)
      }
      "getCompareValue" -> {
        val arguments = call.arguments as Map<*, *>
        val src = Base64.decode(arguments["src"] as String, Base64.DEFAULT)
        val dest = Base64.decode(arguments["dest"] as String, Base64.DEFAULT)
        val score = FpCommon.getCompareValue(src, dest)
        result.success(score)
      }
      "setFingerColor" -> {
        val useDefaultColor = call.arguments as Boolean
        if (useDefaultColor){
          FpCommon.setFingerColor(Finger.BLACK)
        }else{
          FpCommon.setFingerColor(Finger.RED)
        }
      }
      "setQualityThreshold" -> {
        val threshold = call.arguments as Int
        FpCommon.setQualityThreshold(threshold)
      }
      "destroy" -> {
        FpCommon.onDestroy()
      }
      else -> result.notImplemented()
    }
  }


  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
    if (!threadPool.isShutdown){
      threadPool.shutdownNow()
    }
  }


  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    this.eventSink = events
  }

  override fun onCancel(arguments: Any?) {
    this.eventSink = null
  }

  private fun playSound(resid: Int, waitMillis: Long){
    try {
      mMediaPlayer = MediaPlayer.create(context, resid)
      mMediaPlayer!!.start()
      Thread.sleep(waitMillis)
      mMediaPlayer!!.stop()
      mMediaPlayer!!.release()
    }catch (e: InterruptedException){
      Log.e(TAG, "线程睡眠waitMillis毫秒失败.${e.message}")
    }catch (e: Exception) {
      Log.e(TAG, "MediaPlayer错误.${e.message}")
    }
  }
}
