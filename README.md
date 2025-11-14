# template-print

One-click macOS utility to underlay PDF templates (deposit slips, letterhead, forms) onto any PDF and print from the Print → PDF menu. Installs per-user via .pkg installer.

## Quickstart

1. **Download** the `template-print-*.pkg` installer from the [releases page](https://github.com/Black-Letter-Tech/template-print/releases)
2. **Double-click** the `.pkg` file to run the installer (no admin credentials required—installs to your account only)
3. **Add templates**: Place PDF templates in either:
   - `/Users/Shared/Shared PDF Templates/` (shared with all users)
   - `~/My PDF Templates/` (private to your account)
4. **Use**: Print in any macOS app → **PDF** menu → **Template Print**

**Note:** qpdf is bundled with the installer—no separate installation required.

The installer sets up everything in your user account—no conflicts with other users.

## How It Works

When you select **Template Print** from the Print → PDF menu:
1. A dialog shows all available templates (from both shared and private locations)
2. You select a template (last used template is pre-selected)
3. A dialog shows available printers (last used printer is pre-selected)
4. The PDF is composed with the template and sent to the printer

## Template Management

Templates are discovered from two locations:
- **Shared**: `/Users/Shared/Shared PDF Templates/` — accessible to all users
- **User-private**: `~/My PDF Templates/` — private to your account

Templates from both locations are merged and shown in a single chooser dialog. Place your templates in either location based on your needs.

## Preferences

Template Print remembers your choices:
- **Last template used** — automatically selected in the chooser
- **Last printer used** — automatically selected in the printer dialog

Preferences are stored in user defaults (`com.blacklettertech.template-print`) and are per-user.

## Installation Locations (User-Space)

All files are installed to your user account:
- Workflow: `~/Library/PDF Services/TemplatePrint.workflow`
- qpdf: `~/Library/Application Support/template-print/bin/qpdf`
- Uninstaller: `~/Applications/Template Print Uninstaller.app`

## Troubleshooting

- **Alignment off?** Confirm both template and print job share the same paper size.
- **Printer missing?** The printer selection dialog will show all available printers. If none appear, add a printer in System Settings.
- **No templates found?** Ensure at least one `.pdf` file exists in `/Users/Shared/Shared PDF Templates/` or `~/My PDF Templates/`.
- **Workflow not appearing?** Check `~/Library/PDF Services/TemplatePrint.workflow` exists and restart the print dialog.
- **qpdf error?** qpdf is bundled with the installer. If you see this error, try reinstalling the .pkg.

## Uninstallation

To uninstall Template Print:
- **Graphical**: Open `~/Applications/Template Print Uninstaller.app` and follow the prompts
- **Command line**: `rm -rf ~/Library/PDF\ Services/TemplatePrint.workflow ~/Library/Application\ Support/template-print ~/Applications/Template\ Print\ Uninstaller.app && defaults delete com.blacklettertech.template-print`

No sudo required—everything is in your user account.

## Development Workflow

- `make lint` – run `shellcheck` across all shell scripts.
- `make test` – run all tests (requires `bats-core`: `brew install bats-core`).
- `make test-unit` – run unit tests only.
- `make test-integration` – run integration tests only.
- `make prepare-qpdf` – build qpdf from source as universal binary and bundle dependencies (run periodically before `make pkg`). Requires `dylibbundler` (`brew install dylibbundler`).
- `make clean-qpdf` – remove bundled qpdf build artifacts.
- `make pkg` – build the macOS .pkg installer under `dist/`. Uses pre-bundled qpdf if available, otherwise falls back to system qpdf.
- `make archive` – produce a versioned tarball under `dist/` for releases.
- `make install-workflow` / `make uninstall-workflow` – manage the Automator bundle locally (development only).

**Building the installer:** Before running `make pkg`, run `make prepare-qpdf` to build and bundle qpdf from source as a universal binary. This ensures proper dependency isolation. The bundled qpdf is stored in `pkg/qpdf-bundled/` and can be reused for multiple builds.

## Security & Privacy

- Processing is fully local; PDFs never leave the machine.
- Temporary composites live in `mktemp` folders and are cleaned immediately after the `lp` job queues.
- No files are overwritten—input PDFs remain untouched.
- All installation and preferences are per-user—no system-wide changes.

## Next Steps (Release Prep)

- `make prepare-qpdf` to build universal qpdf binary
- `make pkg` to build the installer
- `git tag v0.1.0 && git push --tags`
- Create a GitHub release and attach `dist/template-print-*.pkg`
- Optionally sign and notarize the .pkg for distribution outside of GitHub
