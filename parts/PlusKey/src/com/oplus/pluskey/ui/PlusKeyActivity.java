package com.oplus.pluskey.ui;

import android.animation.ArgbEvaluator;
import android.animation.ObjectAnimator;
import android.animation.ValueAnimator;
import android.app.Activity;
import android.content.Intent;
import android.content.res.ColorStateList;
import android.graphics.PorterDuff;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.view.View;
import android.view.animation.AnimationUtils;
import android.view.animation.DecelerateInterpolator;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.ImageView;
import android.widget.Spinner;
import android.widget.TextView;

import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import androidx.recyclerview.widget.RecyclerView.SmoothScroller;
import androidx.recyclerview.widget.LinearSmoothScroller;

import com.google.android.material.appbar.MaterialToolbar;
import com.oplus.pluskey.Constants;
import com.oplus.pluskey.R;
import com.oplus.pluskey.Settings;
import com.oplus.pluskey.service.AssistantRoleClearer;

/**
 * Plus Key settings — the slick page from pluskey.webp.
 *
 * <p>State flow:
 * <ol>
 *   <li>onCreate inflates the layout, populates the chip row, paints the
 *       initial action onto the central pill.</li>
 *   <li>Tapping a chip invokes {@link #applyAction} which animates the pill
 *       color, swaps icon + label + description, and persists the new
 *       selection to Settings.System.</li>
 *   <li>Selecting Camera reveals an inline mode-picker spinner; everything
 *       else hides it.</li>
 * </ol>
 */
public class PlusKeyActivity extends Activity {

    private GlowingPillView mHalo;
    private View mSharpPill;
    private ImageView mActionIcon;
    private TextView mActionLabel, mActionDesc;
    private Spinner mCameraPicker;
    private RecyclerView mChipRow;
    private ActionChipAdapter mAdapter;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_pluskey);

        // Make sure the handler service is up.
        // Belt-and-suspenders: clear the assistant role on first launch so any
        // search-button preference UI tied to it goes inert. Patched PWM also
        // suppresses ASSIST short-press, so even if the role re-attaches via
        // fallback, Gemini won't launch on plus-key tap.
        AssistantRoleClearer.clearOnce(this);

        MaterialToolbar tb = findViewById(R.id.toolbar);
        tb.setNavigationOnClickListener(v -> finish());

        mHalo = findViewById(R.id.pill_halo);
        mSharpPill = findViewById(R.id.pill_sharp);
        mActionIcon = findViewById(R.id.action_icon);
        mActionLabel = findViewById(R.id.action_label);
        mActionDesc = findViewById(R.id.action_desc);
        mCameraPicker = findViewById(R.id.camera_mode_picker);
        mChipRow = findViewById(R.id.action_chips);

        setupCameraPicker();
        setupChipRow();
        applyAction(Settings.getAction(this), false);
        animateEntry();
    }

    private void setupCameraPicker() {
        ArrayAdapter<CharSequence> a = ArrayAdapter.createFromResource(
                this, R.array.camera_modes,
                android.R.layout.simple_spinner_item);
        a.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        mCameraPicker.setAdapter(a);
        mCameraPicker.setSelection(Settings.getCameraMode(this));
        mCameraPicker.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override public void onItemSelected(AdapterView<?> p, View v, int pos, long id) {
                Settings.setCameraMode(PlusKeyActivity.this, pos);
            }
            @Override public void onNothingSelected(AdapterView<?> p) {}
        });
    }

    private void setupChipRow() {
        mAdapter = new ActionChipAdapter(this, Settings.getAction(this), (actionId, pos) -> {
            applyAction(actionId, true);
            // smooth-scroll to keep the selected chip centred
            SmoothScroller s = new LinearSmoothScroller(this) {
                @Override protected int getHorizontalSnapPreference() { return SNAP_TO_ANY; }
            };
            s.setTargetPosition(pos);
            mChipRow.getLayoutManager().startSmoothScroll(s);
        });
        mChipRow.setLayoutManager(
                new LinearLayoutManager(this, RecyclerView.HORIZONTAL, false));
        mChipRow.setAdapter(mAdapter);
    }

    private void applyAction(int actionId, boolean animate) {
        ActionRegistry.Item item = ActionRegistry.get(ActionRegistry.indexOf(actionId));
        Settings.setAction(this, actionId);

        int accent = getColor(item.color);

        // halo color crossfade
        mHalo.setAccent(accent, animate);
        // sharp inner pill stroke also takes the accent (slightly muted so
        // the halo glow stays visually dominant)
        if (mSharpPill.getBackground() instanceof GradientDrawable g) {
            g.mutate();
            g.setStroke((int) (2 * getResources().getDisplayMetrics().density),
                    blend(accent, 0xFF000000, 0.55f));
        }

        mActionIcon.setImageResource(item.icon);
        mActionIcon.setImageTintList(ColorStateList.valueOf(accent));

        if (animate) {
            mActionIcon.animate().cancel();
            mActionIcon.setAlpha(0f);
            mActionIcon.setScaleX(0.6f);
            mActionIcon.setScaleY(0.6f);
            mActionIcon.animate().alpha(1f).scaleX(1f).scaleY(1f)
                    .setDuration(360)
                    .setInterpolator(new DecelerateInterpolator(1.6f))
                    .start();
        }

        mActionLabel.setText(item.label);
        mActionDesc.setText(item.desc);
        mCameraPicker.setVisibility(
                actionId == Constants.ACTION_CAMERA ? View.VISIBLE : View.GONE);
    }

    private void animateEntry() {
        // Pill scales up, action icon already animated by applyAction.
        mHalo.setScaleX(0.9f); mHalo.setScaleY(0.9f); mHalo.setAlpha(0f);
        mHalo.animate().scaleX(1f).scaleY(1f).alpha(1f)
                .setDuration(560).setInterpolator(new DecelerateInterpolator(1.6f))
                .start();
        mSharpPill.setAlpha(0f);
        mSharpPill.animate().alpha(1f).setStartDelay(220).setDuration(360).start();

        // Chip row slides up from below.
        mChipRow.setTranslationY(120f);
        mChipRow.setAlpha(0f);
        mChipRow.animate().translationY(0).alpha(1f)
                .setStartDelay(140).setDuration(420)
                .setInterpolator(new DecelerateInterpolator(1.4f))
                .start();
    }

    /** lerp two argb colors with ratio in [0,1] (1 = pure b). */
    private static int blend(int a, int b, float ratio) {
        Object o = new ArgbEvaluator().evaluate(ratio, a, b);
        return (int) o;
    }
}
