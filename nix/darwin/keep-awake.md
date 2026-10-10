# Keep Awake on lima

Keep Awake prevents system sleep on battery and power for a chosen number of
minutes. Click again to end the session. Expiration, daemon restart, and reboot
restore normal sleep by setting `pmset -a disablesleep 0`. Other power settings
remain as configured. The Control Center label stays **Keep Awake**; confirmations
show the deadline or that the session stopped.

## Install

Apply the lima configuration from this repository:

```bash
sudo darwin-rebuild switch --flake path:$HOME/.dotfiles#lima
```

The system launchd daemon `org.nixos.keep-awake` runs as `victoryap` and uses lima's
existing passwordless `pmset` permission. It restores sleep before accepting
requests, handles requests sequentially, and checks expiration every five seconds.
The helper refuses requests when the daemon is unavailable. A start request while
already active fails rather than extending the session.

In Shortcuts, create a shortcut named **Keep Awake** with one **Run AppleScript**
action containing:

```applescript
on run {input, parameters}
    run script POSIX file "/etc/keep-awake/toggle.applescript"
    return input
end run
```

Shortcuts must have **Settings → Advanced → Allow Running Scripts** enabled.
The prompt accepts a positive whole number of minutes, up to nine digits. Cancel
leaves the settings unchanged. Errors appear in a dialog.

Open **Control Center → Edit Controls → Shortcuts → Run Shortcut**, add the
control, and choose **Keep Awake**.

## Commands and diagnostics

```bash
/etc/keep-awake/helper start 30
/etc/keep-awake/helper stop
/etc/keep-awake/helper status
launchctl print system/org.nixos.keep-awake
pmset -g
```

`status` returns `inactive` or `active` followed by the local deadline. Session
requests and daemon identity live in
`~/Library/Application Support/Keep Awake/`, outside the repository. The deadline
exists only in the daemon's memory. Logs are in `~/Library/Logs/keep-awake.log`.

## Verification

Run `scripts/test-sync.sh` for static shell checks, input validation, and refusal
when the daemon is unavailable. Compile the AppleScript with `osacompile` and
evaluate/build `darwinConfigurations.lima.config.system.build.toplevel` for Nix
validation.

After activation:

- Start a one-minute session. Check that `status` shows a deadline and `pmset -g`
  shows `SleepDisabled 1`. Within five seconds after the deadline, check for
  `inactive` and `SleepDisabled 0`.
- Start again and click the control a second time. Check for `inactive` and
  `SleepDisabled 0`. Repeat start/stop clicks.
- Cancel the minutes prompt and try zero, negative, fractional, and nonnumeric
  input. Confirm no session starts and errors are shown for invalid input.
- Send a second start during an active session. Confirm it fails and the
  deadline remains unchanged.
- Start a session, then run
  `sudo launchctl kickstart -k system/org.nixos.keep-awake`. Confirm sleep returns
  and `status` becomes `inactive` after startup.
- Close the lid during a session on battery and power, and unplug during a
  session. Confirm the intended workload continues. After stopping or expiration,
  confirm normal lid sleep returns.
- Reboot during an active session. Confirm `inactive` and `SleepDisabled 0` after
  startup.

`disablesleep` is undocumented. Lid behavior on this hardware and macOS version
requires the physical checks above before this feature can be considered verified.
