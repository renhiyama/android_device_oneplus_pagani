package com.oplus.pluskey;

import android.content.ContentResolver;
import android.content.Context;
import android.provider.Settings.System;

/** Tiny wrapper around Settings.System for our prefs. */
public final class Settings {
    private Settings() {}

    public static int getAction(Context ctx) {
        return System.getInt(ctx.getContentResolver(),
                Constants.KEY_PLUSKEY_ACTION, Constants.DEFAULT_ACTION);
    }

    public static void setAction(Context ctx, int action) {
        System.putInt(ctx.getContentResolver(), Constants.KEY_PLUSKEY_ACTION, action);
    }

    public static int getCameraMode(Context ctx) {
        return System.getInt(ctx.getContentResolver(),
                Constants.KEY_PLUSKEY_CAMERA_MODE, Constants.CAM_MODE_PHOTO);
    }

    public static void setCameraMode(Context ctx, int mode) {
        System.putInt(ctx.getContentResolver(), Constants.KEY_PLUSKEY_CAMERA_MODE, mode);
    }
}
