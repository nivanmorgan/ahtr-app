#!/usr/bin/env python3
"""
Convert an Excel spreadsheet to the CSV format expected by scripts/import_csv.py.

Expected CSV headers:
  s3_key,title,artist,views,latitude,longitude

Usage examples:
  python scripts/convert_xlsx_to_csv.py --xlsx ./data.xlsx --out ./out.csv \
    --sheet "Sheet1" --col-s3-key "S3 Key" --col-title Title --col-artist Artist \
    --col-views Views --col-latitude Latitude --col-longitude Longitude

Auto-detection tries common synonyms if --col-* flags are omitted.
Requires: pandas, openpyxl (install locally: pip install pandas openpyxl)
"""

import argparse
import sys
from typing import Dict, Optional

try:
    import pandas as pd  # type: ignore
except Exception as exc:  # pragma: no cover
    print("This script requires pandas. Install with: pip install pandas openpyxl", file=sys.stderr)
    raise


DEFAULT_HEADERS = ["s3_key", "title", "artist", "views", "latitude", "longitude"]

SYNONYMS: Dict[str, list[str]] = {
    "s3_key": ["s3_key", "s3 key", "key", "path", "object key", "filename", "file", "image", "image key"],
    "title": ["title", "name"],
    "artist": ["artist", "author", "creator"],
    "views": ["views", "view", "tags", "labels"],
    "latitude": ["latitude", "lat"],
    "longitude": ["longitude", "lon", "long", "lng"],
}


def normalize(s: str) -> str:
    return " ".join(s.strip().lower().replace("_", " ").split())


def auto_map_columns(df: "pd.DataFrame", overrides: Dict[str, Optional[str]]) -> Dict[str, str]:
    columns_norm = {normalize(c): c for c in df.columns}
    mapping: Dict[str, str] = {}

    for target in DEFAULT_HEADERS:
        override = overrides.get(target)
        if override:
            if override not in df.columns:
                raise SystemExit(f"Override column '{override}' not found in sheet")
            mapping[target] = override
            continue
        # Try synonyms
        for cand in SYNONYMS[target]:
            key = normalize(cand)
            if key in columns_norm:
                mapping[target] = columns_norm[key]
                break
        # Optional fields latitude/longitude/views may be missing
        if target not in mapping and target in ("latitude", "longitude", "views"):
            continue
        if target not in mapping:
            raise SystemExit(f"Could not auto-detect column for '{target}'. Use --col-{target} to specify.")

    return mapping


def main() -> None:
    ap = argparse.ArgumentParser(description="Convert Excel to CSV for import")
    ap.add_argument("--xlsx", required=True, help="Path to .xlsx file")
    ap.add_argument("--out", required=True, help="Output CSV path")
    ap.add_argument("--sheet", default=None, help="Worksheet name (default: first)")
    # Column overrides
    ap.add_argument("--col-s3-key", dest="s3_key", default=None)
    ap.add_argument("--col-title", dest="title", default=None)
    ap.add_argument("--col-artist", dest="artist", default=None)
    ap.add_argument("--col-views", dest="views", default=None)
    ap.add_argument("--col-latitude", dest="latitude", default=None)
    ap.add_argument("--col-longitude", dest="longitude", default=None)
    args = ap.parse_args()

    # Load sheet
    xl = pd.ExcelFile(args.xlsx)
    sheet_name = args.sheet or xl.sheet_names[0]
    df = xl.parse(sheet_name=sheet_name)

    overrides = {
        "s3_key": args.s3_key,
        "title": args.title,
        "artist": args.artist,
        "views": args.views,
        "latitude": args.latitude,
        "longitude": args.longitude,
    }
    mapping = auto_map_columns(df, overrides)

    out_df = pd.DataFrame()
    out_df["s3_key"] = df[mapping["s3_key"]].astype(str).str.strip()
    out_df["title"] = df[mapping["title"]].astype(str).str.strip() if "title" in mapping else ""
    out_df["artist"] = df[mapping["artist"]].astype(str).str.strip() if "artist" in mapping else ""

    if "views" in mapping:
        out_df["views"] = df[mapping["views"]].astype(str).fillna("").str.strip()
    else:
        out_df["views"] = ""

    if "latitude" in mapping:
        out_df["latitude"] = pd.to_numeric(df[mapping["latitude"]], errors="coerce")
    else:
        out_df["latitude"] = None

    if "longitude" in mapping:
        out_df["longitude"] = pd.to_numeric(df[mapping["longitude"]], errors="coerce")
    else:
        out_df["longitude"] = None

    out_df.to_csv(args.out, index=False)
    print(f"Wrote {len(out_df)} rows to {args.out}")


if __name__ == "__main__":
    main()

