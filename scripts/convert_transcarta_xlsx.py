#!/usr/bin/env python3
"""
Convert the transposed transcarta Excel file to a normalized CSV for import.
The Excel has artworks as columns and metadata as rows.
"""
import pandas as pd
import sys

def main():
    print("Loading Excel file...")
    xl = pd.ExcelFile('./data/transcarta-image-meta.xlsx')
    
    # Parse Image View List which has Image_IDs as columns
    print("Parsing Image View List...")
    image_df = xl.parse('Image View List')
    
    # The first row contains field names, columns are Image_IDs
    # Skip first 2 columns (Image_ID and description)
    image_ids = image_df.columns[2:]
    
    # Create a list to hold our records
    records = []
    
    for img_id in image_ids:
        if pd.isna(img_id) or img_id == 'Unnamed':
            continue
            
        # Get the column data
        col_data = image_df[img_id]
        
        # Extract relevant fields
        # The row labels are in the first column
        row_labels = image_df['Image_ID'].tolist()
        
        record = {
            's3_key': img_id,  # The image ID is the s3_key
            'title': None,
            'artist': None,
            'views': None,
        }
        
        # Try to find title, artist, etc from row labels
        for idx, label in enumerate(row_labels):
            if pd.isna(label):
                continue
            label_lower = str(label).lower().strip()
            value = col_data.iloc[idx] if idx < len(col_data) else None
            
            if 'artwork_id' in label_lower:
                # This links to artwork info
                artwork_id = value
            elif 'title' in label_lower or label_lower == 'artwork_title':
                record['title'] = str(value) if not pd.isna(value) else None
            elif 'artist' in label_lower:
                record['artist'] = str(value) if not pd.isna(value) else None
            elif 'view' in label_lower and 'list' not in label_lower:
                record['views'] = str(value) if not pd.isna(value) else None
        
        records.append(record)
    
    # Now try to get artwork titles from Artwork List
    print("Parsing Artwork List for titles...")
    artwork_df = xl.parse('Artwork List')
    
    # Similar structure - artworks as columns
    artwork_ids = artwork_df.columns[2:]  # Skip first 2 columns
    artwork_titles = {}
    
    for artwork_id in artwork_ids:
        if pd.isna(artwork_id) or 'Unnamed' in str(artwork_id):
            continue
        col_data = artwork_df[artwork_id]
        # First meaningful row should have the title
        if len(col_data) > 0:
            title = col_data.iloc[0] if not pd.isna(col_data.iloc[0]) else None
            if title:
                artwork_titles[artwork_id] = str(title).strip()
    
    # Now match image IDs to artwork IDs to get titles
    # The Image View List first row maps Image_ID to Artwork_ID
    image_to_artwork = {}
    if 'Artwork_ID' in image_df['Image_ID'].values or 'artwork_id' in [str(x).lower() for x in image_df['Image_ID'].values]:
        artwork_id_row_idx = None
        for idx, label in enumerate(image_df['Image_ID']):
            if not pd.isna(label) and 'artwork_id' in str(label).lower():
                artwork_id_row_idx = idx
                break
        
        if artwork_id_row_idx is not None:
            for img_id in image_ids:
                if pd.isna(img_id):
                    continue
                artwork_id = image_df[img_id].iloc[artwork_id_row_idx]
                if not pd.isna(artwork_id):
                    image_to_artwork[img_id] = str(artwork_id).strip()
    
    # Update records with artwork titles
    for record in records:
        img_id = record['s3_key']
        # Try to find artwork title
        if img_id in image_to_artwork:
            artwork_id = image_to_artwork[img_id]
            if artwork_id in artwork_titles:
                record['title'] = artwork_titles[artwork_id]
        
        # If still no title, try to extract from filename
        if not record['title']:
            # Image IDs look like [ArtworkName]-A
            # Extract the artwork name
            if '-' in img_id:
                artwork_name = img_id.rsplit('-', 1)[0]
                artwork_name = artwork_name.strip('[]')
                record['title'] = artwork_name.replace('_', ' ')
        
        # Match s3_key format in S3 (add .jpg/.tif extension based on what's in S3)
        # Format: [img-AIDSGATE-A].jpg
        if not record['s3_key'].startswith('[img-'):
            # Convert [AIDSGATE]-A to [img-AIDSGATE]-A
            clean_id = img_id.strip('[]')
            record['s3_key'] = f'[img-{clean_id}]'
    
    # Create DataFrame
    df = pd.DataFrame(records)
    
    # Add empty columns for lat/lon (not in this dataset)
    df['latitude'] = None
    df['longitude'] = None
    
    # Reorder columns
    df = df[['s3_key', 'title', 'artist', 'views', 'latitude', 'longitude']]
    
    # Remove rows with empty s3_key
    df = df[df['s3_key'].notna()]
    df = df[df['s3_key'] != '']
    
    # Save to CSV
    output_file = './data/transcarta.csv'
    df.to_csv(output_file, index=False)
    
    print(f"\n✅ Success! Wrote {len(df)} records to {output_file}")
    print("\nFirst 5 records:")
    print(df.head().to_string())
    
    return 0

if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)
