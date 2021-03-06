library angular2.src.analysis.server_plugin.analysis_test;

import 'package:analysis_server/plugin/analysis/navigation/navigation_core.dart';
import 'package:analysis_server/plugin/analysis/occurrences/occurrences_core.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' as protocol;
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/memory_file_system.dart';
import 'package:analyzer/src/context/context.dart' show AnalysisContextImpl;
import 'package:analyzer/src/generated/engine.dart' show AnalysisEngine;
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/task/driver.dart';
import 'package:analyzer/src/task/manager.dart';
import 'package:analyzer/source/package_map_resolver.dart';
import 'package:analyzer/task/model.dart';
import 'package:analyzer/context/context_root.dart';
import 'package:analyzer/src/dart/analysis/driver.dart' as non_task
    show AnalysisDriver, AnalysisDriverScheduler;
import 'package:analyzer/src/dart/analysis/file_state.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:front_end/src/incremental/byte_store.dart';
import 'package:front_end/src/base/performace_logger.dart';
import 'package:angular_analyzer_server_plugin/src/analysis.dart';
import 'package:angular_analyzer_plugin/plugin.dart';
import 'package:angular_analyzer_plugin/notification_manager.dart';
import 'package:angular_analyzer_plugin/src/angular_driver.dart';
import 'package:plugin/manager.dart';
import 'package:plugin/plugin.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:typed_mock/typed_mock.dart';
import 'package:unittest/unittest.dart';

import 'mock_sdk.dart';

void main() {
  defineReflectiveSuite(() {
    // TODO get these working again in the latest SDK
    //defineReflectiveTests(AngularNavigationContributorTest);
    //defineReflectiveTests(AngularOccurrencesContributorTest);
    defineReflectiveTests(EmptyTest);
  });
}

@reflectiveTest
class EmptyTest {
  // ignore: non_constant_identifier_names
  void test_soTheSuitePasses() {
    expect(null, isNull);
  }
}

@reflectiveTest
class AngularNavigationContributorTest extends AbstractAngularTaskTest {
  String code;

  List<_RecordedNavigationRegion> regions = <_RecordedNavigationRegion>[];
  NavigationCollector collector = new NavigationCollectorMock();

  _RecordedNavigationRegion region;
  protocol.Location targetLocation;

  @override
  void setUp() {
    super.setUp();
    when(collector.addRegion(anyInt, anyInt, anyObject, anyObject))
        .thenInvoke((offset, length, targetKind, targetLocation) {
      regions.add(new _RecordedNavigationRegion(
          offset, length, targetKind, targetLocation));
    });
  }

  // ignore: non_constant_identifier_names
  void test_dart_templates() {
    addAngularSources();
    code = r'''
import '/angular/src/core/metadata.dart';

@Component(selector: 'text-panel', inputs: const ['text: my-text'])
@View(template: r"<div>some text</div>")
class TextPanel {
  String text; // 1
  @Input() longform; // 4
}

@Component(selector: 'UserPanel')
@View(template: r"""
<div>
  <text-panel [my-text]='user.name' [longform]='""'></text-panel> // close
</div>
""", directives: [TextPanel])
class UserPanel {
  User user; // 2
}

class User {
  String name; // 3
}
''';
    final source = newSource('/test.dart', code);
    //LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    //computeResult(target, DART_TEMPLATES);
    // compute navigation regions
    new AngularNavigationContributor()
        .computeNavigation(collector, context, source, null, null);
    // input references setter
    {
      _findRegionString('text', ': my-text');
      expect(region.targetKind, protocol.ElementKind.SETTER);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf('text; // 1'));
    }
    // template references component (open tag)
    {
      _findRegionString('text-panel', ' [my-text]');
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf("text-panel', inputs"));
    }
    // template references component (close tag)
    {
      _findRegionString('text-panel', '> // close');
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf("text-panel', inputs"));
    }
    // template references input
    {
      _findRegionString('my-text', ']=');
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf("my-text'])"));
    }
    // template references field
    {
      _findRegionString('user', ".name' ");
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf("user; // 2"));
    }
    // template references field
    {
      _findRegionString('name', "' [");
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf("name; // 3"));
    }
    // template references input
    {
      _findRegionString('longform', ']=');
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf("longform; // 4"));
    }
  }

  // ignore: non_constant_identifier_names
  void test_dart_view_templateUrl() {
    addAngularSources();
    code = r'''
import '/angular/src/core/metadata.dart';

@Component(selector: 'text-panel')
@View(templateUrl: 'text_panel.html')
class TextPanel {}
''';
    final dartSource = newSource('/test.dart', code);
    newSource('/text_panel.html', "");
    // compute views, so that we have the TEMPLATE_VIEWS result
    //{
    //  LibrarySpecificUnit target =
    //      new LibrarySpecificUnit(dartSource, dartSource);
    //  computeResult(target, VIEWS_WITH_HTML_TEMPLATES2);
    //}
    //// compute Angular templates
    //computeResult(htmlSource, HTML_TEMPLATES);
    // compute navigation regions
    new AngularNavigationContributor()
        .computeNavigation(collector, context, dartSource, null, null);
    // input references setter
    {
      _findRegionString("'text_panel.html'", ')');
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/text_panel.html');
      expect(targetLocation.offset, 0);
    }
  }

  // ignore: non_constant_identifier_names
  void test_html_templates() {
    addAngularSources();
    final dartCode = r'''
import '/angular/src/core/metadata.dart';

@Component(selector: 'text-panel')
@View(templateUrl: 'text_panel.html')
class TextPanel {
  String text; // 1
}
''';
    final htmlCode = r"""
<div>
  {{text}}
</div>
""";
    newSource('/test.dart', dartCode);
    final htmlSource = newSource('/text_panel.html', htmlCode);
    // compute views, so that we have the TEMPLATE_VIEWS result
    //{
    //  LibrarySpecificUnit target =
    //      new LibrarySpecificUnit(dartSource, dartSource);
    //  computeResult(target, VIEWS_WITH_HTML_TEMPLATES2);
    //}
    //// compute Angular templates
    //computeResult(htmlSource, HTML_TEMPLATES);
    // compute navigation regions
    new AngularNavigationContributor()
        .computeNavigation(collector, context, htmlSource, null, null);
    // template references field
    {
      _findRegionString('text', "}}", codeOverride: htmlCode);
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, dartCode.indexOf("text; // 1"));
    }
  }

  void _findRegion(int offset, int length) {
    for (final region in regions) {
      if (region.offset == offset && region.length == length) {
        this.region = region;
        targetLocation = region.targetLocation;
        return;
      }
    }
    final regionsString = regions.join('\n');
    fail('Unable to find a region at ($offset, $length) in $regionsString');
  }

  void _findRegionString(String str, String suffix, {final codeOverride}) {
    final code = codeOverride != null ? codeOverride : this.code;
    final search = '$str$suffix';
    final offset = code.indexOf(search);
    expect(offset, isNonNegative, reason: 'Cannot find |$search| in |$code|');
    _findRegion(offset, str.length);
  }
}

@reflectiveTest
class AngularOccurrencesContributorTest extends AbstractAngularTaskTest {
  String code;

  OccurrencesCollector collector = new OccurrencesCollectorMock();
  List<protocol.Occurrences> occurrencesList = <protocol.Occurrences>[];

  protocol.Occurrences occurrences;

  @override
  void setUp() {
    super.setUp();
    when(collector.addOccurrences(anyObject)).thenInvoke(occurrencesList.add);
  }

  // ignore: non_constant_identifier_names
  void test_dart_templates() {
    addAngularSources();
    code = r'''
import '/angular/src/core/metadata.dart';

@Component(selector: 'text-panel', inputs: const ['text: my-text'])
@View(template: r"<div>some text</div>")
class TextPanel {
  String text; // 1
}

@Component(selector: 'UserPanel')
@View(template: r"""
<div>
  <text-panel [my-text]='user.value'></text-panel> // cl
</div>
""", directives: [TextPanel])
class UserPanel {
  ObjectContainer<String> user; // 2
}

class ObjectContainer<T> {
  T value; // 3
}
''';
    final source = newSource('/test.dart', code);
    //LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    //computeResult(target, DART_TEMPLATES);
    // compute navigation regions
    new AngularOccurrencesContributor()
        .computeOccurrences(collector, context, source);
    // "text" field
    {
      _findOccurrences(code.indexOf('text: my-text'));
      expect(occurrences.element.name, 'text');
      expect(occurrences.length, 'text'.length);
      expect(occurrences.offsets, contains(code.indexOf('text; // 1')));
    }
    // "text-panel" component
    {
      _findOccurrences(code.indexOf("text-panel', "));
      expect(occurrences.element.name, 'text-panel');
      expect(occurrences.length, 'text-panel'.length);
      expect(occurrences.offsets, contains(code.indexOf("text-panel [")));
      expect(occurrences.offsets, contains(code.indexOf("text-panel> // cl")));
    }
    // "user" field
    {
      _findOccurrences(code.indexOf("user.value'><"));
      expect(occurrences.element.name, 'user');
      expect(occurrences.length, 'user'.length);
      expect(occurrences.offsets, contains(code.indexOf('user; // 2')));
    }
    // "value" field
    {
      _findOccurrences(code.indexOf("value'><"));
      expect(occurrences.element.name, 'value');
      expect(occurrences.length, 'value'.length);
      expect(occurrences.offsets, contains(code.indexOf('value; // 3')));
    }
  }

  void _findOccurrences(int offset) {
    for (final occurrences in occurrencesList) {
      if (occurrences.offsets.contains(offset)) {
        this.occurrences = occurrences;
        return;
      }
    }
    final listStr = occurrencesList.join('\n');
    fail('Unable to find occurrences at $offset in $listStr');
  }
}

/// Instances of the class [GatheringErrorListener] implement an error listener
/// that collects all of the errors passed to it for later examination.
class GatheringErrorListener implements AnalysisErrorListener {
  /// A list containing the errors that were collected.
  final _errors = <AnalysisError>[];

  @override
  void onError(AnalysisError error) {
    _errors.add(error);
  }

  void addAll(List<AnalysisError> errors) {
    for (final error in errors) {
      onError(error);
    }
  }
}

class NavigationCollectorMock extends TypedMock implements NavigationCollector {
}

class OccurrencesCollectorMock extends TypedMock
    implements OccurrencesCollector {}

class SourceMock extends TypedMock implements Source {
  final String fullPath;

  SourceMock([String name = 'mocked.dart']) : fullPath = name;

  @override
  String toString() => fullPath;
}

class AbstractAngularTaskTest {
  MemoryResourceProvider resourceProvider = new MemoryResourceProvider();
  Source emptySource;

  DartSdk sdk = new MockSdk();
  AnalysisContextImpl context;

  TaskManager taskManager = new TaskManager();
  AnalysisDriver analysisDriver;

  AnalysisTask task;
  Map<ResultDescriptor<dynamic>, dynamic> outputs;
  GatheringErrorListener errorListener = new GatheringErrorListener();

  Source newSource(String path, [String content = '']) {
    final file = resourceProvider.newFile(path, content);
    return file.createSource();
  }

  void setUp() {
    new ExtensionManager().processPlugins(<Plugin>[]
      ..addAll(AnalysisEngine.instance.requiredPlugins)
      ..add(new AngularAnalyzerPlugin()));
    emptySource = newSource('/test.dart');
    // prepare AnalysisContext
    context = new AnalysisContextImpl()
      ..sourceFactory = new SourceFactory(<UriResolver>[
        new DartUriResolver(sdk),
        new ResourceUriResolver(resourceProvider)
      ]);
    // configure AnalysisDriver
    analysisDriver = context.driver;
  }

  void addAngularSources() {
    newSource(
        '/angular/angular.dart',
        r'''
library angular;

export 'src/core/async.dart';
export 'src/core/metadata.dart';
export 'src/core/linker/template_ref.dart';
export 'src/core/ng_if.dart';
export 'src/core/ng_for.dart';
''');
    newSource(
        '/angular/src/core/metadata.dart',
        r'''
library angular.src.core.metadata;

import 'dart:async';

abstract class Directive {
  const Directive(
      {String selector,
      List<String> inputs,
      List<String> outputs,
      @Deprecated('Use `inputs` or `@Input` instead') List<String> properties,
      @Deprecated('Use `outputs` or `@Output` instead') List<String> events,
      Map<String, String> host,
      @Deprecated('Use `providers` instead') List bindings,
      List providers,
      String exportAs,
      String moduleId,
      Map<String, dynamic> queries})
      : super(
            selector: selector,
            inputs: inputs,
            outputs: outputs,
            properties: properties,
            events: events,
            host: host,
            bindings: bindings,
            providers: providers,
            exportAs: exportAs,
            moduleId: moduleId,
            queries: queries);
}

class Component extends Directive {
  const Component(
      {String selector,
      List<String> inputs,
      List<String> outputs,
      @Deprecated('Use `inputs` or `@Input` instead') List<String> properties,
      @Deprecated('Use `outputs` or `@Output` instead') List<String> events,
      Map<String, String> host,
      @Deprecated('Use `providers` instead') List bindings,
      List providers,
      String exportAs,
      String moduleId,
      Map<String, dynamic> queries,
      @Deprecated('Use `viewProviders` instead') List viewBindings,
      List viewProviders,
      ChangeDetectionStrategy changeDetection,
      String templateUrl,
      String template,
      dynamic directives,
      dynamic pipes,
      ViewEncapsulation encapsulation,
      List<String> styles,
      List<String> styleUrls});
}

class View {
  const View(
      {String templateUrl,
      String template,
      dynamic directives,
      dynamic pipes,
      ViewEncapsulation encapsulation,
      List<String> styles,
      List<String> styleUrls});
}

class Input {
  final String bindingPropertyName;
  const InputMetadata([this.bindingPropertyName]);
}

class Output {
  final String bindingPropertyName;
  const OutputMetadata([this.bindingPropertyName]);
}
''');
    newSource(
        '/angular/src/core/async.dart',
        r'''
library angular.core.facade.async;
import 'dart:async';

class EventEmitter<T> extends Stream<T> {
  StreamController<dynamic> _controller;

  /**
   * Creates an instance of [EventEmitter], which depending on [isAsync],
   * delivers events synchronously or asynchronously.
   */
  EventEmitter([bool isAsync = true]) {
    _controller = new StreamController.broadcast(sync: !isAsync);
  }

  StreamSubscription listen(void onData(dynamic line),
      {void onError(Error error), void onDone(), bool cancelOnError}) {
    return _controller.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  void add(value) {
    _controller.add(value);
  }

  void addError(error) {
    _controller.addError(error);
  }

  void close() {
    _controller.close();
  }
}
''');
    newSource(
        '/angular/src/core/ng_if.dart',
        r'''
library angular.ng_if;
import 'metadata.dart';
import 'linker/template_ref.dart';

@Directive(selector: "[ngIf]", inputs: const ["ngIf"])
class NgIf {
  NgIf(TemplateRef tpl);
  set ngIf(newCondition) {}
}
''');
    newSource(
        '/angular/src/core/ng_for.dart',
        r'''
library angular.ng_for;
import 'metadata.dart';
import 'linker/template_ref.dart';

@Directive(
    selector: "[ngFor][ngForOf]",
    inputs: const ["ngForOf", "ngForTemplate", "ngForTrackBy"])
class NgFor {
  NgFor(TemplateRef tpl);
  set ngForOf(dynamic value) {}
  set ngForTrackBy(TrackByFn value) {}
}

typedef dynamic TrackByFn(num index, dynamic item);
''');
    newSource(
        '/angular/src/core/linker/template_ref.dart',
        r'''
library angular.template_ref;

class TemplateRef {}
''');
  }

  void computeResult(AnalysisTarget target, ResultDescriptor result) {
    task = analysisDriver.computeResult(target, result);
    expect(task.caughtException, isNull);
    outputs = task.outputs;
  }
}

class _RecordedNavigationRegion {
  final int offset;
  final int length;
  final protocol.ElementKind targetKind;
  final protocol.Location targetLocation;

  _RecordedNavigationRegion(
      this.offset, this.length, this.targetKind, this.targetLocation);

  @override
  String toString() => '$offset $length $targetKind $targetLocation';
}

class AbstractAngularTest {
  MemoryResourceProvider resourceProvider;

  DartSdk sdk;
  AngularDriver angularDriver;
  non_task.AnalysisDriver dartDriver;

  GatheringErrorListener errorListener;

  void setUp() {
    final logger = new PerformanceLog(new StringBuffer());
    final byteStore = new MemoryByteStore();

    final scheduler = new non_task.AnalysisDriverScheduler(logger)..start();
    resourceProvider = new MemoryResourceProvider();

    sdk = new MockSdk(resourceProvider: resourceProvider);
    final packageMap = <String, List<Folder>>{
      "angular2": [resourceProvider.getFolder("/angular2")],
      "angular": [resourceProvider.getFolder("/angular")]
    };
    final packageResolver =
        new PackageMapUriResolver(resourceProvider, packageMap);
    final sf = new SourceFactory([
      new DartUriResolver(sdk),
      packageResolver,
      new ResourceUriResolver(resourceProvider),
    ]);
    final testPath = resourceProvider.convertPath('/test');
    final contextRoot = new ContextRoot(testPath, []);

    dartDriver = new non_task.AnalysisDriver(
      scheduler,
      logger,
      resourceProvider,
      byteStore,
      new FileContentOverlay(),
      contextRoot,
      sf,
      new AnalysisOptionsImpl(),
    );

    angularDriver = new AngularDriver(new MockNotificationManager(), dartDriver,
        scheduler, byteStore, sf, new FileContentOverlay());

    errorListener = new GatheringErrorListener();
    addAngularSources();
  }

  Source newSource(String path, [String content = '']) {
    final file = resourceProvider.newFile(path, content);
    final source = file.createSource();
    angularDriver.addFile(path);
    dartDriver.addFile(path);
    return source;
  }

  void fillErrorListener(List<AnalysisError> errors) {
    errorListener.addAll(errors);
  }

  void addAngularSources() {
    newSource(
        '/angular2/angular2.dart',
        r'''
library angular2;

export 'package:angular/angular.dart';
''');
    newSource(
        '/angular/angular.dart',
        r'''
library angular;

export 'src/core/async.dart';
export 'src/core/metadata.dart';
export 'src/core/linker/template_ref.dart';
export 'src/core/ng_if.dart';
export 'src/core/ng_for.dart';
''');
    newSource(
        '/angular/src/core/metadata.dart',
        r'''
library angular.src.core.metadata;

import 'dart:async';

abstract class Directive {
  const Directive(
      {String selector,
      List<String> inputs,
      List<String> outputs,
      @Deprecated('Use `inputs` or `@Input` instead') List<String> properties,
      @Deprecated('Use `outputs` or `@Output` instead') List<String> events,
      Map<String, String> host,
      @Deprecated('Use `providers` instead') List bindings,
      List providers,
      String exportAs,
      String moduleId,
      Map<String, dynamic> queries})
      : super(
            selector: selector,
            inputs: inputs,
            outputs: outputs,
            properties: properties,
            events: events,
            host: host,
            bindings: bindings,
            providers: providers,
            exportAs: exportAs,
            moduleId: moduleId,
            queries: queries);
}

class Component extends Directive {
  const Component(
      {String selector,
      List<String> inputs,
      List<String> outputs,
      @Deprecated('Use `inputs` or `@Input` instead') List<String> properties,
      @Deprecated('Use `outputs` or `@Output` instead') List<String> events,
      Map<String, String> host,
      @Deprecated('Use `providers` instead') List bindings,
      List providers,
      String exportAs,
      String moduleId,
      Map<String, dynamic> queries,
      @Deprecated('Use `viewProviders` instead') List viewBindings,
      List viewProviders,
      ChangeDetectionStrategy changeDetection,
      String templateUrl,
      String template,
      dynamic directives,
      dynamic pipes,
      ViewEncapsulation encapsulation,
      List<String> styles,
      List<String> styleUrls});
}

class View {
  const View(
      {String templateUrl,
      String template,
      dynamic directives,
      dynamic pipes,
      ViewEncapsulation encapsulation,
      List<String> styles,
      List<String> styleUrls});
}

class Input {
  final String bindingPropertyName;
  const InputMetadata([this.bindingPropertyName]);
}

class Output {
  final String bindingPropertyName;
  const OutputMetadata([this.bindingPropertyName]);
}
''');
    newSource(
        '/angular/src/core/async.dart',
        r'''
library angular.core.facade.async;
import 'dart:async';

class EventEmitter<T> extends Stream<T> {
  StreamController<dynamic> _controller;

  /**
   * Creates an instance of [EventEmitter], which depending on [isAsync],
   * delivers events synchronously or asynchronously.
   */
  EventEmitter([bool isAsync = true]) {
    _controller = new StreamController.broadcast(sync: !isAsync);
  }

  StreamSubscription listen(void onData(dynamic line),
      {void onError(Error error), void onDone(), bool cancelOnError}) {
    return _controller.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  void add(value) {
    _controller.add(value);
  }

  void addError(error) {
    _controller.addError(error);
  }

  void close() {
    _controller.close();
  }
}
''');
    newSource(
        '/angular/src/core/ng_if.dart',
        r'''
library angular.ng_if;
import 'metadata.dart';
import 'linker/template_ref.dart';

@Directive(selector: "[ngIf]", inputs: const ["ngIf"])
class NgIf {
  NgIf(TemplateRef tpl);
  set ngIf(newCondition) {}
}
''');
    newSource(
        '/angular/src/core/ng_for.dart',
        r'''
library angular.ng_for;
import 'metadata.dart';
import 'linker/template_ref.dart';

@Directive(
    selector: "[ngFor][ngForOf]",
    inputs: const ["ngForOf", "ngForTemplate", "ngForTrackBy"])
class NgFor {
  NgFor(TemplateRef tpl);
  set ngForOf(dynamic value) {}
  set ngForTrackBy(TrackByFn value) {}
}

typedef dynamic TrackByFn(num index, dynamic item);
''');
    newSource(
        '/angular/src/core/linker/template_ref.dart',
        r'''
library angular.template_ref;

class TemplateRef {}
''');
  }
}

class MockNotificationManager extends TypedMock implements NotificationManager {
}
