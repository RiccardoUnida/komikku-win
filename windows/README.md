# Komikku for Windows (unofficial, untested build kit)

Builds a portable folder / zip (and optionally an installer) of Komikku using
MSYS2 UCRT64 (GTK4, libadwaita, PyGObject).

## Build

### On GitHub (no Windows machine needed)
Push this tree to a GitHub repository and run **Actions → Windows build → Run workflow**.
Artifacts: `Komikku-windows-x64-portable` (zip) and `Komikku-windows-x64-installer` (setup .exe).

### On a Windows machine
1. Install MSYS2 (https://www.msys2.org) and open the **MSYS2 UCRT64** shell.
2. `bash windows/build.sh`
3. `bash windows/selftest.sh` (runs the bundle with no MSYS2 on PATH)
4. Run `_winbuild/Komikku/Komikku.vbs`. If nothing happens, run `Komikku-console.cmd` to see errors.
   Logs of the windowless launcher: `%LOCALAPPDATA%\Komikku\komikku.log`.

Options: `RELAX_DEPS=1` (ignore minimum GTK/libadwaita versions), `SKIP_DEPS=1`.

## What differs from the Linux version
- **No WebKitGTK.** `scripts/remove_webview.py` (upstream) is applied to a copy of the sources:
  servers and trackers that need a web view (captcha / login flows) are removed.
- File and folder names are made valid for Windows (`: ? " * < > |`, trailing dots, reserved names).
- `folder_size()` no longer needs the Unix `du` command on Windows.
- Credentials use the plaintext fallback of the keyring helper (no Secret Service on Windows).
- `unrar` / `unar` are not bundled: CBR import may not work.
- Windows' 260-character path limit can affect long series/chapter names unless long paths are enabled.

## Not verified
Nothing here has been run on Windows. Package names, Python relocatability, DLL bundling,
fonts and the installer are all unverified. Expect to iterate on the first CI log.

## License / upstream
Komikku is GPL-3.0-or-later. The upstream README states that LLM-generated contributions are
not accepted, so do not send these changes upstream; keep them in your own fork.
