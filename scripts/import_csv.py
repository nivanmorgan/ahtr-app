import argparse
import csv
import os
import tempfile
from urllib.parse import urlparse
import boto3
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.models import Artist, Image, ImageView
from app.db import Base


def get_session(db_url: str):
    engine = create_engine(db_url)
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    return Session()


def main():
    parser = argparse.ArgumentParser(description="Import images from CSV into the database")
    parser.add_argument("--csv", required=True, help="Path to CSV file (local path or s3://bucket/key)")
    parser.add_argument("--db", default=os.getenv("POSTGRES_URL"), help="Database URL")
    args = parser.parse_args()

    if not args.db:
        raise SystemExit("Database URL not provided. Use --db or set POSTGRES_URL.")

    session = get_session(args.db)
    created = 0

    csv_path = args.csv
    temp_file = None
    if csv_path.startswith("s3://"):
        parsed = urlparse(csv_path)
        bucket = parsed.netloc
        key = parsed.path.lstrip("/")
        s3 = boto3.client("s3")
        fd, tmp = tempfile.mkstemp(prefix="import_", suffix=".csv")
        os.close(fd)
        s3.download_file(bucket, key, tmp)
        csv_path = tmp
        temp_file = tmp

    with open(csv_path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            artist_name = (row.get("artist") or "").strip()
            artist = None
            if artist_name:
                artist = session.query(Artist).filter(Artist.name == artist_name).first()
                if not artist:
                    artist = Artist(name=artist_name)
                    session.add(artist)
                    session.flush()

            # Persist only mapped fields on the current Image model
            img = Image(
                s3_key=row.get("s3_key"),
                title=row.get("title"),
                artist_id=artist.id if artist else None,
            )
            session.add(img)
            session.flush()

            views_field = row.get("views") or ""
            views = [v.strip() for v in views_field.replace(";", ",").split(",") if v.strip()]
            for v in views:
                session.add(ImageView(image_id=img.id, view=v))

            created += 1

    session.commit()
    print(f"Imported {created} images")

    if temp_file and os.path.exists(temp_file):
        os.remove(temp_file)


if __name__ == "__main__":
    main()
