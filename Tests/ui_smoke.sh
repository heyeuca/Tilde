#!/bin/bash
# UI regression smoke tests, driven through the real app via System Events
# (needs Accessibility permission for the terminal; GUI session required —
# NOT part of Tests/run.sh).
#
# Pins the 2026-08 app review focus and data-safety regressions:
#   1. ⌘N then type immediately  → text lands in the body
#   2. Reader (⌘⇧R) → Esc → type → text lands in the body
#   3. Lossy-encoding file       → read-only, bytes never change
#   4. CRLF paste                → normalized to LF; saved bytes stay clean
#   5. Mixed line endings        → an edit keeps untouched lines' endings
#   6. ⌘Q with untitled text     → no alert; relaunch brings the text back
#
# Scenario 4 uses the clipboard: the current TEXT clipboard is saved and
# restored, but non-text clipboard content is lost.
#
# Usage: Tests/ui_smoke.sh   (builds the smoke bundle first)

set -u
cd "$(dirname "$0")/.."

APP="$(scripts/smoke_bundle.sh)" || { echo "FAIL  smoke bundle build"; exit 1; }
BIN="$APP/Contents/MacOS/Tilde"
WORK="$(mktemp -d)"
passed=0
failed=0
APP_PID=""

result() { # $1 = 0/1 (ok?), $2 = name
    if [[ "$1" == "0" ]]; then passed=$((passed+1)); echo "  ok  $2"
    else failed=$((failed+1)); echo "FAIL  $2"; fi
}

kill_app() {
    [[ -n "$APP_PID" ]] && kill -9 "$APP_PID" 2>/dev/null
    pkill -9 -f "$BIN" 2>/dev/null
    APP_PID=""
    sleep 0.5
}

# The process is addressed by unix id — a plain `process "Tilde"` is
# ambiguous the moment any other Tilde build is running.
tell_app() { # $1 = System Events statement operating on the process
    osascript -e "tell application \"System Events\" to tell (first process whose unix id is $APP_PID) to $1" 2>/dev/null
}

launch() { # $@ = extra `open` arguments (a file to open); IGNORE_STATE=NO restores windows
    open -n -a "$APP" "$@" --args -ApplePersistenceIgnoreState "${IGNORE_STATE:-YES}"
    for _ in $(seq 1 40); do
        APP_PID="$(pgrep -nf "$BIN")" && [[ -n "$APP_PID" ]] &&
            [[ "$(tell_app 'exists front window')" == "true" ]] && { sleep 0.7; return 0; }
        sleep 0.25
    done
    return 1
}

editor_text() { tell_app 'get value of text area 1 of scroll area 1 of group 1 of front window'; }
type_text() { tell_app "keystroke \"$1\""; }

trap 'kill_app; rm -rf "$WORK"' EXIT
pkill -9 -f "$BIN" 2>/dev/null

# ── 1. New document: type immediately ───────────────────────────────────────
if launch; then
    type_text "abc"
    sleep 0.5
    [[ "$(editor_text)" == "abc" ]]; result $? "new document accepts typing without a click"
else
    result 1 "new document accepts typing without a click (no window)"
fi
kill_app

# ── 2. Reader round trip: ⌘⇧R → Esc → type ─────────────────────────────────
printf '# Title\n\nbody text\n' > "$WORK/reader.md"
if launch "$WORK/reader.md"; then
    tell_app 'keystroke "r" using {command down, shift down}'
    sleep 1.2   # reader render + focus handoff
    tell_app 'key code 53'   # Esc
    sleep 0.8   # focus restore is deferred one runloop
    type_text "xyz"
    sleep 0.5
    case "$(editor_text)" in
        *xyz*) result 0 "typing works after Reader → Esc" ;;
        *)     result 1 "typing works after Reader → Esc" ;;
    esac
    # Exit via ⌘⇧R (the menu/toolbar path) must restore focus too.
    tell_app 'keystroke "r" using {command down, shift down}'
    sleep 1.2
    tell_app 'keystroke "r" using {command down, shift down}'
    sleep 0.8
    type_text "qqq"
    sleep 0.5
    case "$(editor_text)" in
        *qqq*) result 0 "typing works after Reader → ⌘⇧R exit" ;;
        *)     result 1 "typing works after Reader → ⌘⇧R exit" ;;
    esac
else
    result 1 "typing works after Reader → Esc (no window)"
fi
kill_app

# ── 3. Lossy-encoding file: read-only, bytes untouched ─────────────────────
printf '\xbe\xc8\xb3\xe7\xc7\xcf\xbc\xbc\xbf\xe4' > "$WORK/euckr.txt"   # EUC-KR "안녕하세요"
before="$(md5 -q "$WORK/euckr.txt")"
if launch "$WORK/euckr.txt"; then
    initial="$(editor_text)"
    type_text "zzz"
    sleep 0.5
    [[ "$(editor_text)" == "$initial" ]]; result $? "lossy document rejects typing (read-only)"
    tell_app 'keystroke "s" using command down'
    sleep 1
    [[ "$(md5 -q "$WORK/euckr.txt")" == "$before" ]]; result $? "lossy document's bytes never change on ⌘S"
else
    result 1 "lossy document checks (no window)"
fi
kill_app

# ── 4. CRLF paste: buffer and saved bytes stay LF-only ─────────────────────
printf 'alpha\n' > "$WORK/lf.txt"
clipboard_backup="$(pbpaste 2>/dev/null)"
printf 'one\r\ntwo\rthree' | pbcopy
if launch "$WORK/lf.txt"; then
    tell_app 'keystroke "v" using command down'
    sleep 0.5
    tell_app 'keystroke "s" using command down'
    sleep 1
    if LC_ALL=C grep -q $'\r' "$WORK/lf.txt"; then
        result 1 "CRLF paste saved without CR bytes"
    else
        result 0 "CRLF paste saved without CR bytes"
    fi
    [[ "$(head -1 "$WORK/lf.txt")" == "one" ]]; result $? "pasted CRLF text kept its line structure"
else
    result 1 "CRLF paste checks (no window)"
fi
printf '%s' "$clipboard_backup" | pbcopy
kill_app

# ── 5. Mixed line endings: untouched lines keep theirs (issue #17) ───────
printf 'a\r\nb\r\nc\r\nd\ne\r\n' > "$WORK/mixed.txt"
if launch "$WORK/mixed.txt"; then
    type_text "X"   # caret opens at the start: line 1 becomes "Xa"
    sleep 0.5
    tell_app 'keystroke "s" using command down'
    sleep 1
    [[ "$(od -An -c "$WORK/mixed.txt" | tr -d ' \n')" == 'Xa\r\nb\r\nc\r\nd\ne\r\n' ]]
    result $? "mixed-ending file keeps untouched lines' endings on ⌘S"
else
    result 1 "mixed line ending checks (no window)"
fi
kill_app

# ── 6. Quit keeps untitled text (#44) ──────────────────────────────────────
# One untitled window with text and one left blank: ⌘Q quits without the
# "review before quitting" alert, and the relaunch brings back only the
# text, still untitled and still edited. Both launches keep saved state (a
# launch that ignores it doesn't save it at quit either), so whatever an
# earlier, interrupted run left is discarded first.
discard_windows() { # closes every window, deleting untitled ones
    for _ in $(seq 1 10); do
        [[ "$(tell_app 'count windows')" == "0" ]] && break
        tell_app 'keystroke "w" using command down'
        sleep 0.7
        tell_app 'click button "Delete" of splitter group 1 of sheet 1 of front window' >/dev/null
        sleep 0.5
    done
}
quit_app() { # ⌘Q; returns 0 when the process is gone without an alert
    tell_app 'keystroke "q" using command down'
    for _ in $(seq 1 20); do kill -0 "$APP_PID" 2>/dev/null || break; sleep 0.25; done
    ! kill -0 "$APP_PID" 2>/dev/null
}
IGNORE_STATE=NO launch && { discard_windows; quit_app; }
kill_app
if IGNORE_STATE=NO launch; then
    type_text "hot exit"
    sleep 0.5
    tell_app 'keystroke "n" using command down'
    sleep 1
    quit_app; result $? "⌘Q with untitled text quits without an alert"
    kill_app
    if IGNORE_STATE=NO launch; then
        [[ "$(tell_app 'count windows')" == "1" ]]
        result $? "relaunch brings back one window, not the blank one"
        [[ "$(editor_text)" == "hot exit" ]]; result $? "relaunch brings back the untitled text"
        [[ "$(tell_app 'get name of front window')" == Untitled* ]]
        result $? "restored window is still untitled"
        tell_app 'keystroke "w" using command down'
        sleep 0.7
        [[ "$(tell_app 'count sheets of front window')" == "1" ]]
        result $? "restored window is still edited (⌘W asks to save)"
        tell_app 'click button "Delete" of splitter group 1 of sheet 1 of front window' >/dev/null
        sleep 0.5
        discard_windows   # so the next run starts clean
    else
        result 1 "relaunch brings back the untitled text (no window)"
    fi
else
    result 1 "quit keeps untitled text (no window)"
fi
kill_app

echo
echo "$passed passed, $failed failed"
exit $((failed == 0 ? 0 : 1))
