# template-print

One-click macOS utility to underlay/overlay PDF templates (deposit slips, letterhead, forms) onto any PDF and print from the Print → PDF menu. Installs system-wide via .pkg installer.

## Quickstart

1. **Download** the `template-print-*.pkg` installer from the [releases page](https://github.com/Black-Letter-Tech/template-print/releases)
2. **Double-click** the `.pkg` file to run the installer (you'll be prompted for admin credentials)
3. **Install** `qpdf` if not already installed: `brew install qpdf` or `sudo port install qpdf`
4. **Add templates**: Example templates are installed to `/Users/Shared/PDFTemplates/examples/`. You can copy them: `cp /Users/Shared/PDFTemplates/examples/Sample\ Template.pdf /Users/Shared/PDFTemplates/Letterhead.pdf`
5. **Use**: Print in any macOS app → **PDF** menu → **Template Print**

The installer sets up everything system-wide—all users on the machine will have access to Template Print after a single admin installation.

## CLI Overview
```
template-print [options] <pdf>
```

Key flags:
- `-t, --template PATH` pick a specific PDF template.
- `-d, --dir DIR` template directory (default `/Users/Shared/PDFTemplates`).
- `TEMPLATE_PRINT_DIR` environment variable can override the default directory globally.
- `-m, --mode underlay|overlay` layering mode (default `underlay`).
- `-p, --printer NAME` override the destination printer.
- `-c, --choose` launch an AppleScript chooser (defaults to the last template).
- `-r, --remember 0|1` toggle persistence of the last template (`1` by default).
- `-l, --list` list the available templates and exit.
- `--version`, `-h`, `--help` standard metadata.

Behavior highlights:
- Requires `qpdf`; exits with a dialog if it is missing.
- Stores chooser history in `defaults write com.blacklettertech.template-print lastTemplatePath`.
- Prints through `lp` with `media=Letter`, `sides=one-sided`, `fit-to-page`.
- Errors loudly (and via dialog) when prerequisites or templates are missing.

## Automator Print Plugin
- Bundle: `workflow/TemplatePrint.workflow`
- Installs to `/Library/PDF Services/TemplatePrint.workflow` (system-wide) via the .pkg installer
- Inside the print dialog, open the **PDF** drop-down and choose **Template Print**; each invocation launches the CLI with `--choose`
- Available to all users after a single admin installation

## Template Management
- Drop organisation-wide templates into `/Users/Shared/PDFTemplates` so all users can access and share them.
- Provide per-user overrides by pointing `--dir` (or `TEMPLATE_PRINT_DIR`) at another location.
- Example templates are installed to `/Users/Shared/PDFTemplates/examples/`—use these as a starting point and edit them in Preview or Acrobat to align with your brand.

## Troubleshooting
- Alignment off? Confirm both template and print job share the same paper size. Pass a different default with `lp` options (`--lp-arg "-o media=A4"` coming soon).
- Printer missing? Check `lpstat -p` and pass `--printer` explicitly.
- No compositor found? Install `qpdf` with `brew install qpdf` or `sudo port install qpdf`.
- Chooser empty? Ensure the directory contains at least one `.pdf` at the top level (subdirectories are ignored).
- Workflow not appearing? Check `/Library/PDF Services/TemplatePrint.workflow` exists and restart the print dialog.
- Apple Silicon vs Intel? `template-print` checks `/opt/homebrew` first, then `/usr/local` for `qpdf`.

## Uninstallation
To uninstall Template Print:
- **Graphical**: Open `/Applications/Utilities/Template Print Uninstaller.app` and follow the prompts
- **Command line**: `sudo rm -rf /usr/local/bin/template-print /Library/PDF\ Services/TemplatePrint.workflow /Users/Shared/PDFTemplates/examples /Applications/Utilities/Template\ Print\ Uninstaller.app`

## Development Workflow
- `make lint` – run `shellcheck` across all shell scripts.
- `make pkg` – build the macOS .pkg installer under `dist/`.
- `make archive` – produce a versioned tarball under `dist/` for releases.
- `make install-workflow` / `make uninstall-workflow` – manage the Automator bundle locally (development only).

## Security & Privacy
- Processing is fully local; PDFs never leave the machine.
- Temporary composites live in `mktemp` folders and are cleaned immediately after the `lp` job queues.
- No files are overwritten—input PDFs remain untouched.

## Next Steps (Release Prep)
- `make pkg` to build the installer
- `git tag v0.1.0 && git push --tags`
- Create a GitHub release and attach `dist/template-print-*.pkg`
- Optionally sign and notarize the .pkg for distribution outside of GitHub
