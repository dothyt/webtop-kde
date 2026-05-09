"""Drop-in pyautogui shim that drives ydotool/ydotoold.

The OSWorld bench builds pyautogui call strings (see
workloads/osworld.py:_format_action) and execs them inside the
container. This shim covers exactly the surface the bench uses so the
generator code can stay unchanged while input goes through ydotool
(which works under Wayland and avoids the Selkies cursor pipeline).

Required at runtime: ydotoold daemon must be listening on
$YDOTOOL_SOCKET (started by /custom-cont-init.d/20-ydotoold).
Container must have --device /dev/uinput.
"""
import os
import subprocess
import time

FAILSAFE = False  # pyautogui-compat attribute, no-op here

_SOCKET = os.environ.setdefault("YDOTOOL_SOCKET", "/tmp/.ydotool_socket")

# Linux input event codes (from /usr/include/linux/input-event-codes.h)
_KEYS = {
    "enter": 28, "return": 28, "esc": 1, "escape": 1, "tab": 15,
    "space": 57, "backspace": 14, "delete": 111, "insert": 110,
    "home": 102, "end": 107, "pageup": 104, "pagedown": 109,
    "up": 103, "down": 108, "left": 105, "right": 106,
    "ctrl": 29, "ctrlleft": 29, "ctrlright": 97,
    "shift": 42, "shiftleft": 42, "shiftright": 54,
    "alt": 56, "altleft": 56, "altright": 100,
    "win": 125, "winleft": 125, "winright": 126,
    "super": 125, "cmd": 125, "command": 125, "meta": 125,
    "capslock": 58, "numlock": 69, "scrolllock": 70,
    "f1": 59, "f2": 60, "f3": 61, "f4": 62, "f5": 63, "f6": 64,
    "f7": 65, "f8": 66, "f9": 67, "f10": 68, "f11": 87, "f12": 88,
}
# letters a-z
for _i, _c in enumerate("abcdefghijklmnopqrstuvwxyz"):
    _KEYS[_c] = (30, 48, 46, 32, 18, 33, 34, 35, 23, 36, 37, 38, 50,
                 49, 24, 25, 16, 19, 31, 20, 22, 47, 17, 45, 21, 44)[_i]
# digits 0-9
for _i, _c in enumerate("1234567890"):
    _KEYS[_c] = (2, 3, 4, 5, 6, 7, 8, 9, 10, 11)[_i]
# punctuation (US layout)
_KEYS.update({
    "-": 12, "=": 13, "[": 26, "]": 27, "\\": 43, ";": 39, "'": 40,
    "`": 41, ",": 51, ".": 52, "/": 53,
})

# Mouse button codes for `ydotool click <hex>`:
#   bit layout: 0x40=down, 0x80=up; OR with button (0x00=L, 0x01=R, 0x02=M)
# So a full down+up of left = 0xC0, right = 0xC1, middle = 0xC2.
_BUTTON = {"left": 0xC0, "right": 0xC1, "middle": 0xC2,
           1: 0xC0, 2: 0xC2, 3: 0xC1}


def _ydo(*args, check=True):
    return subprocess.run(["ydotool", *map(str, args)],
                          capture_output=True, text=True,
                          env={**os.environ, "YDOTOOL_SOCKET": _SOCKET},
                          check=check)


def _key_code(name):
    if isinstance(name, int):
        return name
    return _KEYS[name.lower()]


def moveTo(x, y, duration=0.0, **_kw):
    _ydo("mousemove", "--absolute", "-x", int(x), "-y", int(y))
    if duration:
        time.sleep(duration)


def click(x=None, y=None, clicks=1, interval=0.0, button="left", **_kw):
    if x is not None and y is not None:
        moveTo(x, y)
    code = _BUTTON.get(button, 0xC0)
    for i in range(int(clicks)):
        if i and interval:
            time.sleep(interval)
        _ydo("click", f"0x{code:02X}")


def rightClick(x=None, y=None, **kw):
    click(x, y, button="right", **kw)


def doubleClick(x=None, y=None, **kw):
    click(x, y, clicks=2, **kw)


def mouseDown(x=None, y=None, button="left", **_kw):
    if x is not None and y is not None:
        moveTo(x, y)
    code = _BUTTON.get(button, 0xC0) & 0x7F | 0x40  # down only
    _ydo("click", f"0x{code:02X}")


def mouseUp(x=None, y=None, button="left", **_kw):
    if x is not None and y is not None:
        moveTo(x, y)
    code = _BUTTON.get(button, 0xC0) & 0x7F | 0x80  # up only
    _ydo("click", f"0x{code:02X}")


def dragTo(x, y, duration=0.0, button="left", **_kw):
    mouseDown(button=button)
    if duration:
        # ydotool mousemove is instantaneous; emulate duration with sleep
        time.sleep(duration)
    moveTo(x, y)
    mouseUp(button=button)


def scroll(clicks, x=None, y=None, **_kw):
    if x is not None and y is not None:
        moveTo(x, y)
    # ydotool wheel: positive y = up, negative = down
    _ydo("mousemove", "--wheel", "-y", int(clicks))


def write(text, interval=0.0, **_kw):
    delay_ms = max(int(interval * 1000), 0)
    _ydo("type", "--delay", delay_ms, "--", str(text))


typewrite = write  # pyautogui alias


def press(key, presses=1, interval=0.0, **_kw):
    if isinstance(key, (list, tuple)):
        for k in key:
            press(k, presses=presses, interval=interval)
        return
    code = _key_code(key)
    for i in range(int(presses)):
        if i and interval:
            time.sleep(interval)
        _ydo("key", f"{code}:1", f"{code}:0")


def keyDown(key, **_kw):
    _ydo("key", f"{_key_code(key)}:1")


def keyUp(key, **_kw):
    _ydo("key", f"{_key_code(key)}:0")


def hotkey(*keys, interval=0.0, **_kw):
    codes = [_key_code(k) for k in keys]
    # Press all down, then release in reverse — pyautogui semantics.
    args = [f"{c}:1" for c in codes] + [f"{c}:0" for c in reversed(codes)]
    _ydo("key", *args)


def position():
    # ydotool can't query cursor position; return (0, 0). Bench
    # doesn't read this — it's only for compatibility.
    return (0, 0)


def size():
    # Bench code never calls size(); kept only for pyautogui-compat.
    return (1920, 1080)
