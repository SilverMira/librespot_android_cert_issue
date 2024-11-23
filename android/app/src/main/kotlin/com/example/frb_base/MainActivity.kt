package com.example.frb_base

import android.content.Context
import android.util.Log
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    flutterEngine.plugins.add(RustJniContext())
  }
}

class RustJniContext: FlutterPlugin, MethodChannel.MethodCallHandler {
  companion object {
    init {
      Log.d("test_librespot", "loadLibrary")
      System.loadLibrary("rust_lib_frb_base")
    }
  }

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    Log.d("test_librespot", "onAttachedToEngine")
    initAndroid(binding.applicationContext)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {

  }

  external fun initAndroid(ctx: Context): Int
  override fun onMethodCall(
    call: MethodCall,
    result: MethodChannel.Result
  ) {
    result.notImplemented()
  }
}