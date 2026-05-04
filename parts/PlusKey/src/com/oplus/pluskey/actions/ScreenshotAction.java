package com.oplus.pluskey.actions;

import android.app.StatusBarManager;
import android.content.Context;

public class ScreenshotAction implements Action {
    @Override
    public void run(Context ctx) {
        StatusBarManager sb = ctx.getSystemService(StatusBarManager.class);
        if (sb == null) return;
        sb.handleSystemKey(new android.view.KeyEvent(
                android.view.KeyEvent.ACTION_DOWN, android.view.KeyEvent.KEYCODE_SYSRQ));
        // SYSRQ on KEY_DOWN triggers SystemUI's screenshot path; haptic comes
        // from the SystemUI capture animation so we skip our own.
    }
}
