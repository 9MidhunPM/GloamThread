#!/usr/bin/env python3
"""Run GameMenus on a new private Xvfb display; capture actual rendered pixels.

Requires Godot, Xvfb, xdotool, ImageMagick import and Pillow. No host display,
window, settings, campaign state or network service is controlled by this test.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import selectors
import shutil
import subprocess
import tempfile
import time

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[2]


def wait_until(predicate, timeout=12):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        result = predicate()
        if result:
            return result
        time.sleep(0.05)
    raise RuntimeError("Timed out waiting for native UI fixture")


def records(path, prefix):
    return [json.loads(line[len(prefix):]) for line in path.read_text(errors="replace").splitlines()
            if line.startswith(prefix)]


def same_pixels(left, right):
    return left.size == right.size and ImageChops.difference(left.convert("RGB"), right.convert("RGB")).getbbox() is None


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--xvfb", default="Xvfb")
    parser.add_argument("--xdotool", default="xdotool")
    parser.add_argument("--library-path", help="Optional private xdotool library directory")
    parser.add_argument("--output", type=Path, default=ROOT / "evidence/content/ui/captures")
    args = parser.parse_args()
    for executable in (args.xvfb, args.xdotool, "godot", "import"):
        require(shutil.which(executable) is not None, f"Missing QA dependency: {executable}")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["LIBGL_ALWAYS_SOFTWARE"] = "1"
    if args.library_path:
        env["LD_LIBRARY_PATH"] = str(Path(args.library_path).resolve())
    app = None
    app_stream = None
    commands = []
    with tempfile.TemporaryDirectory(prefix="gloamthread-ui-display-") as directory:
        with open(Path(directory) / "xvfb.log", "w") as server_log:
            server = subprocess.Popen([args.xvfb, "-displayfd", "1", "-screen", "0", "1920x1080x24",
                                       "-nolisten", "tcp", "-noreset"], stdout=subprocess.PIPE, stderr=server_log, text=True)
            try:
                selector = selectors.DefaultSelector()
                selector.register(server.stdout, selectors.EVENT_READ)
                require(bool(selector.select(10)), "Xvfb did not announce a private display")
                number = server.stdout.readline().strip()
                selector.close()
                require(number.isdecimal(), "Xvfb returned an invalid display identifier")
                env["DISPLAY"] = ":" + number

                def xdo(*arguments):
                    return subprocess.check_output([args.xdotool, *map(str, arguments)], env=env, text=True).strip()

                def start(scale, long_prompts=False, capture_all=False):
                    nonlocal app, app_stream
                    name = "long-prompts" if long_prompts else f"native-{scale}x"
                    log = output / (name + ".log")
                    app_stream = log.open("w")
                    command = ["godot", "--path", str(ROOT), "--display-driver", "x11", "--rendering-method", "gl_compatibility",
                               "--audio-driver", "Dummy", "--resolution", f"{960 * scale}x{360 * scale}", "--position", "0,0",
                               "res://scenes/ui/menu_preview.tscn", "--", "--menu", "settings"]
                    if long_prompts:
                        command.append("--long-prompts")
                    if capture_all:
                        command += ["--capture-dir", str(output / "1x")]
                    commands.append(command)
                    app = subprocess.Popen(command, cwd=ROOT, env=env, stdout=app_stream, stderr=subprocess.STDOUT)
                    wait_until(lambda: records(log, "UI_PREVIEW_LAYOUT "))
                    if capture_all:
                        wait_until(lambda: len(records(log, "UI_RENDER_CAPTURE ")) == 9)
                        wait_until(lambda: log.read_text().rstrip().endswith("}") and
                                   records(log, "UI_PREVIEW_LAYOUT ")[-1]["kind"] == "settings")
                    # Debug builds may append a title suffix. PID ownership is
                    # the authority; the prefix only narrows this private display.
                    windows = xdo("search", "--onlyvisible", "--name", "^Gloamthread menu preview").splitlines()
                    window = next((item for item in windows if int(xdo("getwindowpid", item)) == app.pid), None)
                    require(window is not None, "Native window does not belong to the test process")
                    xdo("windowfocus", "--sync", window)
                    time.sleep(0.15)
                    return log, window

                def capture(window, path):
                    path.parent.mkdir(parents=True, exist_ok=True)
                    subprocess.run(["import", "-window", window, str(path)], env=env, check=True)
                    return Image.open(path).convert("RGB")

                def stop_app():
                    nonlocal app, app_stream
                    if app is not None:
                        if app.poll() is None:
                            app.terminate()
                        try:
                            app.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                            app.kill()
                            app.wait(timeout=5)
                        app = None
                    if app_stream is not None:
                        app_stream.close()
                        app_stream = None

                log, window = start(1, capture_all=True)
                before = capture(window, output / "1x/settings_window.png")
                framebuffer = Image.open(output / "1x/settings.png").convert("RGB")
                require(same_pixels(before, framebuffer), "Native window differs from the engine framebuffer")
                require(len(before.getcolors(before.width * before.height)) > 3, "Native menu capture lacks rendered content")
                xdo("key", "--clearmodifiers", "--delay", "120", "Down", "period", "m", "Return")
                time.sleep(0.1)
                after = capture(window, output / "1x/nonowner_unchanged.png")
                require(same_pixels(before, after), "Partner keys changed the owner's menu pixels")
                require(not records(log, "UI_PREVIEW_ACTION "), "Partner keys emitted an action")
                xdo("key", "--clearmodifiers", "--delay", "120", "d", "s", "a")
                wait_until(lambda: len(records(log, "UI_PREVIEW_ACTION ")) >= 2)
                layout = wait_until(lambda: records(log, "UI_PREVIEW_LAYOUT ")[-1])
                row = next(item for item in layout["rows"] if item["id"] == "effects")
                x, y, width, _ = row["rect"]
                xdo("mousemove", "--sync", round(x + width - 20), round(y + 12), "click", "1")
                wait_until(lambda: len(records(log, "UI_PREVIEW_ACTION ")) >= 3)
                actions = records(log, "UI_PREVIEW_ACTION ")
                expected = [{"action": "music", "payload": {"direction": 1}},
                            {"action": "effects", "payload": {"direction": -1}},
                            {"action": "effects", "payload": {"direction": 1}}]
                require(actions == expected, f"Unexpected native action sequence: {actions}")
                time.sleep(0.1)
                capture(window, output / "1x/settings_input.png")
                xdo("key", "--clearmodifiers", "--delay", "120", "Escape", "s", "s", "s", "space", "s", "s", "space")
                require(app.wait(timeout=5) == 0, "Native cancel/title/quit flow did not exit cleanly")
                require([item["action"] for item in records(log, "UI_PREVIEW_ACTION ")[-3:]] == ["cancel", "title", "quit"],
                        "Native cancel/title/quit actions mismatch")
                stop_app()

                log2, window2 = start(2)
                large = capture(window2, output / "2x/settings_window.png")
                require(large.size == (1920, 720), f"Unexpected 2x window size: {large.size}")
                small = large.resize((960, 360), Image.Resampling.NEAREST)
                require(same_pixels(small, before), "2x menu differs from the 1x logical layout")
                require(same_pixels(small.resize((1920, 720), Image.Resampling.NEAREST), large), "2x pixels are filtered or unevenly scaled")
                stop_app()

                log3, window3 = start(1, long_prompts=True)
                layout = records(log3, "UI_PREVIEW_LAYOUT ")[-1]
                require(layout["footer_lines"] == 2, "Long prompt fixture did not wrap into exactly two lines")
                capture(window3, output / "long_prompts.png")
                stop_app()
                for log_path in (output / "native-1x.log", log2, log3):
                    text = log_path.read_text()
                    require("SCRIPT ERROR" not in text and "\nERROR:" not in text, f"Unexpected engine error: {log_path}")
                result = {"engine": subprocess.check_output(["godot", "--version"], text=True).strip(),
                          "renderer": "X11 / Compatibility / Mesa llvmpipe", "private_display": True,
                          "fixture_states_rendered": 9, "native_matches_engine_framebuffer": True,
                          "nonowner_pixels_unchanged": True,
                          "native_actions": expected, "cancel_title_quit": True,
                          "pixel_exact_integer_2x": True, "long_prompt_footer_lines": 2,
                          "commands": commands,
                          "limits": "UI fixture only; no physical gamepad, keyboard rollover, full application or human acceptance"}
                (output / "results.json").write_text(json.dumps(result, indent=2) + "\n")
                print(json.dumps({key: value for key, value in result.items() if key != "commands"}, indent=2))
            finally:
                if app is not None:
                    stop_app()
                server.terminate()
                try:
                    server.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    server.kill()
                    server.wait(timeout=5)


if __name__ == "__main__":
    main()
