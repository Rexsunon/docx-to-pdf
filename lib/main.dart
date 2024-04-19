import 'dart:io';

import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:docx_to_text/docx_to_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

const docUrl = 'DOCX_URL_HERE';

Future<String> downloadDocument(String url) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    // Get the temporary directory
    final directory = await getTemporaryDirectory();

    // Create a file in the temporary directory
    final file = File('${directory.path}/document.docx');

    // Write the document data to the file
    await file.writeAsBytes(response.bodyBytes);

    // Return the file path
    return file.path;
  } else {
    // Handle error
    if (kDebugMode) {
      print('Failed to download document');
    }
    return '';
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Docx to PDF',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Docx to Pdf'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String documentPath = '';
  String? extractedText;
  bool isLoading = false;
  String message = 'Click the download doc button!';

  Future<void> downloadAndSaveDocument() async {
    setState(() => isLoading = true);
    documentPath = await downloadDocument(docUrl);
    if (documentPath.isNotEmpty) {
      message = 'Document downloaded and saved at: $documentPath';
    }
    setState(() => isLoading = false);
  }

  Future<void> readDocx() async {
    setState(() => isLoading = true);
    final file = File(documentPath);
    final bytes = await file.readAsBytes();
    extractedText = docxToText(bytes);

    if (extractedText != null) {
      replaceTextPlaceholders(extractedText!);
    } else {
      message = 'Failed to extract text from document.';
    }
    setState(() => isLoading = false);
  }

  void replaceTextPlaceholders(String docString) {
    final now = DateTime.now();
    final formattedDate = DateFormat('MMMM d, yyyy').format(now);

    const companyName = 'ManyCarbon Inc.';
    const companyAddress = '123 Main Street, Anytown Lagos, Nigeria';

    const farmerName = 'John Doe';
    const farmerAddress = '456 Farm Road, Somewhere Lagos';
    const farmerEmail = 'john.doe@email.com';
    const farmerPhone = '08101664765';

    String updatedDocString = docString
        .replaceAll('Insert the date the document is signed.', formattedDate)
        .replaceAll('Insert Company Name', companyName)
        .replaceAll('Insert company address', companyAddress)
        .replaceAll('Name of farmer', farmerName)
        .replaceAll('Address of farmer', farmerAddress)
        .replaceAll('email address of farmer', farmerEmail)
        .replaceAll('phone number for farmer', farmerPhone)
        .replaceAll('Name of company', companyName);


    extractedText = updatedDocString;
  }

  Future<void> generateAndOpenPDF(String docString) async {

    // Create a PDF document
    final pdf = pw.Document();

    // Create a text style for the content
    const textStyle = pw.TextStyle(
      // font: await PdfGoogleFonts.notoSerifRegular(),
      fontSize: 12,
    );

    // Split the content into chunks
    final chunks = <String>[];
    final lines = docString.split('\n');
    var chunk = '';
    for (var line in lines) {
      if (chunk.isNotEmpty && (chunk + line).length > 2000) {
        chunks.add(chunk);
        chunk = '';
      }
      chunk += '$line\n';
    }
    if (chunk.isNotEmpty) chunks.add(chunk);

    // Create PDF pages
    for (var chunk in chunks) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(16.0),
                child: pw.Text(
                  chunk,
                  style: textStyle,
                ),
              ),
            );
          },
        ),
      );
    }

    // Save the PDF to a temporary file
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/document.pdf');
    await file.writeAsBytes(await pdf.save());

    // Open the PDF
    await OpenFile.open(file.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: isLoading ? const Center(child: CircularProgressIndicator()) : SizedBox(
                width: MediaQuery.sizeOf(context).width * 9,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Text(extractedText ?? message),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: extractedText != null && extractedText!.isNotEmpty ? ElevatedButton(
                child: const Text('Convert to PDF'),
                onPressed: () async => await generateAndOpenPDF(extractedText!),
              ): Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    child: const Text('Download doc'),
                    onPressed: () async => isLoading || documentPath.isNotEmpty ? null : await downloadAndSaveDocument(),
                  ),
                  ElevatedButton(
                    child: const Text('Extract text'),
                    onPressed: () async {
                      await readDocx();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
