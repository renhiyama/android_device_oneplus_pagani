package com.oplus.pluskey;

import android.content.Context;
import android.provider.Settings.System;

/** Tiny wrapper around Settings.System for our prefs. */
public final class Settings {
    private Settings() {}

    /** @return the persisted action id, or {@link Constants#ACTION_UNSET} if
     *  the user has never picked one. The receiver uses the sentinel to know
     *  it should open the picker Activity instead of dispatching. */
    public static int getAction(Context ctx) {
        return System.getInt(ctx.getContentResolver(),
                Constants.KEY_PLUSKEY_ACTION, Constants.ACTION_UNSET);
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

    /** Package name of the user-picked "Open app" target, or null if unset. */
    public static String getOpenAppPkg(Context ctx) {
        return System.getString(ctx.getContentResolver(), Constants.KEY_PLUSKEY_OPEN_APP_PKG);
    }

    public static void setOpenAppPkg(Context ctx, String pkg) {
        System.putString(ctx.getContentResolver(), Constants.KEY_PLUSKEY_OPEN_APP_PKG, pkg);
    }
}
