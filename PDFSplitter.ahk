; ============================================================
;  DocumentSplitter.ahk  —  AHK v2
;  Splits PDF files by page numbers or every N pages.
;  Requires Python 3 + pypdf (auto-installed on first run).
; ============================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

; ── Constants ────────────────────────────────────────────────
TITLE     := "PDF Splitter"
PY_SCRIPT := A_Temp "\pdf_splitter_helper.py"

; ── Build Python helper on disk ──────────────────────────────
WritePythonHelper(PY_SCRIPT)

; ── GUI ──────────────────────────────────────────────────────
MyGui := Gui(, TITLE)
MyGui.SetFont("s10", "Segoe UI")
MyGui.OnEvent("Close", (*) => ExitApp())

; File row
MyGui.Add("Text",  "xm y12 w80 h23 +0x200", "File:")
edFile := MyGui.Add("Edit", "x100 y12 w380 h23 vFilePath ReadOnly")
MyGui.Add("Button", "x488 y10 w80 h27", "Browse…").OnEvent("Click", BrowseFile)

; Split-type row
MyGui.Add("Text",  "xm y50 w80 h23 +0x200", "Split by:")
ddType := MyGui.Add("DropDownList", "x100 y50 w200 vSplitType",
    ["Page numbers (e.g. 3,7,12)",
     "Every N pages"])
ddType.Value := 1
ddType.OnEvent("Change", UpdateHint)

; Value row
MyGui.Add("Text",  "xm y88 w80 h23 +0x200", "Value:")
edVal := MyGui.Add("Edit", "x100 y88 w200 h23 vSplitValue")

; Hint label
lblHint := MyGui.Add("Text", "x100 y116 w460 h36 cGray", "")
UpdateHint()

; Output folder row
MyGui.Add("Text",  "xm y158 w80 h23 +0x200", "Output:")
edOut := MyGui.Add("Edit", "x100 y158 w380 h23 vOutFolder ReadOnly")
MyGui.Add("Button", "x488 y156 w80 h27", "Browse…").OnEvent("Click", BrowseOutput)

; Progress / status
pbStatus := MyGui.Add("Progress", "xm y198 w460 h18 -Smooth Range0-100 Hidden")
lblStatus := MyGui.Add("Text",    "xm y220 w570 h20 cGray", "Ready.")

; Action buttons
MyGui.Add("Button", "xm y250 w100 h32 Default", "Split!").OnEvent("Click", DoSplit)
MyGui.Add("Button", "x120 y250 w100 h32", "Open Output").OnEvent("Click", OpenOutput)
MyGui.Add("Button", "x490 y250 w80 h32",  "Exit").OnEvent("Click", (*) => ExitApp())

MyGui.Show("w580 h295")

; ── Hint text per split type ─────────────────────────────────
UpdateHint(*) {
    global ddType, lblHint, edVal
    hints := [
        "Enter page numbers where splits occur. E.g.  5,10,20  → parts: 1-5 | 6-10 | 11-20 | 21-end",
        "Enter chunk size N. E.g.  5  → part_001 has pages 1-5, part_002 has 6-10, …"
    ]
    lblHint.Text := hints[ddType.Value]
    defaults := ["5,10", "5"]
    edVal.Value := defaults[ddType.Value]
}

; ── Browse helpers ────────────────────────────────────────────
BrowseFile(*) {
    global edFile, edOut
    f := FileSelect(3,, "Select a PDF file", "PDF Files (*.pdf)")
    if f {
        edFile.Value := f
        SplitPath f, &name, &dir
        SplitPath name, , , , &stem
        edOut.Value := dir "\" "Split_" stem
    }
}

BrowseOutput(*) {
    global edOut
    d := DirSelect(, 3, "Choose output folder")
    if d
        edOut.Value := d
}

OpenOutput(*) {
    global edOut
    d := edOut.Value
    if d && DirExist(d)
        Run "explorer.exe " Chr(34) d Chr(34)
    else
        MsgBox "Output folder does not exist yet. Run a split first.", TITLE, 48
}

; ── Main split action ─────────────────────────────────────────
DoSplit(*) {
    global edFile, ddType, edVal, edOut, pbStatus, lblStatus, PY_SCRIPT, TITLE

    filePath  := edFile.Value
    splitType := ddType.Value
    splitVal  := Trim(edVal.Value)
    outFolder := Trim(edOut.Value)

    if !filePath {
        MsgBox "Please select a file first.", TITLE, 48
        return
    }
    if !FileExist(filePath) {
        MsgBox "File not found:`n" filePath, TITLE, 16
        return
    }
    if splitVal = "" {
        MsgBox "Please enter a split value.", TITLE, 48
        return
    }
    if outFolder = "" {
        MsgBox "Please choose an output folder.", TITLE, 48
        return
    }

    SplitPath filePath, , , &ext
    if StrLower(ext) != "pdf" {
        MsgBox "Please select a PDF file.", TITLE, 48
        return
    }

    if !DirExist(outFolder)
        DirCreate outFolder

    pbStatus.Visible := true
    pbStatus.Value   := 20
    lblStatus.Text   := "Installing dependencies & splitting…"
    Sleep 50

    modeMap := Map(1, "pages", 2, "every")
    mode := modeMap[splitType]

    cmd := 'python "' PY_SCRIPT '" '
         . '--file "'   filePath  '" '
         . '--mode '    mode       ' '
         . '--value "'  splitVal  '" '
         . '--out "'    outFolder '"'

    pbStatus.Value := 50
    result := RunAndCapture(cmd)
    pbStatus.Value := 90

    if InStr(result, "ERROR:") {
        pbStatus.Visible := false
        lblStatus.Text   := "Error — see details."
        MsgBox "Split failed:`n`n" result, TITLE, 16
        return
    }

    pbStatus.Value   := 100
    lblStatus.Text   := "Done!  " result
    Sleep 300
    pbStatus.Visible := false
    MsgBox result "`n`nOutput folder:`n" outFolder, TITLE, 64
}

; ── Run a command and capture stdout+stderr ───────────────────
RunAndCapture(cmd) {
    tmpOut := A_Temp "\pdf_splitter_out.txt"
    RunWait A_ComSpec ' /C ' cmd ' > "' tmpOut '" 2>&1',, "Hide"
    out := ""
    try out := FileRead(tmpOut)
    try FileDelete(tmpOut)
    return Trim(out)
}

; ── Embed the Python helper ───────────────────────────────────
WritePythonHelper(path) {
    code := '
(
import sys, os, re, subprocess, argparse

def ensure(pkg, import_as=None):
    import importlib
    mod = import_as or pkg
    try:
        importlib.import_module(mod)
    except ImportError:
        subprocess.check_call([sys.executable, "-m", "pip", "install", pkg,
                               "--quiet", "--disable-pip-version-check"])

ensure("pypdf")

def split_pdf_pages(src, values, out_dir):
    from pypdf import PdfReader, PdfWriter
    reader = PdfReader(src)
    total  = len(reader.pages)
    breaks = sorted(set(int(v.strip()) for v in values.split(",") if v.strip().isdigit()))
    boundaries = [0] + [b for b in breaks if 0 < b < total] + [total]
    count = 0
    for i in range(len(boundaries) - 1):
        s, e = boundaries[i], boundaries[i+1]
        w = PdfWriter()
        for p in range(s, e):
            w.add_page(reader.pages[p])
        out = os.path.join(out_dir, f"part_{i+1:03d}_pages_{s+1}-{e}.pdf")
        with open(out, "wb") as f:
            w.write(f)
        count += 1
    return count, total

def split_pdf_every(src, n, out_dir):
    from pypdf import PdfReader, PdfWriter
    reader = PdfReader(src)
    total  = len(reader.pages)
    n = max(1, int(n))
    count = 0
    for start in range(0, total, n):
        end = min(start + n, total)
        w = PdfWriter()
        for p in range(start, end):
            w.add_page(reader.pages[p])
        out = os.path.join(out_dir, f"part_{count+1:03d}_pages_{start+1}-{end}.pdf")
        with open(out, "wb") as f:
            w.write(f)
        count += 1
    return count, total

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--file");  ap.add_argument("--mode")
    ap.add_argument("--value"); ap.add_argument("--out")
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)

    try:
        if args.mode == "pages":
            n, total = split_pdf_pages(args.file, args.value, args.out)
            print(f"Split into {n} parts  ({total} pages total).")
        elif args.mode == "every":
            n, total = split_pdf_every(args.file, args.value, args.out)
            print(f"Split into {n} parts of {args.value} pages each  ({total} pages total).")
        else:
            print(f"ERROR: Unknown mode {args.mode}")
    except Exception as ex:
        print(f"ERROR: {ex}")

if __name__ == "__main__":
    main()
)'

    if !FileExist(path)
        FileAppend code, path, "UTF-8"
}
