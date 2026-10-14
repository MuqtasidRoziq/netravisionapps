package com.netravision.apps

import android.accessibilityservice.AccessibilityService
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class NetraAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "NetraA11y"
        var instance: NetraAccessibilityService? = null
            private set

        @Volatile
        var pendingAction: String? = null // "video_call" or "send_chat"
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
        if (pkg != "com.whatsapp" && pkg != "com.whatsapp.w4b") return

        val root = rootInActiveWindow ?: return

        when (action) {
            "video_call" -> {
                val targetLabels = listOf(
                    "telepon video",
                    "panggilan video",
                    "video call",
                    "video_call",
                    "videocall"
                )
                if (searchAndClick(root, targetLabels)) {
                    Log.d(TAG, "Successfully triggered Video Call click! Watching for call screen or dialog...")
                    pendingAction = "confirm_call"
                    armTime = System.currentTimeMillis()
                }
            }
            "voice_call" -> {
                val targetLabels = listOf(
                    "telepon suara",
                    "panggilan suara",
                    "voice call",
                    "voice_call",
                    "audio call"
                )
                if (searchAndClick(root, targetLabels)) {
                    Log.d(TAG, "Successfully triggered Voice Call click! Watching for call screen or dialog...")
                    pendingAction = "confirm_call"
                    armTime = System.currentTimeMillis()
                }
            }
            "confirm_call" -> {
                // If call screen is already active or ringing, we are done
                val callKeywords = listOf("call_screen", "call_grid", "tidak dijawab", "memanggil", "berdering", "calling", "ringing", "selesai")
                if (containsAny(root, callKeywords)) {
                    Log.d(TAG, "Call is active! Disarming.")
                    disarm()
                    return
                }
                // Confirmation dialog button (e.g. "Panggil", "Call", "Mulai Panggilan")
                val confirmLabels = listOf("panggil", "call", "mulai panggilan")
                if (searchAndClick(root, confirmLabels)) {
                    Log.d(TAG, "Confirmed call dialog!")
                    disarm()
                } else if (System.currentTimeMillis() - armTime > 3500L) {
                    disarm()
                }
            }
            "send_chat" -> {
                val targetLabels = listOf("kirim", "send")
                if (searchAndClick(root, targetLabels)) {
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

    private fun searchAndClick(node: AccessibilityNodeInfo, labels: List<String>): Boolean {
        val desc = node.contentDescription?.toString()?.lowercase() ?: ""
        val text = node.text?.toString()?.lowercase() ?: ""

        // Cocok persis agar kata umum seperti "call" atau "send" pada isi
        // chat tidak pernah diperlakukan sebagai tombol. Hanya satu aksi klik
        // yang dikirim, tanpa gesture sintetis dan tanpa klik parent kedua kali.
        if (labels.any { it == desc || it == text }) {
            var clickable: AccessibilityNodeInfo? = node
            while (clickable != null && !clickable.isClickable) {
                clickable = clickable.parent
            }
            if (clickable != null) {
                Log.d(TAG, "Clicking confirmed WhatsApp control: desc='$desc', text='$text'")
                return clickable.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            if (searchAndClick(child, labels)) {
                return true
            }
        }

        return false
    }

}
