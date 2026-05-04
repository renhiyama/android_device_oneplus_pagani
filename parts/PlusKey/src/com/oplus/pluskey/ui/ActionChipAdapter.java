package com.oplus.pluskey.ui;

import android.content.Context;
import android.content.res.ColorStateList;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.oplus.pluskey.R;

/**
 * Horizontal RecyclerView adapter for the action chip row at the bottom of
 * the settings screen. Tapping a chip notifies the listener so the activity
 * can update the central pill + persist the new selection.
 */
public class ActionChipAdapter extends RecyclerView.Adapter<ActionChipAdapter.VH> {

    public interface OnSelected { void onSelected(int actionId, int positionInList); }

    private final Context mCtx;
    private final OnSelected mListener;
    private int mSelectedPos;

    public ActionChipAdapter(Context ctx, int initialActionId, OnSelected listener) {
        mCtx = ctx;
        mListener = listener;
        mSelectedPos = ActionRegistry.indexOf(initialActionId);
    }

    public void selectByPosition(int pos) {
        int prev = mSelectedPos;
        if (prev == pos) return;
        mSelectedPos = pos;
        notifyItemChanged(prev);
        notifyItemChanged(pos);
    }

    public int getSelectedPosition() { return mSelectedPos; }

    @NonNull
    @Override
    public VH onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View v = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.item_action_chip, parent, false);
        return new VH(v);
    }

    @Override
    public void onBindViewHolder(@NonNull VH h, int pos) {
        ActionRegistry.Item item = ActionRegistry.get(pos);
        h.icon.setImageResource(item.icon);

        boolean selected = pos == mSelectedPos;
        int accent = mCtx.getColor(item.color);
        // muted icon when not selected — when selected, full accent
        int tint = selected ? accent : 0xFF6B6B6B;
        h.icon.setImageTintList(ColorStateList.valueOf(tint));

        h.itemView.setAlpha(selected ? 1f : 0.65f);
        h.itemView.setOnClickListener(v -> {
            if (mSelectedPos == pos) return;
            int prev = mSelectedPos;
            mSelectedPos = pos;
            notifyItemChanged(prev);
            notifyItemChanged(pos);
            mListener.onSelected(item.id, pos);
        });
    }

    @Override
    public int getItemCount() { return ActionRegistry.ITEMS.size(); }

    static class VH extends RecyclerView.ViewHolder {
        final ImageView icon;
        VH(View v) { super(v); icon = v.findViewById(R.id.chip_icon); }
    }
}
