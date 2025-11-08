"""
Geocode existing images in the database by populating latitude, longitude, and location_name fields.

Usage:
    python scripts/geocode_existing_images.py --db postgresql://user:pass@host:5432/dbname
    
Or with environment variable:
    export POSTGRES_URL="postgresql://..."
    python scripts/geocode_existing_images.py
"""
import sys
import os
import json
import time
import argparse
from pathlib import Path

# Add parent directory to path so we can import app modules
sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.models import Image
from app.services.geocoding import geocode_location


def load_location_mapping(mapping_file='data/artwork_locations.json'):
    """Load the artwork → location name mapping from JSON file."""
    mapping_path = Path(__file__).parent.parent / mapping_file
    
    if not mapping_path.exists():
        print(f"⚠️  Warning: Location mapping file not found at {mapping_path}")
        return {}
    
    with open(mapping_path, 'r') as f:
        mapping = json.load(f)
    
    print(f"📍 Loaded {len(mapping)} location mappings")
    return mapping


def geocode_images(db_url, dry_run=False, batch_size=10):
    """
    Geocode all images missing coordinates.
    
    Args:
        db_url: PostgreSQL connection string
        dry_run: If True, don't actually update database
        batch_size: Number of images to process before committing
    """
    # Load location mappings
    location_map = load_location_mapping()
    
    # Connect to database
    engine = create_engine(db_url)
    Session = sessionmaker(bind=engine)
    session = Session()
    
    try:
        # Query images without coordinates
        images = session.query(Image).filter(Image.latitude.is_(None)).all()
        total = len(images)
        
        if total == 0:
            print("✅ All images already have coordinates!")
            return
        
        print(f"🌍 Found {total} images needing geocoding\n")
        
        success_count = 0
        skip_count = 0
        fail_count = 0
        
        for i, image in enumerate(images, 1):
            # Determine location name from mapping
            location_name = location_map.get(image.title)
            
            # Fallback to s3_key-based lookup if title not mapped
            if not location_name and image.s3_key:
                s3_key_base = image.s3_key.replace('[img-', '').replace(']-A', '').replace('.jpg', '')
                location_name = location_map.get(s3_key_base)
            
            # Final fallback to default location
            if not location_name:
                location_name = location_map.get('_default_')
            
            if not location_name:
                print(f"⏭️  {i}/{total}: Skipping '{image.title}' - no location mapping")
                skip_count += 1
                continue
            
            # Geocode the location
            print(f"🔍 {i}/{total}: Geocoding '{image.title}' → {location_name}...", end=" ")
            coords = geocode_location(location_name)
            
            if coords['latitude'] and coords['longitude']:
                if not dry_run:
                    image.latitude = coords['latitude']
                    image.longitude = coords['longitude']
                    image.location_name = location_name
                
                print(f"✅ [{coords['latitude']:.4f}, {coords['longitude']:.4f}]")
                success_count += 1
            else:
                print(f"❌ Failed")
                fail_count += 1
            
            # Commit in batches
            if not dry_run and i % batch_size == 0:
                session.commit()
                print(f"💾 Committed batch {i//batch_size}\n")
            
            # Rate limit: Nominatim requires 1 req/second
            if i < total:
                time.sleep(1)
        
        # Final commit
        if not dry_run:
            session.commit()
            print("\n💾 Final commit complete")
        
        # Summary
        print(f"\n{'='*60}")
        print(f"📊 Geocoding Summary:")
        print(f"   ✅ Success: {success_count}")
        print(f"   ⏭️  Skipped: {skip_count}")
        print(f"   ❌ Failed:  {fail_count}")
        print(f"   📍 Total:   {total}")
        print(f"{'='*60}")
        
        if dry_run:
            print("\n⚠️  DRY RUN - No changes were saved to database")
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        session.rollback()
        raise
    finally:
        session.close()


def main():
    parser = argparse.ArgumentParser(description="Geocode existing images in database")
    parser.add_argument(
        '--db',
        default=os.getenv('POSTGRES_URL'),
        help='Database URL (default: POSTGRES_URL env var)'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Run without actually updating database'
    )
    parser.add_argument(
        '--batch-size',
        type=int,
        default=10,
        help='Number of images to process before committing (default: 10)'
    )
    
    args = parser.parse_args()
    
    if not args.db:
        print("❌ Error: Database URL required. Provide via --db or POSTGRES_URL env var")
        sys.exit(1)
    
    print(f"🚀 Starting geocoding process...")
    if args.dry_run:
        print("   Mode: DRY RUN (no database changes)")
    print()
    
    geocode_images(args.db, dry_run=args.dry_run, batch_size=args.batch_size)


if __name__ == '__main__':
    main()
