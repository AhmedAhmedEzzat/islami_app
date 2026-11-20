package com.ahmedezzat.sakina

import android.hardware.GeomagneticField
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Android compasses report magnetic north. The Qibla bearing is measured from
 * true north, so the app adds the local magnetic declination, which Android
 * works out from the World Magnetic Model it ships with. Without it the arrow
 * is off by up to 20 degrees in some countries.
 */
class Compass : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "declination") {
            result.notImplemented()
            return
        }
        val lat = call.argument<Double>("latitude")
        val lng = call.argument<Double>("longitude")
        if (lat == null || lng == null) {
            result.error("args", "latitude and longitude are required", null)
            return
        }
        val field = GeomagneticField(
            lat.toFloat(),
            lng.toFloat(),
            0f,
            System.currentTimeMillis(),
        )
        result.success(field.declination.toDouble())
    }
}
