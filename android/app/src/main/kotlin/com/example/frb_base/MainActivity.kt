package com.example.frb_base

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
  init {
    System.loadLibrary("rust_lib_frb_base")
  }
}
