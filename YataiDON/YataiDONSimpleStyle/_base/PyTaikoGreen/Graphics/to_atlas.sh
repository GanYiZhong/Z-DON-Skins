#!/bin/bash

# Default to horizontal concatenation
direction="horizontal"
images_per_row=0

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--vertical)
            direction="vertical"
            shift
            ;;
        -g|--grid)
            direction="grid"
            images_per_row=$2
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Get array of image files
mapfile -t images < <(find . -maxdepth 1 -name "[0-9]*.png" -printf '%f\n' | sort -V)

# Get dimensions of first image
read width height < <(identify -format "%w %h" "${images[0]}")

# Create the output filename
output="$(basename "$PWD").png"

# Concatenate images
if [ "$direction" = "vertical" ]; then
    convert "${images[@]}" -append "$output"
elif [ "$direction" = "grid" ]; then
    # Create grid by concatenating rows horizontally, then rows vertically
    temp_rows=()

    for ((row = 0; row < ${#images[@]}; row += images_per_row)); do
        row_end=$((row + images_per_row))
        if [ $row_end -gt ${#images[@]} ]; then
            row_end=${#images[@]}
        fi

        row_images=("${images[@]:row:images_per_row}")
        temp_file="temp_row_$((row / images_per_row)).png"
        convert "${row_images[@]}" +append "$temp_file"
        temp_rows+=("$temp_file")
    done

    convert "${temp_rows[@]}" -append "$output"

    # Clean up temp files
    rm "${temp_rows[@]}"
else
    convert "${images[@]}" +append "$output"
fi

# Generate crop array
echo "{"
echo "  \"crop\": ["

if [ "$direction" = "vertical" ]; then
    # Vertical: y changes, x stays 0
    for i in "${!images[@]}"; do
        y=$((height * i))

        if [ $i -lt $((${#images[@]} - 1)) ]; then
            echo "      [0, $y, $width, $height],"
        else
            echo "      [0, $y, $width, $height]"
        fi
    done
elif [ "$direction" = "grid" ]; then
    # Grid: calculate position based on row and column
    for i in "${!images[@]}"; do
        row=$((i / images_per_row))
        col=$((i % images_per_row))
        x=$((width * col))
        y=$((height * row))

        if [ $i -lt $((${#images[@]} - 1)) ]; then
            echo "      [$x, $y, $width, $height],"
        else
            echo "      [$x, $y, $width, $height]"
        fi
    done
else
    # Horizontal: x changes, y stays 0
    for i in "${!images[@]}"; do
        x=$((width * i))

        if [ $i -lt $((${#images[@]} - 1)) ]; then
            echo "      [$x, 0, $width, $height],"
        else
            echo "      [$x, 0, $width, $height]"
        fi
    done
fi

echo "  ]"
echo "}"
