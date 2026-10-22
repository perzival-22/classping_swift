# doc-extract.py: used by doc-check.sh. Writes the "### 4.N" Swift blocks of a phase doc into a folder.
import re, sys, pathlib
md = pathlib.Path(sys.argv[1]).read_text()
dest = pathlib.Path(sys.argv[2])
pat = re.compile(r"^### 4\.\d+ `~/ClassPing/Sources/ClassPing/([^`]+)`[^\n]*\n(?:(?!^### ).)*?```swift\n(.*?)\n```", re.S | re.M)
n = 0
for m in pat.finditer(md):
    p = dest / m.group(1)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(m.group(2) + "\n")
    n += 1
    print("wrote", m.group(1))
print(n, "files")
