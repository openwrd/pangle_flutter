import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config_android.dart';
import 'config_ios.dart';
import 'size.dart';

final kBannerViewType = 'nullptrx.github.io/pangle_bannerview';

typedef void BannerViewCreatedCallback(BannerViewController controller);

/// Display banner AD
/// PlatformView does not support Android API level 19 or below.
class BannerView extends StatefulWidget {
  final IOSBannerAdConfig iOS;
  final AndroidBannerAdConfig android;

  const BannerView({
    Key key,
    this.iOS,
    this.android,
    this.onBannerViewCreated,
  }) : super(key: key);

  final BannerViewCreatedCallback onBannerViewCreated;

  @override
  State<StatefulWidget> createState() => _BannerViewState();
}

class _BannerViewState extends State<BannerView>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  BannerViewController _controller;
  bool offstage = true;
  bool removed = false;
  double adWidth = kPangleSize;
  double adHeight = kPangleSize;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    remove();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _controller?._update(_createParams());
  }

  void remove() {
    setState(() {
      this.removed = true;
    });
    _controller?.remove();
    _controller = null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Widget body;
    try {
      Widget platformView;
      if (defaultTargetPlatform == TargetPlatform.android) {
        platformView = AndroidView(
          viewType: kBannerViewType,
          onPlatformViewCreated: (index) =>
              _onPlatformViewCreated(context, index),
          creationParams: _createParams(),
          creationParamsCodec: const StandardMessageCodec(),
          // BannerView content is not affected by the Android view's layout direction,
          // we explicitly set it here so that the widget doesn't require an ambient
          // directionality.
          layoutDirection: TextDirection.ltr,
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        platformView = UiKitView(
          viewType: kBannerViewType,
          onPlatformViewCreated: (index) =>
              _onPlatformViewCreated(context, index),
          creationParams: _createParams(),
          creationParamsCodec: const StandardMessageCodec(),
          // BannerView content is not affected by the Android view's layout direction,
          // we explicitly set it here so that the widget doesn't require an ambient
          // directionality.
          layoutDirection: TextDirection.ltr,
        );
      }
      if (platformView != null) {
        if (removed) {
          body = SizedBox.shrink();
        } else {
          body = Offstage(
            offstage: offstage,
            child: Container(
              color: Colors.white,
              width: adWidth,
              height: adHeight,
              child: platformView,
            ),
          );
        }
      }
    } on PlatformException {}
    if (body == null) {
      body = SizedBox.shrink();
    }

    return body;
  }

  @override
  void didUpdateWidget(BannerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller?._update(_createParams());
  }

  void _onPlatformViewCreated(BuildContext context, int id) {
    final removed = () {
      remove();
    };
    final updated = (args) {
      double width = args['width'];
      double height = args['height'];
      setState(() {
        this.offstage = false;
        this.adWidth = width;
        this.adHeight = height;
      });
    };

    var controller =
        BannerViewController._(id, onRemove: removed, onUpdate: updated);
    _controller = controller;
    if (widget.onBannerViewCreated == null) {
      return;
    }
    widget.onBannerViewCreated(controller);
  }

  void updateWidget(BuildContext context, bool success) {
    if (mounted) {
      setState(() {
        offstage = !success;
      });
    }
  }

  Map<String, dynamic> _createParams() {
    if (Platform.isIOS && widget.iOS != null) {
      return widget.iOS.toJSON();
    } else if (Platform.isAndroid && widget.android != null) {
      return widget.android.toJSON();
    }
    return {};
  }
}

enum BannerMethod {
  remove,
  reload,
}

class BannerViewController {
  MethodChannel _methodChannel;
  final VoidCallback onRemove;
  final SizeCallback onUpdate;

  BannerViewController._(
    int id, {
    this.onRemove,
    this.onUpdate,
  }) {
    _methodChannel = new MethodChannel('${kBannerViewType}_$id');
    _methodChannel.setMethodCallHandler(_handleMethod);
  }

  void remove() {
    this._methodChannel = null;
  }

  Future<dynamic> _handleMethod(MethodCall call) {
    switch (call.method) {
      case 'remove':
        if (onRemove != null) {
          onRemove();
        }
        break;
      case 'update':
        final params = call.arguments as Map<dynamic, dynamic>;
        if (onUpdate != null) {
          onUpdate(params);
        }
        break;
      default:
        break;
    }
    return null;
  }

  Future<Null> _update(Map<String, dynamic> params) async {
    await _methodChannel?.invokeMethod('update', params);
  }
}
