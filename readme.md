
# ConvertToWebp

This script converts images in the current directory to the WebP format using `cwebp`. It also generates an HTML file to preview the original and converted images side-by-side. 

## Features

- Convert images to WebP format with customizable quality.
- Supports lossless conversion.
- Generates an HTML file for easy comparison of original and converted images.
- Option to start a local web server to preview results.
- Dynamically updates the main `index.html` to reflect existing conversion directories.
- Option to only regenerate the `index.html` and start the web server without performing conversions.

## Prerequisites

- `cwebp` must be installed on your system. You can install it via Homebrew:
  ```sh
  brew install webp
  ```

- Python 3 for starting the local web server.

## Usage

### Basic Conversion

To convert images in the current directory to WebP format with default quality (100):

```sh
convertToWebp
```

### Custom Quality

To specify a custom quality (e.g., 80):

```sh
convertToWebp -q 80
```

### Lossless Conversion

To perform a lossless conversion:

```sh
convertToWebp -lossless
```

### Preview Results

To start a local web server and preview the results:

```sh
convertToWebp -preview
```

### Preview Only

To regenerate the `index.html` and start the local web server without performing conversions:

```sh
convertToWebp -previewOnly
```

## Additional Arguments

The script supports additional arguments as passed to `cwebp`. For a full list of available arguments, please refer to the [cwebp documentation](https://developers.google.com/speed/webp/docs/cwebp).

## Arguments

### `-q quality`

Specify the quality of the WebP conversion (default: 100).

### `-lossless`

Perform a lossless conversion.

### `-preview`

Generate the `index.html` file and start a local web server to preview the results after conversions.

### `-previewOnly`

Only regenerate the `index.html` and start the local web server without performing any conversions.

## Example

To convert images to WebP format with a quality of 80, and start a local web server to preview the results:

```sh
convertToWebp -q 80 -preview
```

To regenerate the `index.html` and start the local web server without performing any conversions:

```sh
convertToWebp -previewOnly
```

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Attribution

- Christopher Vogt (https://www.chrisvogt.me)
- OpenAI's ChatGPT (https://www.openai.com/)
