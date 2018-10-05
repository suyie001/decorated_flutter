import 'dart:async';

import 'package:flutter/material.dart';
import 'package:framework/framework.dart';
import 'package:meta/meta.dart';

typedef Widget FutureWidgetBuilder<DATA>(DATA data);

class FutureWidget<T> extends StatelessWidget {
  final Future<T> future;
  final FutureWidgetBuilder<T> builder;
  final bool showLoading;
  final T initialData;
  final bool isExpanded;
  final Widget emptyWidget;
  final Widget errorWidget;

  const FutureWidget({
    Key key,
    @required this.future,
    @required this.builder,
    this.showLoading = true,
    this.isExpanded = false,
    this.initialData,
    this.emptyWidget,
    this.errorWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      initialData: initialData,
      future: future,
      builder: (ctx, snapshot) {
        if (snapshot.hasError) {
          return errorWidget ?? ErrorWidget(snapshot.error.toString());
        }

        if (snapshot.hasData) {
          return builder(snapshot.data);
        } else if (showLoading) {
          return LoadingWidget();
        } else if (isExpanded) {
          return Expanded(child: EmptyWidget());
        } else {
          return emptyWidget ?? EmptyWidget();
        }
      },
    );
  }
}
