#pragma once

#include <flutter_linux/flutter_linux.h>

/// Registers the com.clawrelay/screenshot method channel.
/// Call after fl_register_plugins().
void screenshot_plugin_register(FlView* view);
