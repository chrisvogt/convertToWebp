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

# Default quality
quality=100
lossless="false"
preview="false"
preview_only="false"
extra_params=()
template_file="$script_dir/template.html"
server_pid=""

# Parse command-line arguments for -q, -lossless, -preview, and -previewOnly
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -q)
      quality="$2"
      shift # past argument
      shift # past value
      ;;
    -lossless)
      lossless="true"
      shift # past argument
      ;;
    -preview)
      preview="true"
      shift # past argument
      ;;
    -previewOnly)
      preview_only="true"
      shift # past argument
      ;;
    *)
      extra_params+=("$1")
      shift # past argument
      ;;
  esac
done

# Function to format bytes as KB with comma separators
format_size() {
  echo $1 | awk '{printf("%\047.2f\n", $1/1024)}'
}

# Function to regenerate the main index.html file
regenerate_main_index() {
  main_index_file="index.html"
  echo "<!DOCTYPE html>" > "$main_index_file"
  echo "<html lang=\"en\">" >> "$main_index_file"
  echo "<head><meta charset=\"UTF-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\"><title>Conversion Results</title></head>" >> "$main_index_file"
  echo "<body><h1>Conversion Results</h1><ul>" >> "$main_index_file"
  
  # Check for existing directories to avoid duplicates
  existing_dirs=()
  while IFS= read -r -d '' dir; do
    existing_dirs+=("$dir")
  done < <(find . -maxdepth 1 -type d -name "conversion_q*" -print0)
  
  # Add links to the main index file
  for dir in "${existing_dirs[@]}"; do
    if [ -f "$dir/conversion.log" ]; then
      link_name=$(basename "$dir")
      echo "<li><a href=\"$link_name/index.html\">$link_name</a></li>" >> "$main_index_file"
    fi
  done
  
  # Close the ul and body tags
  echo "</ul></body></html>" >> "$main_index_file"
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

# Handle previewOnly case
if [ "$preview_only" == "true" ]; then
  start_local_server
  exit 0
fi

# Regenerate the main index.html file at the start
regenerate_main_index

# Define the output directory name
output_dir="conversion_q${quality}"
[ "$lossless" == "true" ] && output_dir="${output_dir}_lossless"
[ "${#extra_params[@]}" -ne 0 ] && output_dir="${output_dir}_options"

# Create the output directory if it doesn't exist
mkdir -p "$output_dir"

# Define the log file name
logfile="$output_dir/conversion.log"

# Clear the log file and write the parameters at the top
{
  echo "Quality: $quality"
  echo "Lossless: $lossless"
  echo "Additional cwebp options: ${extra_params[*]}"
  echo ""
} > "$logfile"

# Initialize HTML file by copying the template
htmlfile="$output_dir/index.html"
cp "$template_file" "$htmlfile"

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
  sed -i '' '/<!-- Content Placeholder -->/ i\
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

    # Build the cwebp command
    cwebp_cmd=("cwebp" "-q" "$quality")
    [ "$lossless" == "true" ] && cwebp_cmd+=("-lossless")
    cwebp_cmd+=("${extra_params[@]}" "$file" "-o" "$output")

    # Convert file to webp with the specified quality and any additional options
    ("${cwebp_cmd[@]}" >> "$logfile" 2>&1) & show_loading

    # Wait for the conversion to complete
    wait

    # Get output file size
    output_size=$(stat -f %z "$output")

    # Format sizes as KB
    original_size_kb=$(format_size "$original_size")
    output_size_kb=$(format_size "$output_size")

    # Log sizes to log file and display the sizes in the terminal
    log_entry="$file -> $output: $original_size_kb KB -> $output_size_kb KB | Quality: $quality | Lossless: $lossless"
    echo "$log_entry" >> "$logfile"
    echo "$log_entry"

    # Prepare the HTML entry for insertion with file sizes
    html_entry="<tr><td><img src=\"../$file\" alt=\"$file\"><br><small>Original: $original_size_kb KB</small></td><td><img src=\"${output#$output_dir/}\" alt=\"${file%.*}.webp\"><br><small>Converted: $output_size_kb KB</small></td></tr>"

    # Add entry to HTML file
    sed -i '' '/<!-- Content Placeholder -->/ i\
    '"$html_entry"'
    ' "$htmlfile"
  fi
done

# Remove trap and finalize log file and HTML file
trap - SIGINT
{
  echo "" >> "$logfile"
  echo "Conversion complete." >> "$logfile"
  sed -i '' '/<!-- Content Placeholder -->/ i\
  <p>Conversion complete.</p>
  ' "$htmlfile"
}

# Display the log file
echo ""
echo "Conversion complete. Log file: $logfile"

# Regenerate the main index.html file at the end
regenerate_main_index

# Start a local web server and open the browser if -preview is specified
if [ "$preview" == "true" ]; then
  start_local_server
fi
