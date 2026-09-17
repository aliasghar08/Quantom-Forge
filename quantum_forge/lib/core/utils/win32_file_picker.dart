// ignore_for_file: non_constant_identifier_names
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// Struct definitions for pure Dart FFI without win32 package

typedef GetOpenFileNameWNative = Int32 Function(Pointer<OPENFILENAME> lpofn);
typedef GetOpenFileNameWDart = int Function(Pointer<OPENFILENAME> lpofn);

final class OPENFILENAME extends Struct {
  @Uint32()
  external int lStructSize;

  @IntPtr()
  external int hwndOwner;

  @IntPtr()
  external int hInstance;

  external Pointer<Utf16> lpstrFilter;
  external Pointer<Utf16> lpstrCustomFilter;

  @Uint32()
  external int nMaxCustFilter;

  @Uint32()
  external int nFilterIndex;

  external Pointer<Utf16> lpstrFile;

  @Uint32()
  external int nMaxFile;

  external Pointer<Utf16> lpstrFileTitle;

  @Uint32()
  external int nMaxFileTitle;

  external Pointer<Utf16> lpstrInitialDir;
  external Pointer<Utf16> lpstrTitle;

  @Uint32()
  external int Flags;

  @Uint16()
  external int nFileOffset;

  @Uint16()
  external int nFileExtension;

  external Pointer<Utf16> lpstrDefExt;

  @IntPtr()
  external int lCustData;

  @IntPtr()
  external int lpfnHook;

  external Pointer<Utf16> lpTemplateName;
  
  @IntPtr()
  external int pvReserved;

  @Uint32()
  external int dwReserved;

  @Uint32()
  external int FlagsEx;
}

class Win32FilePicker {
  static final DynamicLibrary _comdlg32 = DynamicLibrary.open('comdlg32.dll');
  static final GetOpenFileNameWDart _getOpenFileNameW = 
      _comdlg32.lookupFunction<GetOpenFileNameWNative, GetOpenFileNameWDart>('GetOpenFileNameW');

  static String? pickFile({String title = 'Select File'}) {
    if (!Platform.isWindows) return null;

    final arena = Arena();
    try {
      final ofn = arena<OPENFILENAME>();
      ofn.ref.lStructSize = sizeOf<OPENFILENAME>();
      ofn.ref.hwndOwner = 0; // NULL

      // Allocate buffer for the returned file name (MAX_PATH = 260)
      final lpstrFile = arena<Uint16>(260).cast<Utf16>();
      // Initialize the first character to null
      lpstrFile.cast<Uint16>().value = 0;

      ofn.ref.lpstrFile = lpstrFile;
      ofn.ref.nMaxFile = 260;

      // Allocate title
      ofn.ref.lpstrTitle = title.toNativeUtf16(allocator: arena);

      // OFN_PATHMUSTEXIST (0x00000800) | OFN_FILEMUSTEXIST (0x00001000)
      ofn.ref.Flags = 0x00000800 | 0x00001000;

      final result = _getOpenFileNameW(ofn);
      
      if (result != 0) {
        return ofn.ref.lpstrFile.toDartString();
      }
      return null;
    } finally {
      arena.releaseAll();
    }
  }
}
