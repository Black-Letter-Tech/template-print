# template-print

One-click macOS utility to underlay/overlay PDF templates (deposit slips, letterhead, forms) onto any PDF and print from the Print → PDF menu. Installs system-wide via .pkg installer.

## Quickstart

1. **Download** the `template-print-*.pkg` installer from the [releases page](https://github.com/Black-Letter-Tech/template-print/releases)
2. **Double-click** the `.pkg` file to run the installer (you'll be prompted for admin credentials)
3. **Add templates**: Example templates are installed to `/Users/Shared/PDFTemplates/examples/`. You can copy them: `cp /Users/Shared/PDFTemplates/examples/Sample\ Template.pdf /Users/Shared/PDFTemplates/Letterhead.pdf`
4. **Use**: Print in any macOS app → **PDF** menu → **Template Print**

**Note:** qpdf is bundled with the installer—no separate installation required.

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
- Uses bundled `qpdf` (included with installer); falls back to system/Homebrew qpdf if bundled version missing.
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
- No compositor found? qpdf is bundled with the installer. If you see this error, the bundled qpdf may be missing—try reinstalling the .pkg.
- Chooser empty? Ensure the directory contains at least one `.pdf` at the top level (subdirectories are ignored).
- Workflow not appearing? Check `/Library/PDF Services/TemplatePrint.workflow` exists and restart the print dialog.

## Uninstallation
To uninstall Template Print:
- **Graphical**: Open `/Applications/Utilities/Template Print Uninstaller.app` and follow the prompts
- **Command line**: `sudo rm -rf /usr/local/bin/template-print /Library/PDF\ Services/TemplatePrint.workflow /Users/Shared/PDFTemplates/examples /Library/Application\ Support/template-print /Applications/Utilities/Template\ Print\ Uninstaller.app`

## Development Workflow
- `make lint` – run `shellcheck` across all shell scripts.
- `make test` – run all tests (requires `bats-core`: `brew install bats-core`).
- `make test-unit` – run unit tests only.
- `make test-integration` – run integration tests only.
- `make install-dev` – install development symlinks (changes to source files are immediately available).
- `make uninstall-dev` – remove development symlinks.
- `make prepare-qpdf` – build qpdf from source and bundle dependencies (run periodically before `make pkg`). Requires `dylibbundler` (`brew install dylibbundler`).
- `make clean-qpdf` – remove bundled qpdf build artifacts.
- `make pkg` – build the macOS .pkg installer under `dist/`. Uses pre-bundled qpdf if available, otherwise falls back to system qpdf.
- `make archive` – produce a versioned tarball under `dist/` for releases.
- `make install-workflow` / `make uninstall-workflow` – manage the Automator bundle locally (development only).

**Building the installer:** Before running `make pkg`, run `make prepare-qpdf` to build and bundle qpdf from source. This ensures proper dependency isolation. The bundled qpdf is stored in `pkg/qpdf-bundled/` and can be reused for multiple builds.

## Security & Privacy
- Processing is fully local; PDFs never leave the machine.
- Temporary composites live in `mktemp` folders and are cleaned immediately after the `lp` job queues.
- No files are overwritten—input PDFs remain untouched.

## Next Steps (Release Prep)
- `make pkg` to build the installer
- `git tag v0.1.0 && git push --tags`
- Create a GitHub release and attach `dist/template-print-*.pkg`
- Optionally sign and notarize the .pkg for distribution outside of GitHub
