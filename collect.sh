#!/bin/bash

# Define the destination directory
DEST_DIR=~/Downloads/PDFs

# Check if the destination directory exists; if not, create it
if [ ! -d "$DEST_DIR" ]; then
  mkdir -p "$DEST_DIR"
  echo "Created directory: $DEST_DIR"
fi

# Initialize counter
counter=1

# Find all PDF files (case-insensitive for extension) in the current directory and subdirectories
# Use process substitution to avoid subshell variable scope issues
while IFS= read -r file; do
    # Extract just the filename
    filename=$(basename "$file")
    
    # Format counter with leading zeros (e.g., 001, 002)
    # Using 3 digits for padding
    prefix=$(printf "%03d" "$counter")
    
    # Construct new filename
    new_filename="${prefix}_${filename}"
    
    # Copy the file
    cp "$file" "$DEST_DIR/$new_filename"
    
    # Increment counter
    ((counter++))
    
done < <(find . -type f -iname "*.pdf")

echo "All PDF files have been copied to $DEST_DIR with numeric prefixes."
