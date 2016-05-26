class Tree {
    // Simple data structure for Huffman Trees as used by the Inflate class
    table = null;
    trans = null;

    constructor() {
        table = array(16, 0);
        trans = array(288, 0);
    }
}

class Inflate {
    // PUBLIC FUNCTIONS

    static function decompress(source = null, debug = false) {
        // Class entry point. 'source' must be a blob, and contains the deflated data
        // Returns the decompressed data as a new blob, or null on error
        if (source == null || typeof source != "blob") {
            server.error("Inflate.decompress() requires a non-zero data source blob");
            return null;
        }
        local data = _decompress(source, debug);
        if (data != null) return data;
        server.error("Inflate.decompress() source data could not be decompressed");
        return null;
    }

    // PRIVATE FUNCTIONS - DO NOT CALL DIRECTLY

    static function _decompress(source, debug) {
        // Inflate stream from source to dest
        local bfinal, result, block;
        local bitCount = 0;
        local block = 0;

        // Decompression tree data
        local dynamicLengthTree = Tree();
        local dynamicDistTree = Tree();
        local fixedLengthTree = Tree();
        local fixedDistTree = Tree();

        fixedLengthTree.table = [0,0,0,0,0,0,0,24,152,112,0,0,0,0,0,0];
        fixedLengthTree.trans = [256,257,258,259,260,261,262,263,264,265,266,267,268,269,270,271,272,273,274,275,276,277,
        278,279,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,
        39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,
        74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,
        107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,
        134,135,136,137,138,139,140,141,142,143,280,281,282,283,284,285,286,287,144,145,146,147,148,149,150,151,152,
        153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,176,177,178,179,
        180,181,182,183,184,185,186,187,188,189,190,191,192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,
        207,208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,224,225,226,227,228,229,230,231,232,233,
        234,235,236,237,238,239,240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255];

        fixedDistTree.table = [0,0,0,0,0,32,0,0,0,0,0,0,0,0,0,0];
        fixedDistTree.trans = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,0,
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];

        local lengthBits = [0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0,0];
        local lengthBase = [3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258,0];

        local distBits = [0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13];
        local distBase = [1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,
        6145,8193,12289,16385,24577];

        local clc = [16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15];

        // Source data is in ZLIB format (see section 2.2, RTF1950)
        // So remove the first two and last six bytes to yield the
        // compressed image data
        source.seek(2, 'b');
        local input = source.readblob(source.len() - 4);
        input.seek(0, 'b');
        local output = blob();

        // Set up a structure to pass around the class
        local data = {};
        data.input <- input;
        data.output <- output;
        data.bitCount <- 0;
        data.tag <- 0;
        data.distBits <- distBits;
        data.distBase <- distBase;
        data.lengthBits <- lengthBits;
        data.lengthBase <- lengthBase;
        data.clc <- clc;

        do {
            ++block;
            if (debug) server.log("Processing Block " + block);
            local btype;
            local res;

            // Read final block flag
            bfinal = _getBit(data);

            // Read block type (2 bits)
            btype = _readBits(data, 2, 0);
            if (debug) server.log("Block type: " + btype + ", Block final: " + bfinal);

            // Decompress block
            switch (btype) {
                case 0:
                    // Decompress uncompressed block
                    result = _inflateUncompressedBlock(data);
                    break;
                case 1:
                    // Decompress block with fixed huffman trees
                    result = _inflateFixedBlock(data, fixedLengthTree, fixedDistTree);
                    break;
                case 2:
                    // Decompress block with dynamic huffman trees
                    result = _inflateDynamicBlock(data, dynamicLengthTree, dynamicDistTree);
                    break;
                default:
                    result = -1;
            }

            if (result != 0) return null;

        } while (!bfinal);

        if (debug) server.log("Decoded data length: " + output.len());
        return output;
    }

    static function _getBit(data) {
        local bit;
        if (!data.bitCount--) {
            data.tag = data.input.readn('b');
            data.bitCount = 7;
        }
        bit = data.tag & 0x01;
        data.tag = data.tag >> 1;
        return bit;
    }

    static function _readBits(data, number = 0, basis = 0) {
        local value = 0;
        if (number > 0) {
            local limit = 1 << number;
            for (local mask = 1 ; mask < limit ; mask *= 2) {
                if (_getBit(data)) value = value + mask;
            }
        }
        return value + basis;
    }

    static function _inflateUncompressedBlock(data) {
        data. bitCount = 0;
        local len = data.input.readn('b');
        len = 256 * data.input.readn('b') + len;
        local nlen = data.input.readn('b');
        nlen = 256 * data.input.readn('b') + nlen;
        if (len != (~nlen & 0xFFFF)) return -1;

        for (local i = len ; i > 0 ; --i) {
            local a = data.input.readn('b');
            data.output.writen(a, 'b');
        }

        if (debug) server.log("Written " + len + " uncompressed bytes");
        return 0;
    }

    static function _inflateFixedBlock(data, flt, fdt) {
        return _inflateBlockData(data, flt, fdt);
    }

    static function _inflateDynamicBlock(data, dlt, ddt) {
        _decodeTrees(data, dlt, ddt);
        return _inflateBlockData(data, dlt, ddt);
    }

    static function _inflateBlockData(data, lTree, dTree) {
        local start;
        while (1) {
            start = data.output.tell();
            local symbol = _decodeSymbol(data, lTree);
            if (symbol == 256) return 0;
            if (symbol < 256) {
                // Write the symbol as a literal
                data.output.writen(symbol, 'b');
            } else {
                local length, distance, offset;
                symbol -= 257;
                length = _readBits(data, data.lengthBits[symbol], data.lengthBase[symbol]);
                distance = _decodeSymbol(data, dTree);
                offset = -1 * _readBits(data, data.distBits[distance], data.distBase[distance]);
                start = data.output.tell();
                for (local i = 0 ; i < length ; ++i) {
                    data.output.writen(data.output[start + i + offset], 'b');
                }
            }
        }
    }

    static function _decodeTrees(data, lTree, dTree) {
        local codeTree = Tree();
        local hlit, hdist, hclen;
        local i, number, length;
        local codeLengths = array(320, 0);

        // Read in the first 14 bits in the block:
        // HLIT: bits 1 to 5, values 257-286, code lengths for the literal/length alphabet
        // HDIST: bits 6 to 10, values 1-32, code lengths for the distance alphabet
        // HCLEN: bits 11 to 14, values 4-19, code lengths for the code length alphabet
        hlit = _readBits(data, 5, 257);
        hdist = _readBits(data, 5, 1);
        hclen = _readBits(data, 4, 4);

        // Read the next HCLEN groups of 3 bits, one at a time
        for (i = 0 ; i < hclen ; ++i) {
            local clen = _readBits(data, 3, 0);
            codeLengths[data.clc[i]] = clen;
        }

        // Build the code length tree from the codeLengths array
        _buildTree(codeTree, codeLengths, 19);

        for (number = 0 ; number < hlit + hdist ; number = number) {
            local symbol = _decodeSymbol(data, codeTree);
            switch (symbol) {
                case 16:
                    // Copy the previous code length 3-6 times (stored as 2 bits)
                    local previous = codeLengths[number - 1];
                    for (length = _readBits(data, 2, 3); length ; --length) {
                        codeLengths[number] = previous;
                        ++number;
                    }
                    break;
                case 17:
                    // Repeat code length 0 for 3-10 times (stored as 3 bits
                    for (length = _readBits(data, 3, 3) ; length ; --length) {
                        codeLengths[number] = 0;
                        ++number;
                    }
                    break;
                case 18:
                    // Repeat code length 0 for 11-138 times (stored as 7 bits
                    for (length = _readBits(data, 7, 11) ; length ; --length) {
                        codeLengths[number] = 0;
                        ++number;
                    }
                    break;
                default:
                    codeLengths[number] = symbol;
                    ++number;
                    break;
            }
        }

        _buildTree(lTree, codeLengths, hlit);
        _buildTree(dTree, codeLengths.slice(hlit), hdist);
    }

    static function _decodeSymbol(data, aTree) {
        // Decode the next symbol from the input
        // relative to the passed tree object
        local sum = 0, code = 0, index = 0;

        do {
            // Get bits while the code value is above sum
            code = 2 * code + _getBit(data);
            ++index;
            sum += aTree.table[index];
            code -= aTree.table[index];

        } while (code >= 0);

        return aTree.trans[sum + code];
    }

    static function _buildTree(aTree, lengths, items) {
        // Build a tree from an array of code lengths
        // 'items' is number of entries in the tree
        local offsets = array(16, 0);
        local sum, i;

        // Clear the code length count table
        for (i = 0 ; i < 16 ; ++i) {
            aTree.table[i] = 0;
        }

        // Add the symbol lengths and code count lengths
        for (i = 0 ; i < items ; ++i) {
            local a = lengths[i];
            aTree.table[a]++;
        }

        aTree.table[0] = 0;

        // Calculate offset table
        for (sum = 0, i = 0 ; i < 16 ; ++i) {
            offsets[i] = sum;
            sum += aTree.table[i];
        }

        // Create code:symbol translation table
        for (i = 0 ; i < items ; ++i) {
            if (lengths[i] != 0) aTree.trans[offsets[lengths[i]]++] = i;
        }
    }
}
