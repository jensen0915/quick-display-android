package com.jensen.ShowLastImage;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.Context;
import android.content.ContextWrapper;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.ImageDecoder;
import android.graphics.Matrix;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;
import android.view.WindowManager;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.view.View;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.ContextCompat;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class MainActivity extends AppCompatActivity {

    private static final String TAG = "MainActivity";
    private static final String IMAGE_DIR = "imageDir";
    private static final String PREFS_NAME = "display_prefs";
    private static final String PREF_LAST_SLOT = "last_slot";
    private static final String PREF_DARK_BACKGROUND = "dark_background";
    private static final String PREF_SLOT_FORMAT_PREFIX = "slot_format_";
    private static final int MAX_IMAGE_DIMENSION = 1200;

    private static final int SLOT_BARCODE = 0;
    private static final int SLOT_QRCODE = 1;
    private static final int SLOT_PHOTO = 2;
    private static final String FORMAT_JPEG = "jpeg";
    private static final String FORMAT_PNG = "png";
    private static final String FORMAT_WEBP = "webp";

    private ImageButton BSlotBarcode;
    private ImageButton BSlotQrCode;
    private ImageButton BSlotPhoto;
    private ImageButton BToggleBackground;
    private ImageButton BSelectImage;
    private ImageButton BRemoveImage;
    private ImageButton BRotateImage;
    private ImageView IVPreviewImage;
    private View rootLayout;

    private Bitmap currentBitmap;
    private int currentSlot = SLOT_BARCODE;
    private boolean isDarkBackground;
    private SharedPreferences preferences;
    private final ExecutorService imageExecutor = Executors.newSingleThreadExecutor();

    private final ActivityResultLauncher<Intent> launchSomeActivity =
            registerForActivityResult(
                    new ActivityResultContracts.StartActivityForResult(),
                    result -> {
                        if (result.getResultCode() != Activity.RESULT_OK) {
                            return;
                        }

                        Intent data = result.getData();
                        if (data == null || data.getData() == null) {
                            return;
                        }

                        Uri selectedImageUri = data.getData();
                        int selectedSlot = currentSlot;

                        imageExecutor.execute(() -> importImageForSlot(selectedImageUri, selectedSlot));
                    });

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        BSlotBarcode = findViewById(R.id.BSlotBarcode);
        BSlotQrCode = findViewById(R.id.BSlotQrCode);
        BSlotPhoto = findViewById(R.id.BSlotPhoto);
        BToggleBackground = findViewById(R.id.BToggleBackground);
        BSelectImage = findViewById(R.id.BSelectImage);
        BRemoveImage = findViewById(R.id.BRemoveImage);
        BRotateImage = findViewById(R.id.BRotateImage);
        IVPreviewImage = findViewById(R.id.IVPreviewImage);
        rootLayout = findViewById(R.id.rootLayout);

        preferences = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        currentSlot = preferences.getInt(PREF_LAST_SLOT, SLOT_BARCODE);
        isDarkBackground = preferences.getBoolean(PREF_DARK_BACKGROUND, false);

        WindowManager.LayoutParams lp = getWindow().getAttributes();
        lp.screenBrightness = 1.0f;
        getWindow().setAttributes(lp);

        BSlotBarcode.setOnClickListener(v -> switchToSlot(SLOT_BARCODE));
        BSlotQrCode.setOnClickListener(v -> switchToSlot(SLOT_QRCODE));
        BSlotPhoto.setOnClickListener(v -> switchToSlot(SLOT_PHOTO));
        BToggleBackground.setOnClickListener(v -> toggleBackgroundMode());

        BSelectImage.setOnClickListener(v -> imageChooser());
        BRemoveImage.setOnClickListener(v -> removeCurrentSlotImage());
        BRotateImage.setOnClickListener(v -> {
            if (currentBitmap == null) {
                return;
            }

            currentBitmap = rotateBitmap(currentBitmap, 90);
            IVPreviewImage.setImageBitmap(currentBitmap);
            saveBitmapForCurrentSlot(currentBitmap);
        });

        applyBackgroundMode();
        switchToSlot(currentSlot);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        imageExecutor.shutdown();
    }

    private void switchToSlot(int slot) {
        currentSlot = slot;
        preferences.edit().putInt(PREF_LAST_SLOT, currentSlot).apply();
        updateSlotUi();
        loadBitmapForCurrentSlot();
    }

    private void updateSlotUi() {
        updateSlotButtonState(BSlotBarcode, currentSlot == SLOT_BARCODE);
        updateSlotButtonState(BSlotQrCode, currentSlot == SLOT_QRCODE);
        updateSlotButtonState(BSlotPhoto, currentSlot == SLOT_PHOTO);
    }

    private void saveBitmapForCurrentSlot(Bitmap bitmapImage) {
        saveBitmapForSlot(bitmapImage, currentSlot, getSlotImageFormat(currentSlot));
    }

    private void saveBitmapForSlot(Bitmap bitmapImage, int slot, String format) {
        ContextWrapper cw = new ContextWrapper(getApplicationContext());
        File directory = cw.getDir(IMAGE_DIR, Context.MODE_PRIVATE);
        deleteSlotFiles(directory, slot);

        File imagePath = new File(directory, getImageFileName(slot, format));
        Bitmap.CompressFormat compressFormat = getCompressFormat(format);
        int quality = FORMAT_JPEG.equals(format) || FORMAT_WEBP.equals(format) ? 92 : 100;

        try (FileOutputStream fos = new FileOutputStream(imagePath)) {
            bitmapImage.compress(compressFormat, quality, fos);
            Log.d(TAG, "Saved image to " + imagePath);
        } catch (IOException e) {
            Log.e(TAG, "Error while saving image", e);
        }
    }

    private void loadBitmapForCurrentSlot() {
        ContextWrapper cw = new ContextWrapper(getApplicationContext());
        File directory = cw.getDir(IMAGE_DIR, Context.MODE_PRIVATE);
        File imageFile = new File(directory, getImageFileName(currentSlot, getSlotImageFormat(currentSlot)));

        try (FileInputStream inputStream = new FileInputStream(imageFile)) {
            currentBitmap = BitmapFactory.decodeStream(inputStream);
            IVPreviewImage.setImageBitmap(currentBitmap);
        } catch (FileNotFoundException e) {
            currentBitmap = null;
            IVPreviewImage.setImageDrawable(null);
            Log.d(TAG, "No saved image found for slot " + currentSlot);
        } catch (IOException e) {
            currentBitmap = null;
            IVPreviewImage.setImageDrawable(null);
            Log.e(TAG, "Error while loading image", e);
        }
    }

    private void imageChooser() {
        Intent intent = new Intent();
        intent.setType("image/*");
        intent.setAction(Intent.ACTION_GET_CONTENT);
        launchSomeActivity.launch(intent);
    }

    private void importImageForSlot(Uri selectedImageUri, int slot) {
        try {
            ImageDecoder.Source source =
                    ImageDecoder.createSource(getContentResolver(), selectedImageUri);
            Bitmap selectedImageBitmap = decodeScaledBitmap(source);
            String sourceFormat = detectImageFormat(selectedImageUri);
            setSlotImageFormat(slot, sourceFormat);
            saveBitmapForSlot(selectedImageBitmap, slot, sourceFormat);

            runOnUiThread(() -> {
                if (isFinishing() || isDestroyed() || currentSlot != slot) {
                    return;
                }

                currentBitmap = selectedImageBitmap;
                IVPreviewImage.setImageBitmap(currentBitmap);
            });
        } catch (IOException e) {
            Log.e(TAG, "Error decoding image", e);
        }
    }

    private void removeCurrentSlotImage() {
        currentBitmap = null;
        IVPreviewImage.setImageDrawable(null);

        ContextWrapper cw = new ContextWrapper(getApplicationContext());
        File directory = cw.getDir(IMAGE_DIR, Context.MODE_PRIVATE);

        try {
            boolean deleted = deleteSlotFiles(directory, currentSlot);
            Log.d(TAG, "deleted = " + deleted + ", slot = " + currentSlot);
        } catch (Exception e) {
            Log.e(TAG, "Error while removing img", e);
        }
    }

    private void toggleBackgroundMode() {
        isDarkBackground = !isDarkBackground;
        preferences.edit().putBoolean(PREF_DARK_BACKGROUND, isDarkBackground).apply();
        applyBackgroundMode();
    }

    private void updateSlotButtonState(ImageButton button, boolean isActive) {
        button.setSelected(isActive);
        button.setAlpha(isActive ? 1.0f : 0.72f);
        button.setBackgroundTintList(ContextCompat.getColorStateList(
                this,
                isActive ? R.color.slot_button_active_background : R.color.slot_button_background
        ));
        button.setImageTintList(ContextCompat.getColorStateList(
                this,
                isActive ? R.color.slot_button_active_icon : R.color.slot_button_icon
        ));
    }

    private void applyBackgroundMode() {
        int rootBackgroundColor = ContextCompat.getColor(
                this,
                isDarkBackground ? R.color.screen_background_dark : R.color.screen_background_light
        );
        int previewBackgroundColor = ContextCompat.getColor(
                this,
                isDarkBackground ? R.color.preview_background_dark : R.color.preview_background_light
        );

        rootLayout.setBackgroundColor(rootBackgroundColor);
        IVPreviewImage.setBackgroundColor(previewBackgroundColor);

        BToggleBackground.setImageResource(
                isDarkBackground ? R.drawable.ic_background_light : R.drawable.ic_background_dark
        );
        BToggleBackground.setContentDescription(
                getString(isDarkBackground ? R.string.light_background : R.string.dark_background)
        );
    }

    private Bitmap decodeScaledBitmap(ImageDecoder.Source source) throws IOException {
        return ImageDecoder.decodeBitmap(source, (decoder, info, src) -> {
            int width = info.getSize().getWidth();
            int height = info.getSize().getHeight();
            int largestDimension = Math.max(width, height);

            if (largestDimension > MAX_IMAGE_DIMENSION) {
                float scale = (float) MAX_IMAGE_DIMENSION / largestDimension;
                int targetWidth = Math.max(1, Math.round(width * scale));
                int targetHeight = Math.max(1, Math.round(height * scale));
                decoder.setTargetSize(targetWidth, targetHeight);
            }

            decoder.setAllocator(ImageDecoder.ALLOCATOR_SOFTWARE);
        });
    }

    private String getImageFileName(int slot, String format) {
        return getSlotBaseName(slot) + "." + getExtensionForFormat(format);
    }

    private String getSlotBaseName(int slot) {
        switch (slot) {
            case SLOT_BARCODE:
                return "slot_barcode";
            case SLOT_QRCODE:
                return "slot_qrcode";
            case SLOT_PHOTO:
                return "slot_photo";
            default:
                return "slot_barcode";
        }
    }

    private String getSlotImageFormat(int slot) {
        return preferences.getString(PREF_SLOT_FORMAT_PREFIX + slot, FORMAT_PNG);
    }

    private void setSlotImageFormat(int slot, String format) {
        preferences.edit().putString(PREF_SLOT_FORMAT_PREFIX + slot, format).apply();
    }

    private String detectImageFormat(Uri uri) {
        ContentResolver resolver = getContentResolver();
        String mimeType = resolver.getType(uri);

        if ("image/jpeg".equalsIgnoreCase(mimeType) || "image/jpg".equalsIgnoreCase(mimeType)) {
            return FORMAT_JPEG;
        }
        if ("image/webp".equalsIgnoreCase(mimeType)) {
            return FORMAT_WEBP;
        }
        return FORMAT_PNG;
    }

    private Bitmap.CompressFormat getCompressFormat(String format) {
        if (FORMAT_JPEG.equals(format)) {
            return Bitmap.CompressFormat.JPEG;
        }
        if (FORMAT_WEBP.equals(format)) {
            return Bitmap.CompressFormat.WEBP_LOSSY;
        }
        return Bitmap.CompressFormat.PNG;
    }

    private String getExtensionForFormat(String format) {
        if (FORMAT_JPEG.equals(format)) {
            return "jpg";
        }
        if (FORMAT_WEBP.equals(format)) {
            return "webp";
        }
        return "png";
    }

    private boolean deleteSlotFiles(File directory, int slot) {
        boolean deletedAny = false;
        String baseName = getSlotBaseName(slot);
        String[] extensions = {"jpg", "png", "webp"};

        for (String extension : extensions) {
            File imageFile = new File(directory, baseName + "." + extension);
            if (imageFile.exists() && imageFile.delete()) {
                deletedAny = true;
            }
        }

        return deletedAny;
    }

    private Bitmap rotateBitmap(Bitmap source, float angle) {
        Matrix matrix = new Matrix();
        matrix.postRotate(angle);
        return Bitmap.createBitmap(
                source, 0, 0, source.getWidth(), source.getHeight(), matrix, true
        );
    }
}
