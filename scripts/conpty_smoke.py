#!/usr/bin/env python3
"""CI-only ConPTY harness for the interactive Hondo counter example."""

from __future__ import annotations

import os
import select
import sys
import time

from winpty import Backend, PtyProcess

TIMEOUT_SECONDS = 30
READY_MARKER = "Count: 0"
INCREMENTAL_UPDATE = "\x1b[1;8H1"
INITIAL_ROWS = 8
INITIAL_COLUMNS = 64
RESIZED_ROWS = 10
RESIZED_COLUMNS = 50
ORDERED_MARKERS = (
    "\x1b[?1049h",
    "\x1b[H",
    READY_MARKER,
    "\x1b[H",
    INCREMENTAL_UPDATE,
    "\x1b[?25h",
    "\x1b[?1049l",
)


def fail(message: str, output: str) -> None:
    sys.stderr.write(f"ConPTY smoke failed: {message}\n")
    sys.stderr.write(f"captured text: {output!r}\n")
    raise SystemExit(1)


def main() -> None:
    command = sys.argv[1:]
    if not command:
        raise SystemExit("usage: conpty_smoke.py COMMAND [ARG ...]")

    command[0] = os.path.abspath(command[0])
    proc = PtyProcess.spawn(
        command,
        dimensions=(INITIAL_ROWS, INITIAL_COLUMNS),
        backend=Backend.ConPTY,
    )

    output = ""
    deadline = time.monotonic() + TIMEOUT_SECONDS
    resize_sent = False
    resize_observed = False
    resize_search_start = 0
    sent_enter = False

    try:
        while time.monotonic() < deadline:
            readable, _, _ = select.select([proc.fileobj], [], [], 0.25)
            if readable:
                try:
                    chunk = proc.read()
                except EOFError:
                    break
                if chunk:
                    output += chunk

            if not resize_sent and READY_MARKER in output:
                resize_search_start = len(output)
                proc.setwinsize(RESIZED_ROWS, RESIZED_COLUMNS)
                resize_sent = True

            if resize_sent and not resize_observed:
                resize_index = output.find("\x1b[H", resize_search_start)
                if resize_index >= 0:
                    resize_observed = True
                    proc.write("\r")
                    sent_enter = True

            if sent_enter and not proc.isalive():
                # ConPTY may not signal EOF immediately after child exit. Drain
                # any bytes already queued without requiring EOF itself.
                for _ in range(8):
                    readable, _, _ = select.select([proc.fileobj], [], [], 0.05)
                    if not readable:
                        break
                    try:
                        chunk = proc.read()
                    except EOFError:
                        break
                    if chunk:
                        output += chunk
                break
        else:
            proc.close(force=True)
            fail("interactive counter timed out", output)

        if proc.isalive():
            proc.close(force=True)
            fail("counter did not exit after activation input", output)

        exit_status = proc.exitstatus
        if not resize_sent:
            fail("initial Count: 0 frame was never observed", output)
        if not resize_observed:
            fail("terminal resize did not trigger a fresh frame", output)
        if not sent_enter:
            fail("increment input was never sent", output)
        if exit_status not in (0, None):
            fail(f"counter exited with status {exit_status}", output)

        cursor = 0
        for marker in ORDERED_MARKERS:
            index = output.find(marker, cursor)
            if index < 0:
                fail(f"missing ordered marker {marker!r}", output)
            cursor = index + len(marker)

        sys.stdout.write("Hondo Windows ConPTY resize + incremental-render smoke passed\n")
    finally:
        if proc.isalive():
            proc.close(force=True)


if __name__ == "__main__":
    main()
