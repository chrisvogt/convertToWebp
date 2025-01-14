#!/bin/bash

# MIT License
# 
# © 2024 Christopher Vogt (https://www.chrisvogt.me)
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# 
# Attribution:
# - Christopher Vogt (https://www.chrisvogt.me)
# - OpenAI's ChatGPT (https://www.openai.com/)

# Get the directory where the script is located, resolving symlinks
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" &> /dev/null && pwd )"
  SOURCE="$( readlink "$SOURCE" )"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if the source was a relative symlink, resolve it relative to the path where the symlink file was located
done
script_dir="$( cd -P "$( dirname "$SOURCE" )" &> /dev/null && pwd )"

# Default values
quality=100
lossless="false"
preview="false"
preview_only="false"
extra_params=()
templates_dir="$script_dir/templates"
common_head_file="$templates_dir/common_head.html"
common_tail_file="$templates_dir/common_tail.html"
template_file="$templates_dir/template.html"
header_file="$templates_dir/header.html"
footer_file="$templates_dir/footer.html"
card_template_file="$templates_dir/card_template.html"
favicon_file="favicon.webp" # Changed to relative path

# Parse command-line arguments
while [[ "$1" =~ ^- ]]; do
    case "$1" in
        -q)
            quality="$2"
            shift 2
            ;;
        -lossless)
            lossless="true"
            shift
            ;;
        -preview)
            preview="true"
            shift
            ;;
        -previewOnly)
            preview_only="true"
            shift
            ;;
        *)
            extra_params+=("$1")
            shift
            ;;
    esac
done

# Create directories if they don't exist
output_dir="conversion_q${quality}"
[ "$lossless" == "true" ] && output_dir="${output_dir}_lossless"
[ "${#extra_params[@]}" -ne 0 ] && output_dir="${output_dir}_options"

mkdir -p "$output_dir"

# Function to format bytes as KB with comma separators
format_size() {
    echo $1 | awk '{printf("%\047.2f\n", $1/1024)}'
}

# Function to regenerate the main index.html file
regenerate_main_index() {
    main_index_file="index.html"
    {
        sed "s|<!-- FAVICON_PLACEHOLDER -->|<link rel=\"icon\" type=\"image/webp\" href=\"$favicon_file\">|g" "$common_head_file"
        cat "$header_file"
        echo "<main class=\"container mx-auto p-4\"><h2 class=\"text-2xl font-bold mb-4\">Conversion Results</h2><div class=\"grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6\">"
    } > "$main_index_file"
    
    # Check for existing directories to avoid duplicates
    existing_dirs=()
    while IFS= read -r -d '' dir; do
        existing_dirs+=("$dir")
    done < <(find . -maxdepth 1 -type d -name "conversion_q*" -print0)
    
    # Add cards to the main index file
    for dir in "${existing_dirs[@]}"; do
        if [ -f "$dir/conversion.log" ]; then
            link_name=$(basename "$dir")
            # Read the exact lines from the log file to get the settings
            quality_line=$(sed -n '1p' "$dir/conversion.log")
            lossless_line=$(sed -n '2p' "$dir/conversion.log")
            filesize_saved_line=$(grep 'Total filesize saved:' "$dir/conversion.log")
            time_line=$(grep 'Total time:' "$dir/conversion.log")
            quality="${quality_line#Quality: }"
            lossless="${lossless_line#Lossless: }"
            total_filesize_saved="${filesize_saved_line#Total filesize saved: }"
            total_time="${time_line#Total time: }"
            
            # Create a card for each conversion directory using the template
            card_content=$(<"$card_template_file")
            
            # Function to escape problematic characters for sed
            escape_sed() {
                echo "$1" | sed -e 's/[\/&]/\\&/g'
            }

            # Escape variables for sed
            escaped_quality=$(escape_sed "$quality")
            escaped_lossless=$(escape_sed "$lossless")

            # Replace placeholders using different delimiter and escaped variables
            card_content=$(echo "$card_content" | sed "s#<!-- LINK_PLACEHOLDER -->#${link_name}/index.html#g")
            card_content=$(echo "$card_content" | sed "s#<!-- LINK_NAME -->#${link_name}#g")
            card_content=$(echo "$card_content" | sed "s#<!-- QUALITY_PLACEHOLDER -->#${escaped_quality}#g")
            card_content=$(echo "$card_content" | sed "s#<!-- LOSSLESS_PLACEHOLDER -->#${escaped_lossless}#g")
            card_content=$(echo "$card_content" | sed "s#<!-- FILESIZE_SAVED_PLACEHOLDER -->#${total_filesize_saved}#g")
            card_content=$(echo "$card_content" | sed "s#<!-- TIME_PLACEHOLDER -->#${total_time}#g")
            echo "$card_content" >> "$main_index_file"
        fi
    done
    
    # Close the div, main and add footer
    {
        echo "</div></main>"
        cat "$footer_file"
        cat "$common_tail_file"
    } >> "$main_index_file"
}

# Function to start the local web server
start_local_server() {
    regenerate_main_index
    echo "Starting local web server to preview the results..."
    port=$(find_available_port)
    if [ -z "$port" ]; then
        echo "No available port found. Exiting."
        exit 1
    fi
    python3 -m http.server $port &
    server_pid=$!
    sleep 1
    open "http://localhost:$port/$main_index_file"
}

# Function to find an available port
find_available_port() {
    for port in $(seq 8000 8100); do
        if ! lsof -i:$port &>/dev/null; then
            echo $port
            return
        fi
    done
}

# Detect operating system and set sed inline flag
if [[ "$OSTYPE" == "darwin"* ]]; then
    SED_INLINE_FLAG="-i ''"
else
    SED_INLINE_FLAG="-i"
fi

# Handle previewOnly case
if [ "$preview_only" == "true" ]; then
    start_local_server
    exit 0
fi

# Function to display loading indicator
show_loading() {
    pid=$!
    spin='-\|/'
    i=0
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r%s" "${spin:$i:1}"
        sleep .1
    done
    printf "\r"  # Clear the spinner line after the process ends
}

# Function to handle cleanup on SIGINT
cleanup() {
    echo "" >> "$logfile"
    echo "Conversion incomplete. Process was killed." >> "$logfile"
    sed $SED_INLINE_FLAG '/<!-- Content Placeholder -->/ i\
    <p>Conversion incomplete. Process was killed.</p>
    ' "$htmlfile"
    echo ""
    echo "Conversion interrupted. Log file: $logfile"
    if [ -n "$server_pid" ]; then
        kill $server_pid
    fi
    exit 1
}

# Trap SIGINT
trap cleanup SIGINT

# Start conversion
logfile="$output_dir/conversion.log"

# Clear the log file and write the parameters at the top
{
    echo "Quality: $quality"
    echo "Lossless: $lossless"
    echo ""
} > "$logfile"

# Initialize HTML file by copying the template
htmlfile="$output_dir/index.html"
{
    sed "s|<!-- FAVICON_PLACEHOLDER -->|<link rel=\"icon\" type=\"image/webp\" href=\"$favicon_file\">|g" "$common_head_file"
    sed '/<!-- Header Placeholder -->/r '"$header_file" "$template_file" | sed '/<!-- Footer Placeholder -->/r '"$footer_file"
    cat "$common_tail_file"
} > "$htmlfile"

start_time=$(date +%s)
total_original_size=0
total_converted_size=0

# Start conversion
for file in *; do
    # Get the file extension
    extension="${file##*.}"
    
    # Convert to lowercase for case-insensitive comparison
    extension=$(echo "$extension" | tr '[:upper:]' '[:lower:]')

    # Check if the file is an image and not an mp4 file
    if [[ "$extension" =~ ^(jpg|jpeg|png|bmp|gif|tiff)$ ]]; then
        # Define output filename with .webp extension
        output="${output_dir}/${file%.*}.webp"

        # Get original file size
        original_size=$(stat -f %z "$file")
        total_original_size=$((total_original_size + original_size))

        # Build the cwebp command
        cwebp_cmd=("cwebp")
        cwebp_cmd+=("-q" "$quality")
        [ "$lossless" == "true" ] && cwebp_cmd+=("-lossless")
        cwebp_cmd+=("${extra_params[@]}")
        cwebp_cmd+=("$file" "-o" "$output")

        # Convert file to webp with the specified quality and any additional options
        ("${cwebp_cmd[@]}" >> "$logfile" 2>&1) & show_loading

        # Wait for the conversion to complete
        wait

        # Get output file size
        output_size=$(stat -f %z "$output")
        total_converted_size=$((total_converted_size + output_size))

        # Format sizes as KB
        original_size_kb=$(format_size "$original_size")
        output_size_kb=$(format_size "$output_size")

        # Log sizes to log file and display the sizes in the terminal
        log_entry="$file -> $output: $original_size_kb KB -> $output_size_kb KB | Quality: $quality | Lossless: $lossless"
        echo "$log_entry" >> "$logfile"
        echo "$log_entry"

        # Prepare the HTML entry for insertion with file sizes
        html_entry="<tr><td><a href=\"../$file\" target=\"_blank\"><img src=\"../$file\" alt=\"$file\"><small>Original: $original_size_kb KB</small></a></td><td><a href=\"${output#$output_dir/}\" target=\"_blank\"><img src=\"${output#$output_dir/}\" alt=\"${file%.*}.webp\"><small>Converted: $output_size_kb KB</small></a></td></tr>"

        # Add entry to HTML file
        sed $SED_INLINE_FLAG '/<!-- Content Placeholder -->/ i\
        '"$html_entry"'
        ' "$htmlfile"
    fi
done

# Remove trap and finalize log file and HTML file
trap - SIGINT
{
    echo "" >> "$logfile"
    echo "Conversion complete." >> "$logfile"
    sed $SED_INLINE_FLAG '/<!-- Content Placeholder -->/ i\
    <p>Conversion complete.</p>
    ' "$htmlfile"
}

end_time=$(date +%s)
total_time=$((end_time - start_time))
percent_saved=$(awk "BEGIN {print (1 - $total_converted_size / $total_original_size) * 100}")

{
    echo "Total filesize saved: $percent_saved%"
    echo "Total time: $total_time seconds"
} >> "$logfile"

# Display the log file
echo ""
echo "Conversion complete. Log file: $logfile"

# Regenerate the main index.html file at the end
regenerate_main_index

# Start a local web server and open the browser if -preview is specified
if [ "$preview" == "true" ]; then
    start_local_server
fi
