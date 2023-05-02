import 'dart:async';
import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_pdf_renderer/native_pdf_renderer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ExampleApp());
}

class ExampleApp extends StatelessWidget {
  Future<PdfDocument> _getDocument() async {
    if (await hasPdfSupport()) {
      return PdfDocument.openAsset('assets/FlutterSampleNotification.pdf');
    }

    throw Exception(
      'PDF Rendering does not '
      'support on the system of this version',
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    final storage = Map<int, PdfPageImage>();

    return MaterialApp(
      title: 'PDF View example',
      color: Colors.white,
      home: Scaffold(
        body: Column(
         
          children: [
          const SizedBox(height: 50,),
          TextButton(
            onPressed: () async {
              // Get the rendered images
              final images = <Uint8List>[];
              final document = await _getDocument();
              for (var i = 1; i <= document.pagesCount; i++) {
                final pageImage = await _renderPage(document, i);
                images.add(pageImage!.bytes);
              }

              // Create PDF from images
              final pdf = sf.PdfDocument();
              for (final image in images) {
                final page = pdf.pages.add();
                page.graphics.drawImage(
                    sf.PdfBitmap(image), const Rect.fromLTWH(0, 0, 595, 842));
              }
             

              final data = await pdf.save();
              final status = await Permission.storage.request();
if (status != PermissionStatus.granted) {
  throw Exception('Permission to write to external storage denied');
}
              final file = File('assets/output.pdf');
              // final file = File('${DateTime.now().millisecondsSinceEpoch}.pdf');
              await file.writeAsBytes(data);
            },
            child: const Text('Click here to convert it again to pdf'),
          ),
          Expanded(
            child: FutureBuilder(
              future: _getDocument(),
              builder: (context, AsyncSnapshot<PdfDocument> snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(snapshot.error.toString()),
                  );
                }

                return PageView.builder(
                  itemCount: snapshot.data!.pagesCount,
                  scrollDirection: Axis.vertical,
                  itemBuilder: (context, index) {
                    return ImageLoader(
                      storage: storage,
                      document: snapshot.data,
                      pageNumber: (index + 1),
                    );
                  },
                );
              },
            ),
          )
        ]),
      ),
    );
  }

  Future<PdfPageImage?> _renderPage(
      PdfDocument document, int pageNumber) async {
    final page = await document.getPage(pageNumber);
    final pageImage = await page.render(
      width: page.width * 2,
      height: page.height * 2,
      format: PdfPageImageFormat.png,
    );
    await page.close();
    return pageImage;
  }
}





class ImageLoader extends StatelessWidget {
  ImageLoader({
    required this.storage,
    required this.document,
    required this.pageNumber,
    Key? key,
  }) : super(key: key);

  final Map<int, PdfPageImage?> storage;
  final PdfDocument? document;
  final int pageNumber;

  @override
  Widget build(BuildContext context) => Center(
        child: FutureBuilder(
          future: _renderPage(),
          builder: (context, AsyncSnapshot<PdfPageImage?> snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('Error'),
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            return Image(
              image: MemoryImage(snapshot.data!.bytes),
            );
          },
        ),
      );

  Future<PdfPageImage?> _renderPage() async {
    if (storage.containsKey(pageNumber)) {
      return storage[pageNumber];
    }
    final page = await document!.getPage(pageNumber);
    final pageImage = await page.render(
      width: page.width * 2,
      height: page.height * 2,
      format: PdfPageImageFormat.png,
    );
    await page.close();
    storage[pageNumber] = pageImage;
    return pageImage;
  }
}

