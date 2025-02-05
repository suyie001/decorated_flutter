import 'dart:async';
import 'dart:math' as math;

import 'package:decorated_flutter/decorated_flutter.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

typedef bool _Equal<T>(T data1, T data2);
typedef Future<T> _Fetch<T, ARG_TYPE>(ARG_TYPE arg);
typedef Future<T> _PageFetch<T, ARG_TYPE>(int page, ARG_TYPE arg);

/// 业务单元基类
abstract class BaseIO<T> {
  BaseIO({
    /// 初始值, 传递给内部的[_subject]
    T seedValue,

    /// Event代表的语义
    @required String semantics,

    /// 是否同步发射数据, 传递给内部的[_subject]
    bool sync = true,

    /// 是否打印日志, 有些IO add比较频繁时, 影响日志观看
    bool printLog = true,

    /// 是否使用BehaviorSubject, 如果使用, 那么Event内部的[_subject]会保存最近一次的值
    bool isBehavior = true,
  })  : _semantics = semantics,
        _seedValue = seedValue,
        _printLog = printLog,
        latest = seedValue,
        _subject = isBehavior
            ? seedValue != null
                ? BehaviorSubject<T>.seeded(seedValue, sync: sync)
                : BehaviorSubject<T>(sync: sync)
            : PublishSubject<T>(sync: sync) {
    _subject.listen((data) {
      latest = data;
      if (_printLog)
        L.d('当前${semantics ??= data.runtimeType.toString()} latest: $latest'
            '\n+++++++++++++++++++++++++++END+++++++++++++++++++++++++++++');
    });
  }

  /// 最新的值
  T latest;

  /// 初始值
  @protected
  T _seedValue;

  /// 初始值
  @protected
  bool _printLog;

  /// 语义
  @protected
  String _semantics;

  /// 内部中转对象
  @protected
  Subject<T> _subject;

  void addError(Object error, [StackTrace stackTrace]) {
    if (_subject.isClosed) return;

    _subject.addError(error, stackTrace);
  }

  Stream<S> map<S>(S convert(T event)) {
    return _subject.map(convert);
  }

  Stream<T> where(bool test(T event)) {
    return _subject.where(test);
  }

  Stream<T> distinct([bool test(T previous, T next)]) {
    return test != null ? _subject.distinct(test) : _subject.distinct();
  }

  Stream<T> sample(Duration duration) {
    return _subject.sampleTime(duration);
  }

  /// 清理保存的值, 恢复成初始状态
  void reset() {
    if (_subject.isClosed) return;

    if (_printLog)
      L.d('-----------------------------BEGIN---------------------------------\n'
          '${_semantics ??= runtimeType.toString()}事件 重置 '
          '\n------------------------------END----------------------------------');
    _subject.add(_seedValue);
  }

  /// 重新发送数据 用户修改数据后刷新的场景
  void invalidate() {
    if (_subject.isClosed) return;

    _subject.add(latest);
  }

  /// 关闭流
  void dispose() {
    if (_subject.isClosed) return;

    if (_printLog)
      L.d('=============================BEGIN===============================\n'
          '${_semantics ??= runtimeType.toString()}事件 disposed '
          '\n==============================END================================');
    _subject.close();
  }

  /// 运行时概要
  String runtimeSummary() {
    return '$_semantics:\n\t\tseedValue: $_seedValue,\n\t\tlatest: $latest';
  }

  @override
  String toString() {
    return 'Output{latest: $latest, seedValue: $_seedValue, semantics: $_semantics, subject: $_subject}';
  }
}

/// BLoC内的静态值, 也就是供初始化时的值, 之前都是直接写成字段, 这里提供一个类, 保持与IO的一致性
class Static<T> {
  T _content;

  void set(T value) {
    _content = value;
  }

  T get() => _content;
}

/// 只输入数据的业务单元
class Input<T> extends BaseIO<T> with InputMixin {
  Input({
    T seedValue,
    @required String semantics,
    bool sync = true,
    bool isBehavior = true,
    bool printLog = true,
    bool acceptEmpty = true,
    bool isDistinct = false,
    _Equal<T> test,
  }) : super(
          seedValue: seedValue,
          semantics: semantics,
          sync: sync,
          isBehavior: isBehavior,
        ) {
    _acceptEmpty = acceptEmpty;
    _isDistinct = isDistinct;
    _test = test;
    _printLog = printLog;
  }
}

/// 只输出数据的业务单元
class Output<T, ARG_TYPE> extends BaseIO<T> with OutputMixin<T, ARG_TYPE> {
  Output({
    T seedValue,
    @required String semantics,
    bool sync = true,
    bool printLog = true,
    bool isBehavior = true,
    @required _Fetch<T, ARG_TYPE> fetch,
  }) : super(
          seedValue: seedValue,
          semantics: semantics,
          sync: sync,
          isBehavior: isBehavior,
        ) {
    stream = _subject.stream;
    _fetch = fetch;
    _printLog = printLog;
  }
}

/// 既可以输入又可以输出的事件
class IO<T> extends BaseIO<T> with InputMixin, OutputMixin<T, dynamic> {
  IO({
    T seedValue,
    @required String semantics,
    bool sync = true,
    bool isBehavior = true,
    bool acceptEmpty = true,
    bool isDistinct = false,
    bool printLog = true,
    _Equal<T> test,
    _Fetch<T, dynamic> fetch,
  }) : super(
          seedValue: seedValue,
          semantics: semantics,
          sync: sync,
          isBehavior: isBehavior,
        ) {
    stream = _subject.stream;

    _acceptEmpty = acceptEmpty;
    _isDistinct = isDistinct;
    _test = test;
    _fetch = fetch;
    _printLog = printLog;
  }
}

//region 衍生IO
/// 内部数据类型是[List]的输入业务单元
class ListInput<T> extends Input<List<T>> with ListMixin {
  ListInput({
    List<T> seedValue,
    @required String semantics,
    bool sync = true,
    bool isBehavior = true,
    bool acceptEmpty = true,
    bool printLog = true,
    bool isDistinct = false,
    int forceCapacity,
    _Equal<List<T>> test,
  }) : super(
          seedValue: seedValue,
          semantics: semantics,
          sync: sync,
          isBehavior: isBehavior,
          acceptEmpty: acceptEmpty,
          isDistinct: isDistinct,
          test: test,
          printLog: printLog,
        ) {
    _forceCapacity = forceCapacity;
  }
}

/// 内部数据类型是[List]的输出业务单元
///
/// 泛型[T]为列表项的类型
class ListOutput<T, ARG_TYPE> extends Output<List<T>, ARG_TYPE> with ListMixin {
  ListOutput({
    List<T> seedValue,
    @required String semantics,
    bool sync = true,
    bool isBehavior = true,
    bool printLog = true,
    int forceCapacity,
    @required _Fetch<List<T>, ARG_TYPE> fetch,
  }) : super(
          seedValue: seedValue,
          semantics: semantics,
          sync: sync,
          isBehavior: isBehavior,
          fetch: fetch,
          printLog: printLog,
        ) {
    _forceCapacity = forceCapacity;
  }
}

/// 分页业务单元
class PageOutput<T, ARG_TYPE> extends ListOutput<T, int>
    with PageMixin<T, ARG_TYPE> {
  PageOutput({
    List<T> seedValue,
    @required String semantics,
    bool sync = true,
    bool isBehavior = true,
    int initPage = 0,
    bool receiveFullData = true,
    bool printLog = true,
    int pageSize = 0,
    int forceCapacity,
    @required _PageFetch<List<T>, ARG_TYPE> pageFetch,
  }) : super(
          seedValue: seedValue,
          semantics: semantics,
          sync: sync,
          isBehavior: isBehavior,
          fetch: null,
        ) {
    _initPage = initPage;
    _currentPage = _initPage;
    _pageFetch = pageFetch;
    _receiveFullData = receiveFullData;
    _pageSize = pageSize;
    _printLog = printLog;
    _forceCapacity = forceCapacity;
  }

  /// 这里标记为protected, 防止被外部引用, 应该使用[refresh]方法
  @protected
  Future<List<T>> update([int arg]) {
    return super.update(arg);
  }
}

/// 分页业务单元
class PageIO<T, ARG_TYPE> extends ListIO<T> with PageMixin<T, ARG_TYPE> {
  PageIO({
    List<T> seedValue,
    @required String semantics,
    bool sync = true,
    bool isBehavior = true,
    int initPage = 0,
    int pageSize = 0,
    bool printLog = true,
    bool receiveFullData = true,
    int forceCapacity,
    @required _PageFetch<List<T>, ARG_TYPE> pageFetch,
  }) : super(
          seedValue: seedValue,
          semantics: semantics,
          sync: sync,
          isBehavior: isBehavior,
          fetch: null,
        ) {
    _initPage = initPage;
    _currentPage = _initPage;
    _pageFetch = pageFetch;
    _receiveFullData = receiveFullData;
    _pageSize = pageSize;
    _printLog = printLog;
    _forceCapacity = forceCapacity;
  }
}

/// 内部数据类型是[List]的输入输出业务单元
class ListIO<T> extends IO<List<T>> with ListMixin {
  ListIO({
    List<T> seedValue,
    @required String semantics,
    bool sync = true,
    bool isBehavior = true,
    bool acceptEmpty = true,
    bool isDistinct = false,
    bool printLog = true,
    int forceCapacity,
    _Equal<List<T>> test,
    _Fetch<List<T>, dynamic> fetch,
  }) : super(
          seedValue: seedValue,
          semantics: semantics,
          sync: sync,
          isBehavior: isBehavior,
          acceptEmpty: acceptEmpty,
          isDistinct: isDistinct,
          test: test,
          fetch: fetch,
          printLog: printLog,
        ) {
    _forceCapacity = forceCapacity;
  }
}

/// 只接收int类型数据的IO
class IntIO extends IO<int> with IntMixin {
  IntIO({
    int seedValue,
    @required String semantics,
    bool sync = true,
    bool isBehavior = true,
    bool acceptEmpty = true,
    bool isDistinct = false,
    bool printLog = true,
    _Equal<int> test,
    _Fetch<int, dynamic> fetch,
  }) : super(
          seedValue: seedValue,
          semantics: semantics,
          sync: sync,
          isBehavior: isBehavior,
          acceptEmpty: acceptEmpty,
          isDistinct: isDistinct,
          test: test,
          fetch: fetch,
          printLog: printLog,
        );
}

/// 只接收int类型数据的Input
class IntInput extends Input<int> with IntMixin {
  IntInput({
    int seedValue,
    @required String semantics,
    bool sync = true,
    bool isBehavior = true,
    bool acceptEmpty = true,
    bool isDistinct = false,
    int min,
    int max,
    bool printLog = true,
    _Equal<int> test,
    _Fetch<int, dynamic> fetch,
  }) : super(
          seedValue: seedValue,
          semantics: semantics,
          sync: sync,
          isBehavior: isBehavior,
          acceptEmpty: acceptEmpty,
          isDistinct: isDistinct,
          test: test,
          printLog: printLog,
        ) {
    this._min = min;
    this._max = max;
  }
}

/// 只接收bool类型数据的IO
class BoolIO extends IO<bool> with BoolMixin {
  BoolIO({
    bool seedValue,
    @required String semantics,
    bool sync = true,
    bool isBehavior = true,
    bool acceptEmpty = true,
    bool isDistinct = false,
    bool printLog = true,
    _Equal<bool> test,
    _Fetch<bool, dynamic> fetch,
  }) : super(
          seedValue: seedValue,
          semantics: semantics,
          sync: sync,
          isBehavior: isBehavior,
          acceptEmpty: acceptEmpty,
          isDistinct: isDistinct,
          test: test,
          fetch: fetch,
          printLog: printLog,
        );
}

/// 只接收bool类型数据的Output
class BoolOutput<ARG_TYPE> extends Output<bool, ARG_TYPE> with BoolMixin {
  BoolOutput({
    bool seedValue,
    @required String semantics,
    bool sync = true,
    bool isBehavior = true,
    bool printLog = true,
    _Fetch<bool, ARG_TYPE> fetch,
  }) : super(
          seedValue: seedValue,
          semantics: semantics,
          sync: sync,
          isBehavior: isBehavior,
          fetch: fetch,
          printLog: printLog,
        );
}

/// 没有数据, 只发射信号的IO
class Signal extends IO<dynamic> {
  Signal({@required String semantics})
      : super(
          semantics: semantics,
          isBehavior: false,
        );

  @override
  void reset() {
    // do nothing
  }

  // 隐藏add方法
  @protected
  @override
  void add(dynamic data) {
    super.add(data);
  }

  /// 发射信号
  void emit() {
    add(Object());
  }
}
//endregion

/// 输入单元特有的成员
///
/// 泛型[T]为数据数据的类型
mixin InputMixin<T> on BaseIO<T> {
  bool _acceptEmpty;
  bool _isDistinct;
  _Equal _test;

  /// 发射数据
  T add(T data) {
    if (_subject.isClosed) return null;

    if (_printLog)
      L.d('+++++++++++++++++++++++++++BEGIN+++++++++++++++++++++++++++++\n'
          'IO接收到**${_semantics ??= data.runtimeType.toString()}**数据: $data');

    if (isEmpty(data) && !_acceptEmpty) {
      if (_printLog)
        L.d('转发被拒绝! 原因: 需要非Empty值, 但是接收到Empty值'
            '\n+++++++++++++++++++++++++++END+++++++++++++++++++++++++++++++');
      return data;
    }

    // 如果需要distinct的话, 就判断是否相同; 如果不需要distinct, 直接发射数据
    if (_isDistinct) {
      // 如果是不一样的数据, 才发射新的通知,防止TabBar的addListener那种
      // 不停地发送通知(但是值又是一样)的情况
      if (_test != null) {
        if (!_test(latest, data)) {
          if (_printLog)
            L.d('IO转发出**${_semantics ??= data.runtimeType.toString()}**数据: $data');
          _subject.add(data);
        } else {
          if (_printLog)
            L.d('转发被拒绝! 原因: 需要唯一, 但是没有通过唯一性测试'
                '\n+++++++++++++++++++++++++++END+++++++++++++++++++++++++++++');
        }
      } else {
        if (data != latest) {
          if (_printLog)
            L.d('IO转发出**${_semantics ??= data.runtimeType.toString()}**数据: $data');
          _subject.add(data);
        } else {
          if (_printLog)
            L.d('转发被拒绝! 原因: 需要唯一, 但是新数据与最新值相同'
                '\n+++++++++++++++++++++++++++END+++++++++++++++++++++++++++++');
        }
      }
    } else {
      if (_printLog)
        L.d('IO转发出**${_semantics ??= data.runtimeType.toString()}**数据: $data');
      _subject.add(data);
    }

    return data;
  }

  T addIfAbsent(T data) {
    if (_subject.isClosed) return null;

    // 如果最新值是_seedValue或者是空, 那么才add新数据, 换句话说, 就是如果event已经被add过
    // 了的话那就不add了, 用于第一次add
    if (_seedValue == latest || isEmpty(latest)) {
      add(data);
    }
    return data;
  }

  Future<T> addStream(Stream<T> source, {bool cancelOnError: true}) {
    return _subject.addStream(source, cancelOnError: cancelOnError);
  }
}

/// 输出单元特有的成员
///
/// 泛型[T]为输出数据的类型, 泛型[ARG_TYPE]为请求数据时的参数类型. 一般参数只有一个时, 就
/// 直接使用该参数的类型, 如果有多个时, 就使用List接收.
mixin OutputMixin<T, ARG_TYPE> on BaseIO<T> {
  /// 输出Future
  Future<T> get future => stream.first;

  /// 输出Stream
  Stream<T> stream;

  /// 监听流
  StreamSubscription<T> listen(
    ValueChanged<T> listener, {
    Function onError,
    VoidCallback onDone,
    bool cancelOnError,
  }) {
    return stream.listen(
      listener,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  /// 输出Stream
  _Fetch<T, ARG_TYPE> _fetch;

  /// 使用内部的trigger获取数据
  Future<T> update([ARG_TYPE arg]) {
    return _fetch(arg)
      ..then((data) {
        if (!_subject.isClosed) _subject.add(data);
      })
      ..catchError((error) {
        if (!_subject.isClosed) _subject.addError(error);
      });
  }
}

/// 内部数据是[List]特有的成员
mixin ListMixin<T> on BaseIO<List<T>> {
  /// 强制内部列表最大长度, 超过这个长度后, 如果是从前面添加数据则弹出最后的数据, 从后面添加则反之.
  int _forceCapacity;

  /// 按条件过滤, 并发射过滤后的数据
  List<T> filterItem(bool test(T element)) {
    if (_subject.isClosed) return null;

    final filtered = latest.where(test).toList();
    _subject.add(filtered);
    return filtered;
  }

  /// 追加, 并发射
  T append(T element, {bool fromHead = false}) {
    if (_subject.isClosed) return null;

    if (fromHead) {
      final pending = latest..insert(0, element);
      // 从前面添加, 就把后面的挤出去
      if (_forceCapacity != null && pending.length > _forceCapacity) {
        pending.removeLast();
      }
      _subject.add(pending);
    } else {
      final pending = latest..add(element);
      // 从后面添加, 就把前面的挤出去
      if (_forceCapacity != null && pending.length > _forceCapacity) {
        pending.removeAt(0);
      }
      _subject.add(pending);
    }
    return element;
  }

  /// 追加一个list, 并发射
  List<T> appendAll(List<T> elements, {bool fromHead = false}) {
    if (_subject.isClosed) return null;

    if (fromHead) {
      final pending = latest..insertAll(0, elements);
      // 从前面添加, 就把后面的挤出去
      if (_forceCapacity != null && pending.length > _forceCapacity) {
        pending.removeRange(_forceCapacity - 1, pending.length);
      }
      _subject.add(pending);
    } else {
      final pending = latest..addAll(elements);
      // 从后面添加, 就把前面的挤出去
      if (_forceCapacity != null && pending.length > _forceCapacity) {
        pending.removeRange(0, _forceCapacity);
      }
      _subject.add(pending);
    }
    return elements;
  }

  /// 对list的item做变换之后重新组成list
  Stream<List<S>> flatMap<S>(S mapper(T value)) {
    return _subject.map((list) => list.map(mapper).toList());
  }

  /// 替换指定index的元素, 并发射
  T replace(int index, T element) {
    if (_subject.isClosed) return null;

    _subject.add(latest..replaceRange(index, index + 1, <T>[element]));
    return element;
  }

  /// 替换最后一个的元素, 并发射
  T replaceLast(T element) {
    if (_subject.isClosed) return null;

    if (latest.isNotEmpty) {
      _subject.add(latest
        ..replaceRange(
          latest.length - 1,
          latest.length,
          [element],
        ));
    }
    return element;
  }

  /// 替换第一个的元素, 并发射
  T replaceFirst(T element) {
    if (_subject.isClosed) return null;

    if (latest.isNotEmpty) {
      _subject.add(latest..replaceRange(0, 1, [element]));
    }
    return element;
  }

  /// 删除最后一个的元素, 并发射
  T removeLast() {
    if (_subject.isClosed) return null;

    final lastElement = latest.last;
    if (latest.isNotEmpty) {
      _subject.add(latest..removeLast());
    }
    return lastElement;
  }

  /// 删除一个的元素, 并发射
  T remove(T element) {
    if (_subject.isClosed) return null;

    _subject.add(latest..remove(element));
    return element;
  }

  /// 删除一组的元素, 并发射
  Iterable<T> removeBatch(Iterable<T> elements) {
    if (_subject.isClosed) return null;

    _subject.add(latest..removeWhere((it) => elements.contains(it)));
    return elements;
  }

  /// 删除指定条件的元素
  void removeWhere(bool test(T t)) {
    if (_subject.isClosed) return;

    _subject.add(latest..removeWhere(test));
  }

  /// 删除第一个的元素, 并发射
  T removeFirst() {
    if (_subject.isClosed) return null;

    final firstElement = latest.first;
    if (latest.isNotEmpty) {
      _subject.add(latest..removeAt(0));
    }
    return firstElement;
  }

  /// 删除指定索引的元素, 并发射
  T removeAt(int index) {
    if (_subject.isClosed) return null;

    final element = latest.elementAt(index);
    if (element != null) {
      _subject.add(latest..removeAt(index));
    }
    return element;
  }

  /// 对元素逐个执行操作后, 重新发射
  List<T> forEach(ValueChanged<T> action) {
    if (_subject.isClosed) return null;

    latest.forEach(action);
    _subject.add(latest);
    return latest;
  }

  /// 对[target]进行单选操作, 如果[T]不为[Selectable]则什么都不做, 直接透传
  List<T> select(T target) {
    if (_subject.isClosed) return null;

    assert(latest is List<Selectable>);
    return forEach((T data) {
      if (data is Selectable) {
        data.selected = (data == target);
      }
    });
  }
}

mixin BoolMixin on BaseIO<bool> {
  /// 切换true/false 并发射
  bool toggle() {
    if (_subject.isClosed) return null;

    final toggled = !latest;
    _subject.add(toggled);
    return toggled;
  }
}

mixin IntMixin on BaseIO<int> {
  int _min;
  int _max;

  /// 加一个值 并发射
  int plus([int value = 1]) {
    if (_subject.isClosed) return null;

    int result;
    if (_max != null) {
      result = math.min(latest + value, _max);
    } else {
      result = latest + value;
    }
    if (!_subject.isClosed) {
      _subject.add(result);
    }
    return result;
  }

  /// 减一个值 并发射
  int minus([int value = 1]) {
    if (_subject.isClosed) return null;

    int result;
    if (_min != null) {
      result = math.max(latest - value, _min);
    } else {
      result = latest - value;
    }
    _subject.add(result);
    return result;
  }
}

mixin PageMixin<T, ARG_TYPE> on ListMixin<T> {
  /// 初始页 因为后端业务对初始页的定义不一定一样, 这里提供设置参数
  int _initPage;

  /// nextPage时, 是否add整个列表, 为false时, 只add最新一页的数据
  bool _receiveFullData;

  /// 当前页数
  int _currentPage = 0;

  /// 全部数据
  List<T> _dataList = [];

  /// 是否还有更多数据
  ///
  /// 两种策略判断:
  ///   1. 设置过[_pageSize], 则判断当前页列表大小是否小于[_pageSize],
  ///   如果是, 那么当前页就是最后一页, 不需要再请求下一页
  ///   2. 没有设置过[_pageSize], 那么判断当前页是否为空列表.
  bool _noMoreData = false;

  /// 每页大小 用于判断是否已加载完全部数据
  int _pageSize = 0;

  _PageFetch<List<T>, ARG_TYPE> _pageFetch;

  /// 请求下一页数据
  ///
  /// 返回是否还有更多数据 true为还有更多数据 false为没有更多数据
  @Deprecated('使用[loadMore]代替, 仅仅是名称替换')
  Future<bool> nextPage([ARG_TYPE args]) async {
    // 如果已经没有更多数据的话, 就不再请求
    if (!_noMoreData) {
      try {
        final nextPageData = await _pageFetch(++_currentPage, args);
        if (_receiveFullData) {
          _dataList = [..._dataList, ...nextPageData];
        } else {
          _dataList = nextPageData;
        }
        // 如果当前页列表大小已经小于设置的每页大小, 那么说明已经到最后一页
        // 或者当前页是空, 也说明已经是最后一页
        _noMoreData = nextPageData.length < _pageSize || nextPageData.isEmpty;

        if (_subject.isClosed) return false;
        _subject.add(_dataList);
      } catch (e) {
        if (_subject.isClosed) return false;
        _subject.addError(e);
      }
    }
    return !_noMoreData;
  }

  /// 请求下一页数据
  ///
  /// 返回是否还有更多数据 true为还有更多数据 false为没有更多数据
  Future<bool> loadMore([ARG_TYPE args]) async {
    // 如果已经没有更多数据的话, 就不再请求
    if (!_noMoreData) {
      try {
        final nextPageData = await _pageFetch(++_currentPage, args);
        if (_receiveFullData) {
          _dataList = [..._dataList, ...nextPageData];
        } else {
          _dataList = nextPageData;
        }
        // 如果当前页列表大小已经小于设置的每页大小, 那么说明已经到最后一页
        // 或者当前页是空, 也说明已经是最后一页
        _noMoreData = nextPageData.length < _pageSize || nextPageData.isEmpty;

        if (_subject.isClosed) return false;
        _subject.add(_dataList);
      } catch (e) {
        if (_subject.isClosed) return false;
        _subject.addError(e);
      }
    }
    return !_noMoreData;
  }

  /// 刷新列表
  ///
  /// 会重新加载第一页
  Future<void> refresh([ARG_TYPE args]) async {
    _currentPage = _initPage;
    _noMoreData = false;
    try {
      _dataList = await _pageFetch(_currentPage, args);

      if (_subject.isClosed) return false;
      _subject.add(_dataList);
    } catch (e) {
      if (_subject.isClosed) return false;
      _subject.addError(e);
    }
  }

  /// 当前是否是第一页
  bool get isFirstPage {
    return _currentPage == _initPage;
  }

  /// 是否还有更多数据
  bool get hasMoreData {
    return !_noMoreData;
  }
}

/// 内部数据是[EvictingQueue]特有的成员
mixin EvictingQueueMixin<T> on BaseIO<EvictingQueue<T>> {
  /// 追加, 并发射
  T append(T element, {bool fromHead = false}) {
    if (_subject.isClosed) return null;

    if (fromHead) {
      _subject.add(latest..addFirst(element));
    } else {
      _subject.add(latest..add(element));
    }
    return element;
  }

  /// 对list的item做变换之后重新组成list
  Stream<List<S>> flatMap<S>(S mapper(T value)) {
    return _subject.map((list) => list.map(mapper).toList());
  }

  /// 删除一个的元素, 并发射
  T remove(T element) {
    if (_subject.isClosed) return null;

    _subject.add(latest..remove(element));
    return element;
  }

  /// 删除指定条件的元素
  void removeWhere(bool test(T t)) {
    if (_subject.isClosed) return;

    _subject.add(latest..removeWhere(test));
  }

  /// 删除第一个的元素, 并发射
  T removeFirst() {
    if (_subject.isClosed) return null;

    final firstElement = latest.first;
    if (latest.isNotEmpty) {
      _subject.add(latest..removeFirst());
    }
    return firstElement;
  }
}
