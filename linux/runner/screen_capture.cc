#include "screen_capture.h"

#include <flutter_linux/flutter_linux.h>
#include <X11/Xlib.h>
#include <X11/extensions/Xrandr.h>

#include <cstdlib>
#include <cstring>

#define SCREENSHOT_CHANNEL "com.clawrelay/screenshot"

// Keep the channel alive for the lifetime of the application.
static FlMethodChannel* g_screenshot_channel = nullptr;

// ---------------------------------------------------------------------------
// Capture the monitor that currently contains the mouse cursor.
// Returns a map with keys: "width" (int), "height" (int), "pixels" (uint8[]).
// Pixels are RGBA, 4 bytes per pixel, row-major, top-to-bottom.
// ---------------------------------------------------------------------------
static void handle_capture_screen(FlMethodCall* method_call) {
  Display* display = XOpenDisplay(nullptr);
  if (!display) {
    fl_method_call_respond_error(method_call, "NO_DISPLAY",
                                 "Cannot open X display", nullptr, nullptr);
    return;
  }

  Window root = DefaultRootWindow(display);

  // ── Find where the mouse cursor is ───────────────────────────────────────
  Window root_ret, child_ret;
  int cursor_x = 0, cursor_y = 0, win_x = 0, win_y = 0;
  unsigned int mask = 0;
  XQueryPointer(display, root, &root_ret, &child_ret,
                &cursor_x, &cursor_y, &win_x, &win_y, &mask);

  // ── Find the monitor that contains the cursor (XRandR) ───────────────────
  int cap_x = 0, cap_y = 0, cap_w = 0, cap_h = 0;
  int num_monitors = 0;
  XRRMonitorInfo* monitors =
      XRRGetMonitors(display, root, True, &num_monitors);

  if (monitors && num_monitors > 0) {
    for (int i = 0; i < num_monitors; i++) {
      int mx = monitors[i].x, my = monitors[i].y;
      int mw = monitors[i].width, mh = monitors[i].height;
      if (cursor_x >= mx && cursor_x < mx + mw &&
          cursor_y >= my && cursor_y < my + mh) {
        cap_x = mx;
        cap_y = my;
        cap_w = mw;
        cap_h = mh;
        break;
      }
    }
    // Cursor not on any monitor? Use the first one.
    if (cap_w == 0) {
      cap_x = monitors[0].x;
      cap_y = monitors[0].y;
      cap_w = monitors[0].width;
      cap_h = monitors[0].height;
    }
    XRRFreeMonitors(monitors);
  }

  // Fallback: root window size (no XRandR or no monitors found).
  if (cap_w == 0) {
    XWindowAttributes attr;
    XGetWindowAttributes(display, root, &attr);
    cap_w = attr.width;
    cap_h = attr.height;
  }

  // ── Capture pixels ────────────────────────────────────────────────────────
  XImage* image = XGetImage(display, root,
                             cap_x, cap_y, cap_w, cap_h,
                             AllPlanes, ZPixmap);
  XCloseDisplay(display);

  if (!image) {
    fl_method_call_respond_error(method_call, "CAPTURE_FAILED",
                                 "XGetImage returned null", nullptr, nullptr);
    return;
  }

  // ── Convert BGRA (X11 little-endian) → RGBA ───────────────────────────────
  const int num_pixels = cap_w * cap_h;
  uint8_t* rgba = static_cast<uint8_t*>(malloc(num_pixels * 4));
  if (!rgba) {
    XDestroyImage(image);
    fl_method_call_respond_error(method_call, "OOM", "malloc failed",
                                 nullptr, nullptr);
    return;
  }

  const uint32_t* src = reinterpret_cast<const uint32_t*>(image->data);
  for (int i = 0; i < num_pixels; i++) {
    const uint32_t p = src[i];
    rgba[i * 4 + 0] = (p >> 16) & 0xFF;  // R
    rgba[i * 4 + 1] = (p >>  8) & 0xFF;  // G
    rgba[i * 4 + 2] = (p >>  0) & 0xFF;  // B
    rgba[i * 4 + 3] = 0xFF;              // A (fully opaque)
  }
  XDestroyImage(image);

  // ── Build result map ──────────────────────────────────────────────────────
  g_autoptr(FlValue) result = fl_value_new_map();
  fl_value_set_string_take(result, "width",  fl_value_new_int(cap_w));
  fl_value_set_string_take(result, "height", fl_value_new_int(cap_h));
  // fl_value_new_uint8_list copies the buffer, so we can free ours.
  fl_value_set_string_take(result, "pixels",
                            fl_value_new_uint8_list(rgba, num_pixels * 4));
  free(rgba);

  fl_method_call_respond_success(method_call, result, nullptr);
}

// ---------------------------------------------------------------------------
// Method channel dispatch
// ---------------------------------------------------------------------------
static void method_call_cb(FlMethodChannel* /*channel*/,
                            FlMethodCall* method_call,
                            gpointer /*user_data*/) {
  const gchar* method = fl_method_call_get_name(method_call);
  if (strcmp(method, "captureScreen") == 0) {
    handle_capture_screen(method_call);
  } else {
    fl_method_call_respond_not_implemented(method_call, nullptr);
  }
}

// ---------------------------------------------------------------------------
// Registration
// ---------------------------------------------------------------------------
void screenshot_plugin_register(FlView* view) {
  FlBinaryMessenger* messenger =
      fl_engine_get_binary_messenger(fl_view_get_engine(view));
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();

  // Store in global to keep the channel alive for the app lifetime.
  g_screenshot_channel = fl_method_channel_new(
      messenger, SCREENSHOT_CHANNEL, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      g_screenshot_channel, method_call_cb, nullptr, nullptr);
}
