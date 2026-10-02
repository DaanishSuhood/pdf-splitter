# PDF Splitter

Splits a PDF into several smaller PDFs, either at page numbers you name or in fixed-size chunks.
AutoHotkey cannot manipulate PDFs, so the script writes out a small Python helper and calls it.

Script: [`pdf-splitter.ahk`](pdf-splitter.ahk)

---

## Requirements

| Requirement | Notes |
| --- | --- |
| [AutoHotkey v2.0+](https://www.autohotkey.com/) | Declares `#Requires AutoHotkey v2.0` |
| Python 3 | The `python` command must be on `PATH` |
| `pypdf` | **Installed automatically** on first run by the helper, via `pip install pypdf` |

## Getting started

1. Run `pdf-splitter.ahk`.
2. **Browse…** to a PDF. The output folder is filled in for you as `Split_<filename>` next to the
   source.
3. Choose a **Split by** mode and fill in **Value**.
4. Click **Split!**

The first run also installs `pypdf`, so it takes noticeably longer than later runs.

## Split modes

| Mode | Value means | Example | Result |
| --- | --- | --- | --- |
| **Page numbers** | Comma-separated pages where a split occurs | `5,10,20` | `1-5` \| `6-10` \| `11-20` \| `21-end` |
| **Every N pages** | Chunk size | `5` | `1-5`, `6-10`, `11-15`, … |

The hint under the field restates this for the selected mode, and switching modes resets **Value** to
a sensible default (`5,10` or `5`).

Output files are named `part_001_pages_1-5.pdf`, `part_002_pages_6-10.pdf`, and so on, so the page
range is visible in the filename.

## The window

| Control | Purpose |
| --- | --- |
| **File** | The source PDF (read-only; use **Browse…**) |
| **Split by** | Mode dropdown |
| **Value** | Page list or chunk size |
| **Output** | Destination folder; created if missing. Defaults to `Split_<name>` beside the source |
| **Split!** | Runs the split |
| **Open Output** | Opens the output folder in Explorer |
| Progress bar / status line | Coarse progress and the helper's final message |

## How it works

On startup, `WritePythonHelper` writes an embedded Python script to
`%TEMP%\pdf_splitter_helper.py` — **only if that file does not already exist**. The helper:

1. Imports `pypdf`, `pip install`-ing it quietly if the import fails.
2. Reads the source with `PdfReader`, builds page boundaries for the chosen mode, and writes each
   range out with a fresh `PdfWriter`.
3. Prints a one-line summary, or `ERROR: <message>` on any exception.

The GUI runs `python "<helper>" --file … --mode pages|every --value … --out …` through `cmd.exe`
with stdout and stderr redirected to a temp file, reads that file back, and treats any output
containing `ERROR:` as a failure — shown in a message box with the helper's own text.

Page numbers outside the document are dropped rather than causing an error, and duplicates are
collapsed, so `3,3,999` on a 10-page file behaves like `3`.

## Limitations

- **The helper is cached.** If you edit the embedded Python in the `.ahk` file, delete
  `%TEMP%\pdf_splitter_helper.py` first or the old copy keeps being used.
- **No Python, no split.** If `python` is not on `PATH` the run fails with a `cmd.exe` message rather
  than a clear explanation. Note that a Microsoft Store Python stub can also intercept `python`.
- The first run needs a working internet connection for the `pip install`.
- The progress bar is decorative — it steps 20 → 50 → 90 → 100 around a single blocking `RunWait`
  rather than tracking real progress, and the GUI is frozen while the helper runs. There is no cancel.
- Existing `part_*.pdf` files in the output folder with the same names are overwritten.
- Splits at page boundaries only. Bookmarks, form fields, and attachments are not carried across —
  `pypdf` copies pages, not document-level structure.
- Encrypted / password-protected PDFs will fail with a `pypdf` error.
- The file's own header comment calls it `DocumentSplitter.ahk`; only PDFs are actually supported.
