import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

class JyFpEventType {
  static const EVENT_ON_FP_IMAGE_RECEIVED = 0;
  static const EVENT_ON_FEATURE_RECEIVED = 1;
  static const EVENT_ON_FINGER_RECEIVED = 2;
}

class FingerBean {
  ///指纹特征.
  final String feature;

  ///指纹图像.
  final Uint8List bitmap;

  ///指纹质量.
  final int quality;

  const FingerBean(this.feature, this.bitmap, this.quality)
      : assert(feature != null && feature.length > 0),
        assert(bitmap != null && bitmap.length > 0),
        assert(quality != null && quality >= 0);
}

class JyFp {
  static JyFp _instance;
  static const _channel = const MethodChannel('JyFp');
  static const _eventChannel = const EventChannel("JyFpEvent");
  factory JyFp() => _instance ??= JyFp._();

  void _onEvent(dynamic event) {
    switch (event["event"]) {
      case JyFpEventType.EVENT_ON_FP_IMAGE_RECEIVED:
        if (!_onFpImageReceived.isClosed) {
          _onFpImageReceived.add(event["bitmap"]);
        }
        break;
      case JyFpEventType.EVENT_ON_FINGER_RECEIVED:
        if (!_onFingerReceived.isClosed) {
          if (event["feature"] != null) {
            _onFingerReceived.add(FingerBean(event["feature"], event["bitmap"], event["quality"]));
          } else {
            _onFingerReceived.add(null);
          }
        }
        break;
      case JyFpEventType.EVENT_ON_FEATURE_RECEIVED:
        if (!_onFeatureReceived.isClosed) {
          _onFeatureReceived.add(event["feature"]);
        }
        break;
    }
  }

  JyFp._() {
    _eventChannel.receiveBroadcastStream().listen(_onEvent);
  }

  ///初始化指纹模块.
  ///在所有操作之前必须调用该方法，用于识别设备，连接指纹服务.
  Future<void> init() async {
    await _channel.invokeMethod('init');
  }

  ///打开已连接的指纹识别设备.
  ///返回[true]表示打开成功,[false]表示失败.
  Future<bool> openFpModule() async {
    return await _channel.invokeMethod('openFpModule');
  }

  ///关闭已连接的指纹识别设备.
  Future<void> closeFpModule() async {
    await _channel.invokeMethod('closeFpModule');
  }

  ///获取指纹图片.
  ///耗时操作，建议在IO线程中使用.
  Future<void> getFpImage() async {
    await _channel.invokeMethod('getFpImage');
  }

  ///获取指纹特征值.
  Future<void> getFpFeature() async {
    await _channel.invokeMethod('getFpFeature');
  }

  ///获取指纹对象.
  Future<void> getFingerInfo() async {
    await _channel.invokeMethod('getFingerInfo');
  }

  ///指纹匹配度比对.
  ///计算两组指纹的匹配度并返回比对结果.
  ///[featureSrc] 原指纹特征.
  ///[featureDest] 目标指纹特征.
  ///返回[true]表示匹配，[false]表示不匹配
  Future<bool> compareFpFeature(String featureSrc, String featureDest, [int threshold = 80]) async {
    assert(featureSrc != null && featureSrc.isNotEmpty, "指纹特征src不能为空.");
    assert(featureDest != null && featureDest.isNotEmpty, "指纹特征dest不能为空.");
    if (threshold != null) {
      assert(threshold >= 0 && threshold <= 100, "阈值必须在0至100之间.");
      return await _channel.invokeMethod(
          'compareFpFeature', {"src": featureSrc, "dest": featureDest, "threshold": threshold});
    } else {
      return await _channel
          .invokeMethod('compareFpFeature', {"src": featureSrc, "dest": featureDest});
    }
  }

  ///设置指纹比对值匹配阈值.
  ///[value] 比对匹配阈值 0-100区间 默认60.
  Future<void> setFingerMatchValue(int threshold) async {
    assert(threshold != null && threshold >= 0 && threshold <= 100, "阈值必须在0至100之间.");
    await _channel.invokeMethod('setFingerMatchValue', threshold);
  }

  ///获取当前的比对值匹配阈值.
  Future<int> getFingerMatchValue() async {
    return await _channel.invokeMethod('getFingerMatchValue');
  }

  ///返回两组指纹的匹配度.
  Future<int> getCompareValue(String featureSrc, String featureDest) async {
    assert(featureSrc != null && featureSrc.isNotEmpty, "指纹特征src不能为空.");
    assert(featureDest != null && featureDest.isNotEmpty, "指纹特征dest不能为空.");
    return await _channel.invokeMethod('getCompareValue', {"src": featureSrc, "dest": featureDest});
  }

  ///设置指纹颜色.
  ///目前只支持红色及黑色.
  ///[useDefault] true表示使用默认颜色黑色，false表示红色.
  Future<void> setFingerColor([bool useDefault = true]) async {
    await _channel.invokeMethod('setFingerColor', useDefault);
  }

  ///设置指纹质量阈值.
  ///质量阈值 0-100之间.
  Future<void> setQualityThreshold(int threshold) async {
    assert(threshold != null && threshold >= 0 && threshold <= 100, "阈值必须在0至100之间.");
    await _channel.invokeMethod('setQualityThreshold', threshold);
  }

  ///退出反注册销毁指纹设备.
  Future<void> destroy() async {
    await _channel.invokeMethod('destroy');
  }

  final _onFpImageReceived = StreamController<Uint8List>.broadcast();

  ///获取到指纹图片时触发.
  Stream<Uint8List> get onFpImageReceived => _onFpImageReceived.stream;

  final _onFeatureReceived = StreamController<String>.broadcast();

  ///获取到指纹特征时触发.
  Stream<String> get onFeatureReceived => _onFeatureReceived.stream;

  final _onFingerReceived = StreamController<FingerBean>.broadcast();

  ///获取到指纹信息时触发.
  Stream<FingerBean> get onFingerReceived => _onFingerReceived.stream;

  void dispose() {
    _onFpImageReceived.close();
    _onFeatureReceived.close();
    _onFingerReceived.close();
  }
}
