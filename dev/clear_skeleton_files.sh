#!/bin/bash

# Change to the specified directory
cd "priv/audits" || exit 1

# Find and delete files ending with "skeleton.html"
find . -type f -name "*skeleton.html" -delete

echo "All files ending with 'skeleton.html' have been deleted."