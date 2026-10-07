#!/usr/bin/env bash
#
# subset_fonts.sh — acquire, instantiate and subset OFL fonts for PDF embedding.
#
# Produces static, glyf-based TrueType (.ttf) subsets into assets/fonts/:
#   NotoSansSC-Regular.ttf  NotoSansSC-Bold.ttf
#   NotoSerifSC-Regular.ttf NotoSerifSC-Bold.ttf
#   Inter-Regular.ttf       Inter-Bold.ttf
#   EBGaramond-Regular.ttf  EBGaramond-Bold.ttf
#
# The Dart `pdf` package requires plain static TrueType (sfnt/glyf), not .ttc,
# not .woff2, and not CFF-flavoured OpenType. Noto Serif SC upstream only ships
# a >20 MB variable TTF (rejected by jsDelivr's 20 MB file limit) plus static
# CFF OTFs, so those are subset first and then converted CFF -> glyf.
#
# CJK charset is intentionally compact: the GB2312 hanzi set (6763 chars) plus
# Latin/punctuation/kana ranges (~8.5k glyphs total). Rare glyphs omitted here
# are covered at runtime by assets/fonts/DroidSansFallbackFull.ttf.
#
# Network note: only cdn.jsdelivr.net is reachable; raw.githubusercontent.com is
# blocked. pypi.org is reachable (the tuna mirror is NOT).
#
# Usage:  bash tool/subset_fonts.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO_ROOT/assets/fonts"
WORK="$(mktemp -d)"
VENV="$WORK/venv"
JSD="https://cdn.jsdelivr.net/gh"
GFONTS="$JSD/google/fonts@main"
NOTOCJK="$JSD/notofonts/noto-cjk@main"

# Unicode ranges to retain.
# CJK fonts keep Latin/punctuation + kana ranges directly, PLUS the GB2312
# hanzi set (6763 chars) supplied via a --text-file generated below. Rare
# glyphs left out are covered at runtime by assets/fonts/DroidSansFallbackFull.ttf.
CJK_EXTRA="U+0000-024F,U+2000-206F,U+20A0-20CF,U+2190-21FF,U+2460-24FF,U+25A0-25FF,U+2600-26FF,U+3000-303F,U+3040-30FF,U+FF00-FFEF"
LATIN="U+0000-024F,U+2000-206F,U+20A0-20CF,U+2100-214F,U+2190-21FF,U+2460-24FF,U+25A0-25FF,U+2600-26FF"
SUBFLAGS=(--layout-features='*' --glyph-names --symbol-cmap --legacy-cmap \
          --notdef-glyph --notdef-outline --recommended-glyphs \
          --name-IDs='*' --name-legacy --name-languages='*')

echo "==> workspace: $WORK"
mkdir -p "$WORK" "$WORK/inst" "$WORK/subset" "$DEST"

# GB2312 hanzi set (6763 chars): decode every valid 2-byte GB2312 code.
GB2312_TXT="$WORK/gb2312.txt"
python3 - "$GB2312_TXT" <<'PYEOF'
import sys
chars = set()
for h in range(0xB0, 0xF8):
    for l in range(0xA1, 0xFF):
        try:
            chars.add(bytes([h, l]).decode('gb2312'))
        except Exception:
            pass
with open(sys.argv[1], 'w', encoding='utf-8') as f:
    f.write(''.join(sorted(chars)))
print("gb2312 chars:", len(chars))
PYEOF

# ---------------------------------------------------------------------------
# 0. Tooling
# ---------------------------------------------------------------------------
python3 -m venv "$VENV"
"$VENV/bin/pip" install -q fonttools
PY="$VENV/bin/python"
SUBSET="$VENV/bin/pyftsubset"

# CFF -> glyf converter (fontTools ships it only as a Snippet).
curl -fsSL -o "$WORK/otf2ttf.py" \
  "$JSD/fonttools/fonttools@main/Snippets/otf2ttf.py"

# ---------------------------------------------------------------------------
# 1. Download upstream variable fonts + Serif SC static OTFs + licenses
# ---------------------------------------------------------------------------
cd "$WORK"
curl -fsSL -o "NotoSansSC[wght].ttf"  "$GFONTS/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf"
curl -fsSL -o "Inter[opsz,wght].ttf" "$GFONTS/ofl/inter/Inter%5Bopsz,wght%5D.ttf"
curl -fsSL -o "EBGaramond[wght].ttf" "$GFONTS/ofl/ebgaramond/EBGaramond%5Bwght%5D.ttf"
# Noto Serif SC variable TTF is >20 MB and returns HTTP 403 from jsDelivr;
# use the static CFF (OTF) instances and convert the subset to glyf below.
curl -fsSL -o "NotoSerifSC-Regular.otf" "$NOTOCJK/Serif/SubsetOTF/SC/NotoSerifSC-Regular.otf"
curl -fsSL -o "NotoSerifSC-Bold.otf"    "$NOTOCJK/Serif/SubsetOTF/SC/NotoSerifSC-Bold.otf"
for fam in notosanssc notoserifsc inter ebgaramond; do
  curl -fsSL -o "OFL-$fam.txt" "$GFONTS/ofl/$fam/OFL.txt"
done

# ---------------------------------------------------------------------------
# 2. Instantiate static weights (varLib.instancer)
#    wght=400 / wght=700; Inter also pins opsz=14.
# ---------------------------------------------------------------------------
inst() { "$PY" -m fontTools.varLib.instancer -o "$1" "$2" "${@:3}"; }
inst "inst/NotoSansSC-Regular.ttf"  "NotoSansSC[wght].ttf"  wght=400
inst "inst/NotoSansSC-Bold.ttf"     "NotoSansSC[wght].ttf"  wght=700
inst "inst/Inter-Regular.ttf"       "Inter[opsz,wght].ttf" opsz=14 wght=400
inst "inst/Inter-Bold.ttf"          "Inter[opsz,wght].ttf" opsz=14 wght=700
inst "inst/EBGaramond-Regular.ttf"  "EBGaramond[wght].ttf" wght=400
inst "inst/EBGaramond-Bold.ttf"     "EBGaramond[wght].ttf" wght=700

# ---------------------------------------------------------------------------
# 3. Subset the TrueType instances
# ---------------------------------------------------------------------------
for w in Regular Bold; do
  "$SUBSET" "inst/NotoSansSC-$w.ttf"  --unicodes="$CJK_EXTRA" --text-file="$GB2312_TXT" "${SUBFLAGS[@]}" --output-file="subset/NotoSansSC-$w.ttf"
  "$SUBSET" "inst/Inter-$w.ttf"       --unicodes="$LATIN" "${SUBFLAGS[@]}" --output-file="subset/Inter-$w.ttf"
  "$SUBSET" "inst/EBGaramond-$w.ttf"  --unicodes="$LATIN" "${SUBFLAGS[@]}" --output-file="subset/EBGaramond-$w.ttf"
done

# ---------------------------------------------------------------------------
# 4. Noto Serif SC: subset the CFF OTF, then convert subset CFF -> glyf TTF
# ---------------------------------------------------------------------------
for w in Regular Bold; do
  "$SUBSET" "NotoSerifSC-$w.otf" --unicodes="$CJK_EXTRA" --text-file="$GB2312_TXT" "${SUBFLAGS[@]}" --output-file="subset/NotoSerifSC-$w.otf"
  "$PY" "$WORK/otf2ttf.py" -o "subset/NotoSerifSC-$w.ttf" "subset/NotoSerifSC-$w.otf"
done

# ---------------------------------------------------------------------------
# 5. Install final fonts into assets/fonts/
# ---------------------------------------------------------------------------
for w in Regular Bold; do
  cp "subset/NotoSansSC-$w.ttf"  "$DEST/NotoSansSC-$w.ttf"
  cp "subset/NotoSerifSC-$w.ttf" "$DEST/NotoSerifSC-$w.ttf"
  cp "subset/Inter-$w.ttf"       "$DEST/Inter-$w.ttf"
  cp "subset/EBGaramond-$w.ttf"  "$DEST/EBGaramond-$w.ttf"
done
chmod 644 "$DEST"/NotoSansSC-*.ttf "$DEST"/NotoSerifSC-*.ttf "$DEST"/Inter-*.ttf "$DEST"/EBGaramond-*.ttf

# ---------------------------------------------------------------------------
# 6. Aggregate the OFL notices
# ---------------------------------------------------------------------------
{
  for pair in "Noto Sans SC:notosanssc" "Noto Serif SC:notoserifsc" "Inter:inter" "EB Garamond:ebgaramond"; do
    name="${pair%%:*}"; slug="${pair##*:}"
    echo "================================================================================"
    echo "$name"
    echo "Source: $GFONTS/ofl/$slug/OFL.txt"
    echo "================================================================================"
    cat "OFL-$slug.txt"
    echo; echo
  done
  echo "This file aggregates the SIL Open Font License 1.1 notices for all fonts bundled in assets/fonts/."
  echo
} > "$DEST/OFL.txt"

# ---------------------------------------------------------------------------
# 7. Verify every produced font opens with fontTools and has glyphs
# ---------------------------------------------------------------------------
"$PY" - "$DEST" <<'PYEOF'
import sys, os, glob
from fontTools.ttLib import TTFont
dest = sys.argv[1]
ok = True
for f in sorted(glob.glob(os.path.join(dest, "*.ttf"))):
    base = os.path.basename(f)
    if base.startswith("Droid"):
        continue
    t = TTFont(f)
    nglyphs = len(t.getGlyphOrder())
    is_tt = t.sfntVersion == "\x00\x01\x00\x00" and "glyf" in t
    extra = ""
    if base.startswith(("NotoSansSC", "NotoSerifSC")):
        cmap = t.getBestCmap()
        has_chang = ord("常") in cmap   # in GB2312
        has_da = ord("龘") in cmap      # rare, must be absent
        extra = f" 常={has_chang} 龘={has_da}"
        if not has_chang or has_da:
            ok = False
    print(f"{base:26s} {os.path.getsize(f):>9d} B  glyphs={nglyphs:6d}  glyf={is_tt}{extra}")
    if nglyphs <= 0 or not is_tt:
        ok = False
if not ok:
    sys.exit("verification failed")
PYEOF

echo "==> done. Fonts written to $DEST"
