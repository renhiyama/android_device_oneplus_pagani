package com.oplus.pluskey;

import android.view.KeyEvent;

public final class Constants {
    private Constants() {}

    public static final String TAG = "PlusKey";

    /** The hardware key the OnePlus 13s "Plus Key" reports (BTN_TRIGGER_HAPPY32). */
    public static final int PLUS_KEY_KEYCODE = KeyEvent.KEYCODE_ASSIST;

    /** Long-press threshold. Below this is treated as a short-press (ignored). */
    public static final long LONG_PRESS_MS = 400L;

    // ===== action ids — persisted as int in Settings.System =====
    public static final int ACTION_NONE          = 0;
    public static final int ACTION_SOUND_VIB     = 1;
    public static final int ACTION_DND           = 2;
    public static final int ACTION_CAMERA        = 3;
    public static final int ACTION_FLASHLIGHT    = 4;
    public static final int ACTION_SCREENSHOT   = 5;
    public static final int ACTION_RECORDER      = 6;  // TODO
    public static final int ACTION_TRANSLATE     = 7;  // TODO

    public static final int DEFAULT_ACTION = ACTION_SOUND_VIB;

    // ===== Settings.System keys =====
    public static final String KEY_PLUSKEY_ACTION       = "pluskey_action";
    public static final String KEY_PLUSKEY_CAMERA_MODE  = "pluskey_camera_mode";

    // ===== camera mode IDs (passed to camera intent extras) =====
    public static final int CAM_MODE_PHOTO     = 0;
    public static final int CAM_MODE_VIDEO     = 1;
    public static final int CAM_MODE_SELFIE    = 2;
    public static final int CAM_MODE_PORTRAIT  = 3;
    public static final int CAM_MODE_MACRO     = 4;
    public static final int CAM_MODE_SLO_MO    = 5;
}
