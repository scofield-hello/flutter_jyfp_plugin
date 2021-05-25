import 'dart:async';
import 'dart:typed_data';

import 'package:JyFp/JyFp.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  JyFp _jyFp;

  String featureSrc;
  String featureDest;
  Uint8List bitmap;
  @override
  void initState() {
    super.initState();
    _jyFp = JyFp();
    _jyFp.onFeatureReceived.listen((feature) {
      if (feature != null) {
        _setFeature(feature);
      } else {
        print("未采集到指纹");
      }
    });
    _jyFp.onFpImageReceived.listen((bitmapData) {
      if (bitmapData != null) {
        setState(() {
          bitmap = bitmapData;
        });
      } else {
        print("指纹图片获取失败");
      }
    });
    _jyFp.onFingerReceived.listen((finger) {
      if (finger != null) {
        print("指纹质量:${finger.quality}");
        _setFeature(finger.feature);
        setState(() {
          bitmap = finger.bitmap;
        });
      }
    });
    initPlatformState();
  }

  _setFeature(String feature) {
    if (featureSrc == null) {
      featureSrc = feature;
      return;
    }
    if (featureSrc != null && featureDest == null) {
      featureDest = feature;
      return;
    }
    if (featureSrc != null && featureDest != null) {
      featureSrc = feature;
      return;
    }
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    try {
      _jyFp.init();
    } catch (e) {
      print(e);
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Container(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  FlatButton(
                      onPressed: () async {
                        var opened = await _jyFp.openFpModule();
                        print(opened);
                      },
                      child: Text("打开设备")),
                  FlatButton(
                      onPressed: () {
                        _jyFp.closeFpModule();
                      },
                      child: Text("关闭设备")),
                  FlatButton(
                      onPressed: () {
                        _jyFp.setFingerColor(false);
                      },
                      child: Text("设置红色")),
                  FlatButton(
                      onPressed: () {
                        _jyFp.setFingerMatchValue(60);
                      },
                      child: Text("设置比对相似度阈值")),
                  FlatButton(
                      onPressed: () {
                        _jyFp.setQualityThreshold(60);
                      },
                      child: Text("设置指纹质量")),
                  FlatButton(
                      onPressed: () {
                        _jyFp.getFpFeature();
                      },
                      child: Text("采集指纹Base64")),
                  FlatButton(
                      onPressed: () {
                        _jyFp.getFpImage();
                      },
                      child: Text("获取指纹图片")),
                  FlatButton(
                      onPressed: () {
                        _jyFp.getFingerInfo();
                      },
                      child: Text("采集指纹信息")),
                  FlatButton(
                      onPressed: () async {
                        var match = await _jyFp.compareFpFeature(featureSrc, featureDest, 60);
                        print("指纹匹配:$match");
                      },
                      child: Text("比对"))
                ],
              ),
              if (bitmap != null) Image.memory(bitmap, width: 80, height: 80, fit: BoxFit.contain)
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _jyFp.destroy();
    _jyFp.dispose();
    super.dispose();
  }
}
