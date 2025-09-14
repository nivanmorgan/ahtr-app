#!/usr/bin/env python3
"""
Merge one or more Excel sheets into a single CSV compatible with scripts/import_csv.py.

Outputs CSV with columns: s3_key,title,artist,views,latitude,longitude

Usage:
  - Config-driven (recommended):
      python scripts/xlsx_to_import_csv.py \
        --xlsx "./Data for Transcarta app.xlsx" \
        --config ./data/mapping.yaml \
        --out ./out.csv

  - Auto-detect (best effort):
      python scripts/xlsx_to_import_csv.py --xlsx ./data.xlsx --out ./out.csv

Config format (YAML):
  sheets:
    - name: Images
      key: s3_key              # normalized key used to join
      columns:
        s3_key: S3 Key         # normalized_name: column header in that sheet
        title: Title
        artist: Artist
    - name: Geo
      key: s3_key
      columns:
        latitude: Latitude
        longitude: Longitude
    - name: Views
      key: s3_key
      columns:
        views: Views

Requires: pandas, openpyxl, pyyaml (local tooling; not needed in runtime image).
"""

from __future__ import annotations

import argparse
import sys
from typing import Dict, List, Optional

try:
    import pandas as pd  # type: ignore
except Exception:
    print("This script requires pandas. Install with: pip install pandas openpyxl pyyaml", file=sys.stderr)
    raise

try:
    import yaml  # type: ignore
except Exception:
    print("This script requires pyyaml. Install with: pip install pyyaml", file=sys.stderr)
    raise


TARGET_COLS = ["s3_key", "title", "artist", "views", "latitude", "longitude"]

SYNONYMS: Dict[str, List[str]] = {
    "s3_key": ["s3 key", "s3_key", "key", "path", "object key", "filename", "file", "image", "image key"],
    "title": ["title", "name"],
    "artist": ["artist", "author", "creator"],
    "views": ["views", "view", "tags", "labels"],
    "latitude": ["latitude", "lat"],
    "longitude": ["longitude", "lon", "long", "lng"],
}


def norm(s: str) -> str:
    return " ".join(str(s).strip().lower().replace("_", " ").split())


def autodetect_sheet(df: pd.DataFrame) -> Dict[str, str]:
    cols_norm = {norm(c): c for c in df.columns}
    mapping: Dict[str, str] = {}
    for target, candidates in SYNONYMS.items():
        for cand in candidates:
            key = norm(cand)
            if key in cols_norm:
                mapping[target] = cols_norm[key]
                break
    return mapping


def read_config(path: Optional[str]) -> Optional[dict]:
    if not path:
        return None
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def main() -> None:
    ap = argparse.ArgumentParser(description="Merge Excel sheets into importable CSV")
    ap.add_argument("--xlsx", required=True, help="Path to .xlsx file")
    ap.add_argument("--out", required=True, help="Output CSV path")
    ap.add_argument("--config", help="YAML mapping file (see data/mapping.example.yaml)")
    args = ap.parse_args()

    xl = pd.ExcelFile(args.xlsx)
    config = read_config(args.config)

    if config and "sheets" in config:
        merged: Optional[pd.DataFrame] = None
        join_key_global: Optional[str] = None
        for sheet_cfg in config["sheets"]:
            name = sheet_cfg.get("name")
            key = sheet_cfg.get("key")
            cols = sheet_cfg.get("columns", {})
            if not name or not key or not cols:
                raise SystemExit("Each sheet config must include name, key, and columns")
            df = xl.parse(sheet_name=name)
            # Build a tiny frame with selected columns
            selected = {}
            for tgt, src in cols.items():
                if src not in df.columns:
                    raise SystemExit(f"Column '{src}' not found in sheet '{name}'")
                selected[tgt] = df[src]
            if key not in cols and key not in selected:
                # If key is also a column header name
                if key in df.columns:
                    selected[key] = df[key]
                else:
                    raise SystemExit(f"Key '{key}' not present in mapping or sheet '{name}'")
            part = pd.DataFrame(selected)
            # Ensure join key exists
            if key not in part.columns:
                raise SystemExit(f"Join key '{key}' missing after selection for sheet '{name}'")
            # Deduplicate within sheet on key, aggregating views where necessary
            if "views" in part.columns:
                part["views"] = part["views"].astype(str).fillna("")
                agg = {c: "first" for c in part.columns}
                agg["views"] = lambda s: ",".join(sorted(set(
                    x.strip() for v in s for x in str(v).replace(";", ",").split(",") if x.strip()
                )))
                part = part.groupby(key, as_index=False).agg(agg)
            else:
                part = part.drop_duplicates(subset=[key])

            # Merge into global
            if merged is None:
                merged = part
                join_key_global = key
            else:
                if key != join_key_global:
                    # Align key name if different: rename to join key
                    part = part.rename(columns={key: join_key_global})
                    key = join_key_global
                merged = pd.merge(merged, part, on=key, how="outer")

        assert merged is not None
        # Normalize output columns and types
        out = pd.DataFrame()
        out["s3_key"] = merged.get("s3_key", pd.Series(dtype=str)).astype(str).str.strip()
        out["title"] = merged.get("title", pd.Series(dtype=str)).astype(str).fillna("").str.strip()
        out["artist"] = merged.get("artist", pd.Series(dtype=str)).astype(str).fillna("").str.strip()
        views_series = merged.get("views", pd.Series(dtype=str)).astype(str).fillna("")
        # Re-normalize views separators and dedupe
        def norm_views(v: str) -> str:
            tokens = [x.strip() for x in str(v).replace(";", ",").split(",") if x.strip()]
            return ",".join(sorted(set(tokens)))
        out["views"] = views_series.map(norm_views)
        out["latitude"] = pd.to_numeric(merged.get("latitude", pd.Series(dtype=float)), errors="coerce")
        out["longitude"] = pd.to_numeric(merged.get("longitude", pd.Series(dtype=float)), errors="coerce")

        out = out[TARGET_COLS]
        out.to_csv(args.out, index=False)
        print(f"Wrote {len(out)} rows to {args.out}")
        return

    # Auto-detect across all sheets (best-effort)
    frames: List[pd.DataFrame] = []
    for name in xl.sheet_names:
        df = xl.parse(sheet_name=name)
        mapping = autodetect_sheet(df)
        if not mapping:
            continue
        # Select any matching columns
        sel = {k: df[v] for k, v in mapping.items()}
        part = pd.DataFrame(sel)
        frames.append(part)

    if not frames:
        raise SystemExit("Could not auto-detect any useful columns in the workbook. Provide a --config mapping.")

    merged = pd.concat(frames, ignore_index=True)
    # Aggregate duplicate rows on s3_key if present
    if "s3_key" in merged.columns:
        if "views" in merged.columns:
            merged["views"] = merged["views"].astype(str).fillna("")
            agg = {c: "first" for c in merged.columns}
            agg["views"] = lambda s: ",".join(sorted(set(
                x.strip() for v in s for x in str(v).replace(";", ",").split(",") if x.strip()
            )))
            merged = merged.groupby("s3_key", as_index=False).agg(agg)
        else:
            merged = merged.drop_duplicates(subset=["s3_key"])
    # Build final CSV
    out = pd.DataFrame()
    for col in TARGET_COLS:
        if col in ("latitude", "longitude"):
            out[col] = pd.to_numeric(merged.get(col, pd.Series(dtype=float)), errors="coerce")
        else:
            out[col] = merged.get(col, pd.Series(dtype=str)).astype(str).fillna("").str.strip()
    out = out[TARGET_COLS]
    out.to_csv(args.out, index=False)
    print(f"Wrote {len(out)} rows to {args.out}")


if __name__ == "__main__":
    main()

