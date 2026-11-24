package com.netravision.apps

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class NetraAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "NetraA11y"
        var instance: NetraAccessibilityService? = null
            private set

        @Volatile
        var pendingAction: String? = null // "video_call", "voice_call", "send_chat"
        @Volatile
        var armTime: Long = 0L

        fun arm(action: String) {
            pendingAction = action
            armTime = System.currentTimeMillis()
            Log.d(TAG, "Armed action: $action at $armTime")
        }

        fun disarm() {
            pendingAction = null
            armTime = 0L
            Log.d(TAG, "Disarmed action")
        }

        fun isServiceRunning(): Boolean {
            return instance != null
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d(TAG, "NetraAccessibilityService connected and ready!")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.d(TAG, "NetraAccessibilityService destroyed")
    }

    override fun onInterrupt() {
        disarm()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val action = pendingAction ?: return
        if (System.currentTimeMillis() - armTime > 15000L) {
            disarm()
            return
        }

        val pkg = event?.packageName?.toString() ?: ""
        if (!pkg.contains("whatsapp")) return

        val root = rootInActiveWindow ?: event?.source ?: return

        when (action) {
            "video_call" -> {
                val sendKeywords = listOf("kirim", "send", "send_btn", "entry_send")
                val videoKeywords = listOf(
                    "telepon video",
                    "panggilan video",
                    "video call",
                    "video_call",
                    "videocall",
                    "menuitem_video_call",
                    "video_call_btn"
                )

                // 1. Kirim pesan darurat secara otomatis terlebih dahulu
                if (searchAndClick(root, sendKeywords)) {
                    Log.d(TAG, "Pesan darurat otomatis terkirim! Melanjutkan memicu panggilan video...")
                    pendingAction = "video_call_after_send"
                    armTime = System.currentTimeMillis()
                    mainHandler.postDelayed({
                        val currentRoot = rootInActiveWindow ?: return@postDelayed
                        if (searchAndClick(currentRoot, videoKeywords)) {
                            pendingAction = "confirm_call"
                            armTime = System.currentTimeMillis()
                        }
                    }, 400L)
                    return
                }

                // 2. Jika tombol kirim tidak ada (misal pesan sudah terkirim), langsung klik tombol video call
                if (searchAndClick(root, videoKeywords)) {
                    Log.d(TAG, "Successfully triggered Video Call click! Watching for confirm dialog...")
                    pendingAction = "confirm_call"
                    armTime = System.currentTimeMillis()
                }
            }
            "video_call_after_send" -> {
                val videoKeywords = listOf(
                    "telepon video",
                    "panggilan video",
                    "video call",
                    "video_call",
                    "videocall",
                    "menuitem_video_call",
                    "video_call_btn"
                )
                if (searchAndClick(root, videoKeywords)) {
                    Log.d(TAG, "Successfully triggered Video Call click after send! Watching for confirm dialog...")
                    pendingAction = "confirm_call"
                    armTime = System.currentTimeMillis()
                }
            }
            "voice_call" -> {
                val sendKeywords = listOf("kirim", "send", "send_btn", "entry_send")
                val voiceKeywords = listOf(
                    "telepon suara",
                    "panggilan suara",
                    "voice call",
                    "voice_call",
                    "audio call",
                    "menuitem_voice_call",
                    "voice_call_btn"
                )

                // 1. Kirim pesan darurat terlebih dahulu
                if (searchAndClick(root, sendKeywords)) {
                    Log.d(TAG, "Pesan darurat otomatis terkirim! Melanjutkan memicu panggilan suara...")
                    pendingAction = "voice_call_after_send"
                    armTime = System.currentTimeMillis()
                    mainHandler.postDelayed({
                        val currentRoot = rootInActiveWindow ?: return@postDelayed
                        if (searchAndClick(currentRoot, voiceKeywords)) {
                            pendingAction = "confirm_call"
                            armTime = System.currentTimeMillis()
                        }
                    }, 400L)
                    return
                }

                if (searchAndClick(root, voiceKeywords)) {
                    Log.d(TAG, "Successfully triggered Voice Call click! Watching for confirm dialog...")
                    pendingAction = "confirm_call"
                    armTime = System.currentTimeMillis()
                }
            }
            "voice_call_after_send" -> {
                val voiceKeywords = listOf(
                    "telepon suara",
                    "panggilan suara",
                    "voice call",
                    "voice_call",
                    "audio call",
                    "menuitem_voice_call",
                    "voice_call_btn"
                )
                if (searchAndClick(root, voiceKeywords)) {
                    pendingAction = "confirm_call"
                    armTime = System.currentTimeMillis()
                }
            }
            "confirm_call" -> {
                // Jika layar panggilan sudah aktif, selesai
                val callKeywords = listOf("call_screen", "call_grid", "tidak dijawab", "memanggil", "berdering", "calling", "ringing", "selesai")
                if (containsAny(root, callKeywords)) {
                    Log.d(TAG, "Call is active! Disarming.")
                    disarm()
                    return
                }
                // Klik tombol konfirmasi (e.g. "Panggil", "Call", "Mulai Panggilan")
                val confirmKeywords = listOf("panggil", "call", "mulai panggilan", "start call")
                if (searchAndClick(root, confirmKeywords)) {
                    Log.d(TAG, "Confirmed call dialog!")
                    disarm()
                } else if (System.currentTimeMillis() - armTime > 3500L) {
                    disarm()
                }
            }
            "send_chat" -> {
                val targetKeywords = listOf("kirim", "send", "send_btn", "entry_send")
                if (searchAndClick(root, targetKeywords)) {
                    Log.d(TAG, "Successfully triggered Send Chat click!")
                    disarm()
                }
            }
        }
    }

    private fun containsAny(node: AccessibilityNodeInfo, keywords: List<String>): Boolean {
        val desc = node.contentDescription?.toString()?.lowercase() ?: ""
        val text = node.text?.toString()?.lowercase() ?: ""
        val id = node.viewIdResourceName?.lowercase() ?: ""

        for (kw in keywords) {
            if (desc.contains(kw) || text.contains(kw) || id.contains(kw)) return true
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            if (containsAny(child, keywords)) return true
        }
        return false
    }

    private fun searchAndClick(node: AccessibilityNodeInfo, keywords: List<String>): Boolean {
        val desc = node.contentDescription?.toString()?.lowercase() ?: ""
        val text = node.text?.toString()?.lowercase() ?: ""
        val id = node.viewIdResourceName?.lowercase() ?: ""

        for (kw in keywords) {
            if (desc.contains(kw) || text.contains(kw) || id.contains(kw)) {
                Log.d(TAG, "Found target view: desc='$desc', text='$text', id='$id'")
                val rect = Rect()
                node.getBoundsInScreen(rect)
                if (!rect.isEmpty) {
                    dispatchTapGesture(rect.centerX().toFloat(), rect.centerY().toFloat())
                }
                if (node.isClickable) {
                    node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                }
                var parent = node.parent
                while (parent != null) {
                    if (parent.isClickable) {
                        parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                        break
                    }
                    parent = parent.parent
                }
                return true
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            if (searchAndClick(child, keywords)) {
                return true
            }
        }

        return false
    }

    private fun dispatchTapGesture(x: Float, y: Float) {
        val path = Path().apply {
            moveTo(x, y)
        }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 60))
            .build()
        dispatchGesture(gesture, null, null)
        Log.d(TAG, "Dispatched synthetic tap gesture at ($x, $y)")
    }
}
