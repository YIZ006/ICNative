import 'dart:io';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:icnative/settings/global.dart';
import 'package:path_provider/path_provider.dart';
import 'package:icnative/services/sticker_anchoring_engine.dart';

class ImagePreview extends StatefulWidget {
  const ImagePreview({super.key, required this.imagePath, required this.onSend});
final String imagePath;
final void Function() onSend;
  @override
  State<ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<ImagePreview> {
  late String currentImagePath;
  bool isProcessing = true;

  @override
  void initState() {
    super.initState();
    currentImagePath = widget.imagePath;
    _runAiEngine();
  }

  Future<void> _runAiEngine() async {
    try {
      // 2. Run Engine (Base Model + Saliency)
      final newPath = await StickerAnchoringEngine.processAndMerge(widget.imagePath);
      if (newPath != null) {
        setState(() {
          currentImagePath = newPath;
        });
      }
    } catch (e) {
      print('AI Engine Error: $e');
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 600,

      child: Scaffold(
        backgroundColor: const Color(0xff1d1b20),
        body: Container(
          padding: const EdgeInsets.symmetric(vertical: 10,horizontal: 15),
          height: 500,
          width: MediaQuery.of(context).size.width,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

                Container(
                  height: MediaQuery.of(context).size.width,
                  width: MediaQuery.of(context).size.width,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    image: DecorationImage(
                      image: FileImage(File(currentImagePath)),
                      fit: BoxFit.cover
                    )
                  ),
                  child: isProcessing ? Center(child: CircularProgressIndicator()) : null,
                ),
                Container(
                  height: MediaQuery.of(context).size.height*0.1,
                  width: MediaQuery.of(context).size.width,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [

                      IconButton(onPressed: () async {
                        // 1. Save image to persistent storage
                        final directory = await getApplicationDocumentsDirectory();
                        final fileName = 'widget_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
                        final savedImage = await File(currentImagePath).copy('${directory.path}/$fileName');
                        
                        // 2. Add to history
                        images.add(savedImage.path);
                        
                        // 3. Update Home Widget
                        await HomeWidget.saveWidgetData<String>('widget_image_path', savedImage.path);
                        await HomeWidget.updateWidget(
                          name: 'ICNativeWidgetProvider',
                        );

                        widget.onSend();
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      }, icon: const Icon(Icons.send,size: 50,),),

                    ],
                  ),
                )
            ],
          ),
        )
      ),
    );
  }
}
