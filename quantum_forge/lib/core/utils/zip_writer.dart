// ============================================================================
// Minimal ZIP writer (store method, no compression)
// ----------------------------------------------------------------------------
// The dashboard's "Export Results (.zip)" button used to call a web stub that
// returned `memory://results_<id>.zip` and downloaded nothing at all. Shipping
// a full archive package would be overkill for a handful of text entries, so
// this writes a valid, spec-compliant ZIP by hand:
//
//   local file header → data → (repeat) → central directory → EOCD
//
// CRC-32 is implemented here too (the standard IEEE 802.3 polynomial), because
// `dart:io`'s ZLib is unavailable on the web target.
// ============================================================================

import 'dart:convert';
import 'dart:typed_data';

/// One entry in the archive.
class ZipEntry {
  final String name;
  final String content;
  const ZipEntry(this.name, this.content);
}

class ZipWriter {
  const ZipWriter._();

  /// Builds a ZIP archive containing [entries].
  ///
  /// Sizes and CRCs are computed from the encoded bytes, so the archive is
  /// always internally consistent.
  static Uint8List build(List<ZipEntry> entries) {
    final output = BytesBuilder(copy: false);
    final centralDirectory = BytesBuilder(copy: false);
    final timestamp = _dosDateTime(DateTime.now());

    var offset = 0;
    for (final entry in entries) {
      final nameBytes = utf8.encode(entry.name);
      final data = Uint8List.fromList(utf8.encode(entry.content));
      final crc = crc32(data);

      final localHeader = BytesBuilder(copy: false)
        ..add(_u32(0x04034b50)) // local file header signature
        ..add(_u16(20)) // version needed
        ..add(_u16(0x0800)) // flags: UTF-8 filenames
        ..add(_u16(0)) // method: stored
        ..add(_u16(timestamp.$1))
        ..add(_u16(timestamp.$2))
        ..add(_u32(crc))
        ..add(_u32(data.length)) // compressed size
        ..add(_u32(data.length)) // uncompressed size
        ..add(_u16(nameBytes.length))
        ..add(_u16(0)) // extra field length
        ..add(nameBytes);

      final headerBytes = localHeader.takeBytes();
      output
        ..add(headerBytes)
        ..add(data);

      centralDirectory
        ..add(_u32(0x02014b50)) // central directory signature
        ..add(_u16(20)) // version made by
        ..add(_u16(20)) // version needed
        ..add(_u16(0x0800)) // flags
        ..add(_u16(0)) // method
        ..add(_u16(timestamp.$1))
        ..add(_u16(timestamp.$2))
        ..add(_u32(crc))
        ..add(_u32(data.length))
        ..add(_u32(data.length))
        ..add(_u16(nameBytes.length))
        ..add(_u16(0)) // extra
        ..add(_u16(0)) // comment
        ..add(_u16(0)) // disk number start
        ..add(_u16(0)) // internal attributes
        ..add(_u32(0)) // external attributes
        ..add(_u32(offset)) // relative offset of local header
        ..add(nameBytes);

      offset += headerBytes.length + data.length;
    }

    final directoryBytes = centralDirectory.takeBytes();
    output
      ..add(directoryBytes)
      ..add(_u32(0x06054b50)) // end of central directory signature
      ..add(_u16(0)) // disk number
      ..add(_u16(0)) // disk with central directory
      ..add(_u16(entries.length))
      ..add(_u16(entries.length))
      ..add(_u32(directoryBytes.length))
      ..add(_u32(offset))
      ..add(_u16(0)); // comment length

    return output.takeBytes();
  }

  /// IEEE 802.3 CRC-32, computed with a lazily built lookup table.
  static int crc32(List<int> bytes) {
    final table = _crcTable;
    var crc = 0xFFFFFFFF;
    for (final byte in bytes) {
      crc = (crc >> 8) ^ table[(crc ^ byte) & 0xFF];
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  static final List<int> _crcTable = List<int>.generate(256, (i) {
    var c = i;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    return c;
  });

  /// MS-DOS date/time pair used by the ZIP headers.
  static (int, int) _dosDateTime(DateTime now) {
    final year = now.year.clamp(1980, 2107) - 1980;
    final date = (year << 9) | (now.month << 5) | now.day;
    final time = (now.hour << 11) | (now.minute << 5) | (now.second ~/ 2);
    return (time, date);
  }

  static Uint8List _u16(int value) {
    final bytes = Uint8List(2);
    ByteData.view(bytes.buffer).setUint16(0, value & 0xFFFF, Endian.little);
    return bytes;
  }

  static Uint8List _u32(int value) {
    final bytes = Uint8List(4);
    ByteData.view(bytes.buffer).setUint32(0, value & 0xFFFFFFFF, Endian.little);
    return bytes;
  }
}
