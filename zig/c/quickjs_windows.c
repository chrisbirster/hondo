/*
 * QuickJS 2026-06-04's small-block arena crashes when quickjs.c is compiled
 * by Zig 0.16 for native Windows. Upstream already selects the host-backed
 * large-block path when AddressSanitizer is visible. Compile quickjs.c through
 * this wrapper on Windows so that exact upstream code path is selected without
 * modifying the pinned QuickJS source.
 */
#define __SANITIZE_ADDRESS__ 1
#include "quickjs.c"
