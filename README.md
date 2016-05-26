# Inflate

This library allows Squirrel code to decompress data encoded using the [deflate method](https://en.wikipedia.org/wiki/DEFLATE), as used in zip and gzip file compression, and PNG images.

**To include the library in your code, add** `#require "Inflate.class.nut:1.0.0"` **at the top of your agent or device code**

## Class Usage

The primary class, Inflate, has no constructor &mdash; simply call its only method, *decompress()* as a class method:

```squirrel
#require "Inflate.class.nut:1.0.0"

// Assume deflated data is held in 'data'
local decompressedData = Inflate.decompress(data);
```

## Class Methods

### decompress(*source[, debug]*)

This method inflates the deflate-compressed data passed into its *source* parameter. This data *must* be stored as a blob.

A second, optional parameter, *debug* is provided. It defaults to `false`, but if you pass in `true`, the class will log progress data and other information during the decompression process.

If the decompression fails in any way, the method returns `null`, otherwise it returns a new blob containing the decompressed binary data.

#### Example

```squirrel
// Decode the PNG data
local zlib = decode(downloadData, true);
if (zlib != null) {
    // Deflate the image data
    zlib.data = Inflate.decompress(zlib.data);
    if (zlib.data != null) {
        // De-filter the image data
        zlib.data = defilter(zlib.height, zlib.width, zlib.bpc, zlib.data, debug);
        if (zlib.data != null) {
            // Render the extracted image as a 256 x 256 bitman and return it
            return render(zlib.height, zlib.width, zlib.bpc, zlib.data, debug);
        }
    }
}
```

## The Tree Class

The library also includes a subsidiary class, Tree, which provides Inflate with a data structure for storing Huffman Trees. It contains no methods other than a constructor which initializes each instance’s two data arrays. The constructor has no parameters.

## License

The Inflate library is licensed under the terms of the [MIT license](https://github.com/electricimp/Inflate/blob/master/LICENSE).
