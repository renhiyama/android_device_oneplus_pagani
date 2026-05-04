package com.oplus.pluskey.service;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

import com.oplus.pluskey.Constants;
import com.oplus.pluskey.Settings;
import com.oplus.pluskey.actions.ActionDispatcher;

/**
 * Receives the {@code com.oplus.pluskey.LONG_PRESS} broadcast that the
 * patched PhoneWindowManager (frameworks/base patches/0010) emits when the
 * Plus Key is held past the long-press threshold. Short presses never
 * reach us — PWM drops them at source. That's the user's "no single click
 * allowed" rule, enforced at the framework level so accidental taps can't
 * leak through.
 */
public class PlusKeyReceiver extends BroadcastReceiver {

    public static final String ACTION_LONG_PRESS = "com.oplus.pluskey.LONG_PRESS";

    @Override
    public void onReceive(Context ctx, Intent intent) {
        if (!ACTION_LONG_PRESS.equals(intent.getAction())) return;
        int actionId = Settings.getAction(ctx);
        Log.i(Constants.TAG, "long-press → action=" + actionId);

        // First-run: user has never picked an action. Open the picker
        // instead of silently doing nothing — this is the only place the
        // first long-press is observable, so it's the right moment to
        // walk them into the Settings UI.
        if (actionId == Constants.ACTION_UNSET) {
            Intent settings = new Intent("com.oplus.pluskey.SETTINGS")
                    .setPackage(ctx.getPackageName())
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            ctx.startActivity(settings);
            return;
        }

        new ActionDispatcher(ctx).dispatch(actionId);
    }
}
