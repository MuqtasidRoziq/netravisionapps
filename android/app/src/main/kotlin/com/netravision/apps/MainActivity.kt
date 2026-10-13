package com.netravision.apps

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.ContactsContract
import android.util.Log
import android.view.accessibility.AccessibilityManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val TAG = "NetraVision"
    private val accessibilityChannelName = "com.netravision.apps/accessibility"
    private val whatsAppChannelName = "com.netravision.apps/whatsapp"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, accessibilityChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isTalkBackEnabled" -> {
                        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
                        result.success(am.isTouchExplorationEnabled)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, whatsAppChannelName)
            .setMethodCallHandler { call, result ->
                val phoneNumber = call.argument<String>("phoneNumber") ?: ""
                val contactName = call.argument<String>("contactName") ?: ""
                Log.d(TAG, "MethodChannel call: ${call.method}, phone: $phoneNumber, name: $contactName")
                when (call.method) {
                    "directVideoCall" -> {
                        val success = triggerWhatsAppCall(phoneNumber, contactName, isVideo = true)
                        result.success(success)
                    }
                    "directVoiceCall" -> {
                        val success = triggerWhatsAppCall(phoneNumber, contactName, isVideo = false)
                        result.success(success)
                    }
                    "armAutoClick" -> {
                        val action = call.argument<String>("action") ?: "video_call"
                        NetraAccessibilityService.arm(action)
                        result.success(true)
                    }
                    "isAccessibilityRunning" -> {
                        result.success(NetraAccessibilityService.isServiceRunning())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun triggerWhatsAppCall(phoneNumber: String, contactName: String, isVideo: Boolean): Boolean {
        Log.d(TAG, "triggerWhatsAppCall: phone=$phoneNumber, name=$contactName, isVideo=$isVideo")
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "READ_CONTACTS permission not granted, requesting...")
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.READ_CONTACTS), 101)
            return false
        }

        val mimeTypes = if (isVideo) {
            arrayOf(
                "vnd.android.cursor.item/vnd.com.whatsapp.video.call",
                "vnd.android.cursor.item/vnd.com.whatsapp.w4b.video.call"
            )
        } else {
            arrayOf(
                "vnd.android.cursor.item/vnd.com.whatsapp.voip.call",
                "vnd.android.cursor.item/vnd.com.whatsapp.w4b.voip.call"
            )
        }

        var clean = phoneNumber.replace(Regex("[^0-9]"), "")
        if (clean.startsWith("0")) {
            clean = "62" + clean.substring(1)
        }

        // Take last 8 digits for flexible matching
        val suffix = if (clean.length >= 8) clean.substring(clean.length - 8) else clean

        var dataId: Long? = null
        var matchedMimeType = mimeTypes[0]

        try {
            val cursor = contentResolver.query(
                ContactsContract.Data.CONTENT_URI,
                arrayOf(
                    ContactsContract.Data._ID,
                    ContactsContract.Data.DATA1,
                    ContactsContract.Data.DISPLAY_NAME,
                    ContactsContract.Data.MIMETYPE
                ),
                "${ContactsContract.Data.MIMETYPE} IN (?, ?)",
                mimeTypes,
                null
            )

            cursor?.use {
                while (it.moveToNext()) {
                    val id = it.getLong(it.getColumnIndexOrThrow(ContactsContract.Data._ID))
                    val data1 = it.getString(it.getColumnIndexOrThrow(ContactsContract.Data.DATA1)) ?: ""
                    val displayName = it.getString(it.getColumnIndexOrThrow(ContactsContract.Data.DISPLAY_NAME)) ?: ""
                    val mime = it.getString(it.getColumnIndexOrThrow(ContactsContract.Data.MIMETYPE)) ?: mimeTypes[0]

                    val cleanData1 = data1.replace(Regex("[^0-9]"), "")
                    val isNumberMatch = (suffix.isNotEmpty() && cleanData1.contains(suffix)) ||
                            (clean.isNotEmpty() && cleanData1.contains(clean))
                    val isNameMatch = contactName.isNotEmpty() &&
                            displayName.contains(contactName, ignoreCase = true)

                    if (isNumberMatch || isNameMatch) {
                        dataId = id
                        matchedMimeType = mime
                        Log.d(TAG, "MATCH FOUND! id=$id, data1=$data1, name=$displayName, mime=$mime")
                        break
                    }
                }
            }

            if (dataId != null) {
                val pm = packageManager
                val isStandardInstalled = try {
                    pm.getPackageInfo("com.whatsapp", 0)
                    true
                } catch (e: Exception) {
                    false
                }
                val pkg = if (matchedMimeType.contains(".w4b.")) {
                    "com.whatsapp.w4b"
                } else if (isStandardInstalled) {
                    "com.whatsapp"
                } else {
                    "com.whatsapp.w4b"
                }

                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(
                        Uri.parse("content://com.android.contacts/data/$dataId"),
                        matchedMimeType
                    )
                    setPackage(pkg)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                Log.d(TAG, "Launching WhatsApp Direct Call intent for dataId=$dataId, pkg=$pkg")
                startActivity(intent)
                return true
            } else {
                Log.w(TAG, "No matching contact found in ContactsContract for phone=$clean, suffix=$suffix, name=$contactName")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception in triggerWhatsAppCall", e)
        }
        return false
    }
}
