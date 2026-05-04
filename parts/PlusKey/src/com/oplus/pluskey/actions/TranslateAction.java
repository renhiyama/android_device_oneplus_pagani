package com.oplus.pluskey.actions;

import android.content.Context;
import android.widget.Toast;

import com.oplus.pluskey.R;

/** TODO: tap into Live Translate / Google Translate floating mode. */
public class TranslateAction implements Action {
    @Override
    public void run(Context ctx) {
        Toast.makeText(ctx, R.string.feedback_todo, Toast.LENGTH_SHORT).show();
    }
}
