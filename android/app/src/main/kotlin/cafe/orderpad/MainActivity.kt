package cafe.orderpad

import android.os.Build
import android.view.View
import android.view.WindowInsetsController
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onPostResume() {
        super.onPostResume()
        enableFullscreen()
    }
    
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            enableFullscreen()
        }
    }
    
    private fun enableFullscreen() {
        val decorView = window.decorView
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // For Android 11 (API 30) and above
            window.setDecorFitsSystemWindows(false)
            val controller = decorView.windowInsetsController
            controller?.let {
                it.hide(android.view.WindowInsets.Type.navigationBars())
                it.hide(android.view.WindowInsets.Type.statusBars())
                it.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            // For Android 10 and below
            @Suppress("DEPRECATION")
            val flags = (View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY)
            decorView.systemUiVisibility = flags
        }
    }
}

