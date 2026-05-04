package com.oplus.pluskey.ui;

import android.animation.ArgbEvaluator;
import android.animation.ValueAnimator;
import android.content.Context;
import android.content.res.ColorStateList;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffXfermode;
import android.graphics.RectF;
import android.graphics.RenderEffect;
import android.graphics.Shader;
import android.os.Build;
import android.util.AttributeSet;
import android.view.View;

/**
 * The big animated oval shown in the centre of the Plus Key settings page.
 *
 * <p>Built from two rendered passes:
 * <ul>
 *   <li>A solid-color rounded-rect (pill) with a stroked border, sized to fit
 *       the view bounds with margins.</li>
 *   <li>A blurred copy of the same shape drawn behind it via
 *       {@link RenderEffect#createBlurEffect}, providing the soft halo.</li>
 * </ul>
 *
 * <p>Color is animated between accent values via {@link ArgbEvaluator}
 * whenever {@link #setAccent(int)} is called, with the entry-from-zero
 * variant scaling and fading in.
 */
public class GlowingPillView extends View {

    private static final float STROKE_DP = 14f;
    private static final float MARGIN_DP = 28f;
    private static final float BLUR_RADIUS_DP = 36f;

    private final Paint mStrokePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint mFillPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final RectF mRect = new RectF();

    private int mAccent = Color.RED;
    private int mDimSurface = 0xFF181818;
    private ValueAnimator mColorAnim;

    public GlowingPillView(Context c) { this(c, null); }
    public GlowingPillView(Context c, AttributeSet a) { this(c, a, 0); }
    public GlowingPillView(Context c, AttributeSet a, int s) {
        super(c, a, s);
        mStrokePaint.setStyle(Paint.Style.STROKE);
        mStrokePaint.setStrokeWidth(dp(STROKE_DP));
        mFillPaint.setStyle(Paint.Style.FILL);
        // We re-apply the blur in onSizeChanged so it uses the right pixel radius.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            setRenderEffect(RenderEffect.createBlurEffect(
                    dp(BLUR_RADIUS_DP), dp(BLUR_RADIUS_DP), Shader.TileMode.CLAMP));
        }
        // The blur applies to *us*, including stroke and fill — so we draw a
        // sharp inner pill on top via a sibling FrameLayout overlay (handled
        // in PlusKeyActivity). This view is the halo only.
    }

    public void setAccent(int color, boolean animate) {
        if (color == mAccent) return;
        if (mColorAnim != null) mColorAnim.cancel();
        if (!animate) {
            mAccent = color;
            invalidate();
            return;
        }
        mColorAnim = ValueAnimator.ofObject(new ArgbEvaluator(), mAccent, color);
        mColorAnim.setDuration(420);
        mColorAnim.addUpdateListener(a -> {
            mAccent = (int) a.getAnimatedValue();
            invalidate();
        });
        mColorAnim.start();
    }

    public int getAccent() { return mAccent; }

    public void setDimSurface(int color) { mDimSurface = color; }

    @Override
    protected void onDraw(Canvas canvas) {
        float m = dp(MARGIN_DP);
        mRect.set(m, m, getWidth() - m, getHeight() - m);
        float radius = mRect.width() / 2f;

        mFillPaint.setColor(mDimSurface);
        canvas.drawRoundRect(mRect, radius, radius, mFillPaint);

        mStrokePaint.setColor(mAccent);
        canvas.drawRoundRect(mRect, radius, radius, mStrokePaint);
    }

    private float dp(float v) { return v * getResources().getDisplayMetrics().density; }
}
