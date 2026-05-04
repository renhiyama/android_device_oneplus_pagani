package com.oplus.pluskey.ui;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.graphics.drawable.Drawable;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.google.android.material.appbar.MaterialToolbar;
import com.oplus.pluskey.R;
import com.oplus.pluskey.Settings;

import java.text.Collator;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Lists every launcher-visible app sorted by display name. Tapping a row
 * persists the package to {@link Settings#setOpenAppPkg} and finishes —
 * the Plus Key activity then re-renders the description with the chosen
 * app's name and the user can hit "Set" to commit the action choice.
 */
public class AppPickerActivity extends Activity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_app_picker);

        MaterialToolbar tb = findViewById(R.id.toolbar);
        tb.setNavigationOnClickListener(v -> finish());

        RecyclerView rv = findViewById(R.id.app_list);
        rv.setLayoutManager(new LinearLayoutManager(this));
        rv.setAdapter(new AppAdapter(loadApps()));
    }

    private List<AppEntry> loadApps() {
        Intent main = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER);
        List<ResolveInfo> ris = getPackageManager()
                .queryIntentActivities(main, PackageManager.MATCH_ALL);
        List<AppEntry> out = new ArrayList<>(ris.size());
        for (ResolveInfo ri : ris) {
            String pkg = ri.activityInfo.packageName;
            if (getPackageName().equals(pkg)) continue;
            String label = ri.loadLabel(getPackageManager()).toString();
            Drawable icon = ri.loadIcon(getPackageManager());
            out.add(new AppEntry(pkg, label, icon));
        }
        Collator coll = Collator.getInstance();
        Collections.sort(out, (a, b) -> coll.compare(a.label, b.label));
        return out;
    }

    private static class AppEntry {
        final String pkg, label;
        final Drawable icon;
        AppEntry(String pkg, String label, Drawable icon) {
            this.pkg = pkg; this.label = label; this.icon = icon;
        }
    }

    private class AppAdapter extends RecyclerView.Adapter<AppAdapter.VH> {
        private final List<AppEntry> mItems;
        AppAdapter(List<AppEntry> items) { mItems = items; }

        @NonNull @Override
        public VH onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
            View v = LayoutInflater.from(parent.getContext())
                    .inflate(R.layout.item_app_picker, parent, false);
            return new VH(v);
        }

        @Override
        public void onBindViewHolder(@NonNull VH h, int pos) {
            AppEntry e = mItems.get(pos);
            h.icon.setImageDrawable(e.icon);
            h.label.setText(e.label);
            h.itemView.setOnClickListener(v -> {
                Settings.setOpenAppPkg(AppPickerActivity.this, e.pkg);
                finish();
            });
        }

        @Override public int getItemCount() { return mItems.size(); }

        class VH extends RecyclerView.ViewHolder {
            final ImageView icon;
            final TextView label;
            VH(View v) {
                super(v);
                icon = v.findViewById(android.R.id.icon);
                label = v.findViewById(android.R.id.text1);
            }
        }
    }
}
