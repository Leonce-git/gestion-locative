//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<advance_pdf_viewer/FlutterPluginPdfViewerPlugin.h>)
#import <advance_pdf_viewer/FlutterPluginPdfViewerPlugin.h>
#else
@import advance_pdf_viewer;
#endif

#if __has_include(<document_scanner_flutter/DocumentScannerFlutterPlugin.h>)
#import <document_scanner_flutter/DocumentScannerFlutterPlugin.h>
#else
@import document_scanner_flutter;
#endif

#if __has_include(<sqflite_darwin/SqflitePlugin.h>)
#import <sqflite_darwin/SqflitePlugin.h>
#else
@import sqflite_darwin;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [FlutterPluginPdfViewerPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterPluginPdfViewerPlugin"]];
  [DocumentScannerFlutterPlugin registerWithRegistrar:[registry registrarForPlugin:@"DocumentScannerFlutterPlugin"]];
  [SqflitePlugin registerWithRegistrar:[registry registrarForPlugin:@"SqflitePlugin"]];
}

@end
