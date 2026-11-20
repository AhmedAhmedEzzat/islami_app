package com.ahmedezzat.sakina

import android.content.Context
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Android compasses report magnetic north. The Qibla bearing is measured from
 * true north, so the app adds the local magnetic declination, which Android
 * works out from the World Magnetic Model it ships with. Without it the arrow
 * is off by up to 20 degrees in some countries.
 *
 * It also says whether the phone has a compass at all. Some budget phones
 * have no magnetometer, and on those the compass plugin still sends a heading
 * of 0 forever, so the dial would sit frozen pointing north.
 */
class Compass(private val context: Context) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "declination" -> declination(call, result)
            "hasCompass" -> {
                val sensors = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager?
                result.success(sensors?.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD) != null)
            }
            else -> result.notImplemented()
        }
    }

    private fun declination(call: MethodCall, result: MethodChannel.Result) {
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
