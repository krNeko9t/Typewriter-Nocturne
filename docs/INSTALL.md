# Installing Typewriter Nocturne

Every package is built on GitHub Actions. Download one from a
[release](https://github.com/Chaosnap/Typewriter-Nocturne/releases) or, for development builds, from the
**Artifacts** section of a [CI run](https://github.com/Chaosnap/Typewriter-Nocturne/actions/workflows/ci.yml)
(signed-in GitHub account required for CI artifacts).

| Platform | File |
| --- | --- |
| macOS, Apple silicon | `Typewriter-Nocturne-<version>-mac-arm64.dmg` |
| macOS, Intel | `Typewriter-Nocturne-<version>-mac-x64.dmg` |
| Windows x64 | `Typewriter-Nocturne-<version>-win-x64.zip` (portable, no installer) |
| Linux x64 | `Typewriter-Nocturne-<version>-linux-x86_64.AppImage` or `…-linux-amd64.deb` |

Verify the download against `SHA256SUMS.txt` (release) or `SHA256SUMS-<platform>.txt` (CI artifact):

```bash
shasum -a 256 Typewriter-Nocturne-*.dmg
```

## Windows: extract and run

The Windows download is a ZIP of the whole application, not an installer. Extract it anywhere you can write
to and run `Typewriter Nocturne.exe` from the extracted folder. No administrator rights are needed.

Keep the folder intact: the executable needs everything beside it, including the unpacked ConPTY binaries
that Windows mouse support depends on and `resources\bin\`, which holds the `nocturne` helper. To update,
extract the new ZIP into a fresh folder and delete the old one — settings survive, because they live outside
the application folder.

There is no installer, but the running app still integrates with Windows on its own:

- **PATH.** Every launch adds `<extracted folder>\resources\bin` to your user PATH so that `nocturne` works.
  This is automatic, not only a result of *Tools → Install `nocturne` command in PATH*.
- **Explorer context menu.** *Tools → Add Typewriter Nocturne to system context menu* writes the *Open in
  Typewriter Nocturne* entry for folders and drives, pointing at the current executable. Opt-in, and the
  matching *Remove* item undoes it.
- **`ssh://` protocol.** Registered only when `defaultSSHApp` is `true` in your config (it defaults to
  `false`); setting it back to `false` removes the registration on the next launch.

All three point at the extracted folder, so they go stale if you move or delete it.

## Uninstalling (Windows)

`uninstall.cmd` sits beside `Typewriter Nocturne.exe`. Double-click it to clean up everything the app left
outside its own folder: the settings directory (`%APPDATA%\Typewriter Nocturne`, with plugins and caches),
the PATH entry, and any context-menu or `ssh://` registration pointing at this copy. It lists what it found
and asks before changing anything. Close the app first.

Registrations owned by a different extracted copy are left alone, so cleaning up an old version does not
break a new one. Everything it touches is per-user; no administrator rights are needed.

From a terminal in the extracted folder:

```powershell
.\uninstall.cmd -DryRun           # list what would be removed, change nothing
.\uninstall.cmd -KeepConfig       # keep settings and plugins
.\uninstall.cmd -Force            # skip the confirmation prompt
.\uninstall.cmd -RemoveAppFolder  # also delete the extracted folder itself
```

## Development builds are not code-signed

Signing needs paid certificates, which this project does not have yet. Unsigned builds behave differently
from signed ones, and this is expected:

**macOS.** The app is ad-hoc signed and not notarized. On first launch macOS says it cannot verify the
developer. Open *System Settings → Privacy & Security*, find the message about Typewriter Nocturne and choose
*Open Anyway*. Do not disable Gatekeeper system-wide.

**Windows.** SmartScreen shows "Windows protected your PC" when you run the extracted `Typewriter Nocturne.exe`.
Choose *More info → Run anyway* only after checking the SHA-256 checksum. Some antivirus products are stricter
with unsigned executables.

**Linux.** AppImage: `chmod +x` the file and run it. DEB: `sudo apt install ./Typewriter-Nocturne-*.deb`.

## Enabling signed builds (maintainers)

Add these repository secrets; the build picks them up automatically and otherwise stays unsigned:

| Secret | Purpose |
| --- | --- |
| `MAC_CERT_P12_BASE64`, `MAC_CERT_P12_PASSWORD` | Apple Developer ID Application certificate |
| `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD` | notarization |
| `WIN_CERT_P12_BASE64`, `WIN_CERT_P12_PASSWORD` | Windows Authenticode certificate |

## Configuration

Settings live in `~/.config/TypewriterNocturne/` (Windows: `%APPDATA%\Typewriter Nocturne\`) and never touch
an existing Hyper installation. The `nocturne` command-line helper can be added to your PATH from
*Tools → Install `nocturne` command in PATH*.
