package com.oplus.pluskey.actions;

import android.app.NotificationManager;
import android.content.Context;
import android.media.AudioManager;
import android.widget.Toast;

import com.oplus.pluskey.R;

/**
 * Cycles RING → VIBRATE → SILENT → RING. Haptic payload encodes which mode
 * we just entered:
 *   • silent → 1 short tick
 *   • vibrate → 2 short ticks
 *   • ring → strong heavy buzz
 */
public class SoundVibrationAction implements Action {
    @Override
    public void run(Context ctx) {
        AudioManager am = ctx.getSystemService(AudioManager.class);
        NotificationManager nm = ctx.getSystemService(NotificationManager.class);
        if (am == null) return;

        int next;
        int toast;
        switch (am.getRingerMode()) {
            case AudioManager.RINGER_MODE_NORMAL:
                next  = AudioManager.RINGER_MODE_VIBRATE;
                toast = R.string.feedback_vibrate;
                break;
            case AudioManager.RINGER_MODE_VIBRATE:
                next  = AudioManager.RINGER_MODE_SILENT;
                toast = R.string.feedback_silent;
                break;
            case AudioManager.RINGER_MODE_SILENT:
            default:
                next  = AudioManager.RINGER_MODE_NORMAL;
                toast = R.string.feedback_ring;
                break;
        }

        // Setting SILENT requires DND policy access on Android Q+
        if (next == AudioManager.RINGER_MODE_SILENT
                && nm != null && !nm.isNotificationPolicyAccessGranted()) {
            // fall back to vibrate if we somehow lost DND access
            next = AudioManager.RINGER_MODE_VIBRATE;
            toast = R.string.feedback_vibrate;
        }
        am.setRingerMode(next);

        switch (next) {
            case AudioManager.RINGER_MODE_SILENT:  Haptics.tickOnce(ctx); break;
            case AudioManager.RINGER_MODE_VIBRATE: Haptics.tickTwice(ctx); break;
            case AudioManager.RINGER_MODE_NORMAL:  Haptics.heavy(ctx); break;
        }
        Toast.makeText(ctx, toast, Toast.LENGTH_SHORT).show();
    }
}
