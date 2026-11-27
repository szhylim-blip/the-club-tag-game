"""Four-mode headless ENet integration test.

One `python tools/net_test.py` run starts a real host and two real clients for
each of TAG, HUSH, INFECTION and HOT POTATO on localhost. Clients auto-ready;
the host auto-starts once all three peers are present.

Assertions read the clients' replicated `NET_STATE` JSON (mode, role, IT,
found, infected, potato, fuse, out, position), not prose lines. They also check
that each client moves, uses an ability, receives the decisive mode event, and
that HUSH/INFECTION deliver the authoritative end result. The host drops a
client through ENet after the decisive event in TAG, HUSH and INFECTION, then
must log MATCH_CONTINUE and keep broadcasting.

Exit status is non-zero if any assertion fails.
"""
from __future__ import annotations

import json
import pathlib
import re
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
GODOT = "godot"
MODES = ["tag", "hush", "infection", "potato"]
TIMEOUT_START = 14.0
TIMEOUT_EVENT = 12.0
TIMEOUT_END = 12.0


def logs_for(mode: str) -> tuple[pathlib.Path, pathlib.Path, pathlib.Path]:
    return (
        ROOT / f".net_test_{mode}_host.log",
        ROOT / f".net_test_{mode}_a.log",
        ROOT / f".net_test_{mode}_b.log",
    )


def spawn(args: list[str], log: pathlib.Path) -> subprocess.Popen:
    log.write_text("", encoding="utf-8")
    fh = open(log, "a", encoding="utf-8")
    p = subprocess.Popen(
        [GODOT, "--headless", "--path", str(ROOT), "--", *args],
        stdout=fh, stderr=subprocess.STDOUT, cwd=str(ROOT),
    )
    p._log_handle = fh  # type: ignore[attr-defined]
    return p


def read(path: pathlib.Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return ""


def wait_for(path: pathlib.Path, pattern: str, timeout: float) -> str:
    end = time.time() + timeout
    rx = re.compile(pattern)
    while time.time() < end:
        text = read(path)
        if rx.search(text):
            return text
        time.sleep(0.12)
    return read(path)


def stop(p: subprocess.Popen | None) -> None:
    if p is None:
        return
    try:
        p.kill()
        p.wait(timeout=5)
    except Exception:
        pass
    try:
        p._log_handle.close()  # type: ignore[attr-defined]
    except Exception:
        pass


def parse_states(text: str) -> list[dict]:
    out: list[dict] = []
    for line in text.splitlines():
        if "NET_STATE " not in line:
            continue
        raw = line.split("NET_STATE ", 1)[1].strip()
        try:
            value = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            out.append(value)
    return out


def state_matches(path: pathlib.Path, predicate, timeout: float) -> dict | None:
    end = time.time() + timeout
    while time.time() < end:
        for state in reversed(parse_states(read(path))):
            try:
                if predicate(state):
                    return state
            except (KeyError, TypeError, ValueError):
                continue
        time.sleep(0.12)
    return None


def progress_after_disconnect(path: pathlib.Path, timeout: float) -> bool:
    """A post-drop snapshot proves liveness; a post-drop OVER proves completion."""
    end = time.time() + timeout
    while time.time() < end:
        lines = read(path).splitlines()
        last_drop = max((i for i, line in enumerate(lines) if "DISCONNECT id=" in line), default=-1)
        if last_drop >= 0:
            after = lines[last_drop + 1:]
            if any("SNAPSHOT mode=" in line or "OVER result=" in line for line in after):
                return True
        time.sleep(0.12)
    return False


def ids_in(state: dict, key: str) -> list[int]:
    value = state.get(key, [])
    if not isinstance(value, list):
        return []
    try:
        return [int(v) for v in value]
    except (TypeError, ValueError):
        return []


def run_mode(mode: str) -> tuple[list[str], bool]:
    host_log, a_log, b_log = logs_for(mode)
    for p in (host_log, a_log, b_log):
        p.unlink(missing_ok=True)
    host = alpha = bravo = None
    failures: list[str] = []
    disconnect_seen = False
    try:
        host = spawn(["--net-host", "--net-auto", "--net-test", f"--net-mode={mode}",
                      "--net-name=HOST", "--net-run=10"], host_log)
        time.sleep(1.5)
        alpha = spawn(["--net-join=127.0.0.1", "--net-test", "--net-name=ALPHA"], a_log)
        if "JOIN id=" not in wait_for(host_log, r"JOIN id=\d+ name=ALPHA", 8):
            failures.append("ALPHA did not join")
        bravo = spawn(["--net-join=127.0.0.1", "--net-test", "--net-name=BRAVO"], b_log)
        if "JOIN id=" not in wait_for(host_log, r"JOIN id=\d+ name=BRAVO", 8):
            failures.append("BRAVO did not join")

        h = wait_for(host_log, rf"MATCH_START .*mode={mode}.*players=3", TIMEOUT_START)
        if not re.search(rf"MATCH_START .*mode={mode}.*players=3", h):
            failures.append(f"host never started {mode} with 3 players")
        for label, path in (("ALPHA", a_log), ("BRAVO", b_log)):
            text = wait_for(path, rf"MATCH_START .*mode={mode}", TIMEOUT_START)
            if not re.search(rf"MATCH_START .*mode={mode}", text):
                failures.append(f"{label} did not enter {mode}")

        a0 = state_matches(a_log, lambda s: s.get("mode") == mode, 8)
        b0 = state_matches(b_log, lambda s: s.get("mode") == mode, 8)
        if a0 is None:
            failures.append("ALPHA never received a replicated mode state")
        if b0 is None:
            failures.append("BRAVO never received a replicated mode state")
        if a0 is not None and b0 is not None:
            # Role assignment immediately after the host-authored setup.
            if mode == "tag":
                if int(a0.get("it", 0)) != 1 or int(b0.get("it", 0)) != 1:
                    failures.append("TAG did not start with host as IT")
            elif mode == "hush":
                if int(a0.get("seeker", 0)) != 1 or int(b0.get("seeker", 0)) != 1:
                    failures.append("HUSH did not start with host as seeker")
            elif mode == "infection":
                if 1 not in [int(x) for x in ids_in(a0, "infected")] or 1 not in [int(x) for x in ids_in(b0, "infected")]:
                    failures.append("INFECTION did not start with host as patient zero")
            elif mode == "potato":
                if int(a0.get("potato", 0)) != 1 or int(b0.get("potato", 0)) != 1:
                    failures.append("HOT POTATO did not start with host carrying")

        # Client-owned movement: at least two distinct replicated positions.
        for label, path in (("ALPHA", a_log), ("BRAVO", b_log)):
            moved = state_matches(
                path,
                lambda s, first=read(path): any(
                    abs(float(s.get("pos", [0, 0])[0]) - float(other.get("pos", [0, 0])[0])) > 0.15
                    or abs(float(s.get("pos", [0, 0])[1]) - float(other.get("pos", [0, 0])[1])) > 0.15
                    for other in parse_states(first) if other.get("mode") == mode
                ),
                8,
            )
            if moved is None:
                failures.append(f"{label} never sent a changed position in {mode}")
        if "TEST_ABILITY" not in read(a_log) or "TEST_ABILITY" not in read(b_log):
            wait_for(a_log, r"TEST_ABILITY", 3)
            wait_for(b_log, r"TEST_ABILITY", 3)
        if "TEST_ABILITY" not in read(a_log):
            failures.append("ALPHA never used an ability")
        if "TEST_ABILITY" not in read(b_log):
            failures.append("BRAVO never used an ability")

        # Decisive host event + the same state observed on both clients.
        if mode == "tag":
            h = wait_for(host_log, r"TAG \d+ -> \d+", TIMEOUT_EVENT)
            if not re.search(r"TAG \d+ -> \d+", h):
                failures.append("host never transferred IT")
            for label, path in (("ALPHA", a_log), ("BRAVO", b_log)):
                st = state_matches(path, lambda s: int(s.get("it", 0)) != 1, TIMEOUT_EVENT)
                if st is None:
                    failures.append(f"{label} never observed the TAG transfer")
        elif mode == "hush":
            h = wait_for(host_log, r"FOUND id=\d+", TIMEOUT_EVENT)
            if "FOUND id=" not in h:
                failures.append("host never found a hider")
            for label, path in (("ALPHA", a_log), ("BRAVO", b_log)):
                st = state_matches(path, lambda s: len(ids_in(s, "found")) > 0, TIMEOUT_EVENT)
                if st is None:
                    failures.append(f"{label} never observed a found hider")
            if "OVER result=SEEKER WINS" not in wait_for(host_log, r"OVER result=", TIMEOUT_END):
                failures.append("host did not end HUSH with a seeker win")
        elif mode == "infection":
            h = wait_for(host_log, r"INFECT id=\d+", TIMEOUT_EVENT)
            if "INFECT id=" not in h:
                failures.append("host never infected a survivor")
            for label, path in (("ALPHA", a_log), ("BRAVO", b_log)):
                st = state_matches(path, lambda s: len(ids_in(s, "infected")) >= 2, TIMEOUT_EVENT)
                if st is None:
                    failures.append(f"{label} never observed an infection transfer")
            if "OVER result=INFECTED WIN" not in wait_for(host_log, r"OVER result=", TIMEOUT_END):
                failures.append("host did not end INFECTION with an infected win")
            survivor_result = any(
                "NET_OVER result=INFECTED WIN" in read(path) for path in (a_log, b_log))
            if not survivor_result:
                failures.append("no client received the authoritative INFECTION result")
        elif mode == "potato":
            h = wait_for(host_log, r"POTATO_BOOM", TIMEOUT_EVENT)
            if "POTATO_BOOM" not in h:
                failures.append("host never detonated the potato")
            if "POTATO_PASS" not in h:
                failures.append("host never transferred the potato")
            for label, path in (("ALPHA", a_log), ("BRAVO", b_log)):
                st = state_matches(path, lambda s: len(ids_in(s, "out")) > 0, TIMEOUT_EVENT)
                if st is None:
                    failures.append(f"{label} never observed the potato detonation")

        if mode == "hush":
            survivor_result = any(
                "NET_OVER result=SEEKER WINS" in read(path) for path in (a_log, b_log))
            if not survivor_result:
                failures.append("no client received the authoritative HUSH result")

        # Transport-level mid-round disconnect in three modes. The dropped peer
        # cannot report its own result; the surviving peer and host must keep going.
        if mode in ("tag", "hush", "infection"):
            h = wait_for(host_log, r"DISCONNECT id=\d+", 12)
            if "DISCONNECT id=" not in h:
                failures.append("host never logged the ENet disconnect")
            h = wait_for(host_log, rf"MATCH_CONTINUE mode={mode}", 6)
            if f"MATCH_CONTINUE mode={mode}" not in h:
                failures.append("host did not continue after the disconnect")
            else:
                disconnect_seen = True
            			# The host emits MATCH_CONTINUE before its DISCONNECT log line, so
			# search from the last disconnect rather than slicing the earlier text.
            if not progress_after_disconnect(host_log, 4.0):
                failures.append("host neither snapshotted nor completed after the disconnect")

        time.sleep(0.4)
        for label, path in (("host", host_log), ("ALPHA", a_log), ("BRAVO", b_log)):
            if "SCRIPT ERROR" in read(path):
                failures.append(f"{label} printed a script error")
        stop(host)
        host = None
        stop(alpha)
        alpha = None
        stop(bravo)
        bravo = None
    finally:
        stop(host)
        stop(alpha)
        stop(bravo)

    print(f"== {mode.upper()} host ==")
    print("\n".join(read(host_log).splitlines()[-10:]))
    print(f"== {mode.upper()} ALPHA ==")
    print("\n".join(read(a_log).splitlines()[-6:]))
    print(f"== {mode.upper()} BRAVO ==")
    print("\n".join(read(b_log).splitlines()[-6:]))
    for f in failures:
        print(f"FAIL [{mode}]: {f}")
    print(f"MODE_RESULT mode={mode} failures={len(failures)} disconnect={disconnect_seen}")
    return failures, disconnect_seen


def main() -> int:
    all_failures: list[str] = []
    disconnect_modes: list[str] = []
    for mode in MODES:
        failures, disconnected = run_mode(mode)
        all_failures.extend(failures)
        if disconnected:
            disconnect_modes.append(mode)
    if len(disconnect_modes) < 2:
        all_failures.append(
            f"only {len(disconnect_modes)} mode(s) survived a mid-round disconnect: {disconnect_modes}")
    print(f"DISCONNECT_MODES {','.join(disconnect_modes) or 'none'}")
    print(f"NET_TEST {'PASS' if not all_failures else 'FAIL'} failures={len(all_failures)}")
    return 0 if not all_failures else 1


if __name__ == "__main__":
    sys.exit(main())
