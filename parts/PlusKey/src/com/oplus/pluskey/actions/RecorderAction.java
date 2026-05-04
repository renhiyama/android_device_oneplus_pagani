package com.oplus.pluskey.actions;

import android.content.Context;
import android.widget.Toast;

import com.oplus.pluskey.R;

/** TODO: launch the system recorder app once we pick one (Sound Recorder vs OPlus). */
public class RecorderAction implements Action {
    @Override
    public void run(Context ctx) {
        Toast.makeText(ctx, R.string.feedback_todo, Toast.LENGTH_SHORT).show();
    }
}
