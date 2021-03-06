library angular2.src.analysis.analyzer_plugin.src.model;

import 'dart:collection';
import 'package:analyzer/dart/element/element.dart' as dart;
import 'package:analyzer/dart/element/type.dart' as dart;
import 'package:analyzer/dart/ast/ast.dart' as dart;
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/generated/source.dart' show Source, SourceRange;
import 'package:analyzer/src/generated/utilities_general.dart';
import 'package:analyzer/task/model.dart' show AnalysisTarget;
import 'package:angular_analyzer_plugin/src/selector.dart';
import 'package:angular_analyzer_plugin/src/standard_components.dart';
import 'package:angular_analyzer_plugin/ast.dart';
import 'package:angular_analyzer_plugin/tasks.dart';

/// An abstract model of an Angular directive.
abstract class AbstractDirective {
  /// The [ClassElement] this annotation is associated with.
  final dart.ClassElement classElement;

  final AngularElement exportAs;
  final List<InputElement> inputs;
  final List<OutputElement> outputs;
  final Selector selector;
  final List<ElementNameSelector> elementTags;
  final attributes = <AngularElement>[];

  bool get isHtml;

  /// Which fields have been marked `@ContentChild`, and the range of the type
  /// argument. The element model contains the rest. This should be stored in the
  /// summary, so that at link time we can report errors discovered in the model
  /// against the range we saw it the AST.
  List<ContentChildField> contentChildrenFields;
  List<ContentChildField> contentChildFields;
  final contentChilds = <ContentChild>[];
  final contentChildren = <ContentChild>[];

  /// Its very hard to tell which directives are meant to be used with a *star.
  /// However, any directives which have a `TemplateRef` as a constructor
  /// parameter are almost certainly meant to be used with one. We use this for
  /// whatever validation we can, and autocomplete suggestions.
  bool looksLikeTemplate = false;

  AbstractDirective(this.classElement,
      {this.exportAs,
      this.inputs,
      this.outputs,
      this.selector,
      this.elementTags,
      this.contentChildFields,
      this.contentChildrenFields});

  /// The source that contains this directive.
  Source get source => classElement.source;

  @override
  String toString() => '$runtimeType(${classElement.displayName} '
      'selector=$selector '
      'inputs=$inputs '
      'outputs=$outputs '
      'attributes=$attributes)';

  @override
  bool operator ==(Object other) =>
      other is AbstractDirective && other.classElement == classElement;

  @override
  int get hashCode => classElement.hashCode;
}

/// The base class for all Angular elements.
abstract class AngularElement {
  /// Return the name of this element, not `null`.
  String get name;

  /// Return the length of the name of this element in the file that contains
  /// the declaration of this element.
  int get nameLength;

  /// Return the offset of the name of this element in the file that contains
  /// the declaration of this element.
  int get nameOffset;

  /// Return the [Source] of this element.
  Source get source;
}

/// The base class for concrete implementations of an [AngularElement].
class AngularElementImpl implements AngularElement {
  @override
  final String name;

  @override
  final int nameOffset;

  @override
  final int nameLength;

  @override
  final Source source;

  AngularElementImpl(this.name, this.nameOffset, this.nameLength, this.source);

  @override
  int get hashCode => JenkinsSmiHash.hash4(
      name.hashCode, nameOffset, nameLength, source.hashCode);

  @override
  bool operator ==(Object other) =>
      other is AngularElement &&
      other.runtimeType == runtimeType &&
      other.nameOffset == nameOffset &&
      other.nameLength == nameLength &&
      other.name == name &&
      other.source == source;

  @override
  String toString() => name;
}

abstract class AbstractQueriedChildType {
  bool match(
      ElementInfo element, StandardAngular angular, ErrorReporter reporter);
}

class TemplateRefQueriedChildType extends AbstractQueriedChildType {
  @override
  bool match(NodeInfo element, StandardAngular _, ErrorReporter __) =>
      element is ElementInfo && element.localName == 'template';
}

class ElementRefQueriedChildType extends AbstractQueriedChildType {
  @override
  bool match(NodeInfo element, StandardAngular _, ErrorReporter __) =>
      element is ElementInfo &&
      element.localName != 'template' &&
      !element.directives.any((boundDirective) =>
          boundDirective is Component && !boundDirective.isHtml);
}

class LetBoundQueriedChildType extends AbstractQueriedChildType {
  final String letBoundName;
  final dart.DartType containerType;
  LetBoundQueriedChildType(this.letBoundName, this.containerType);
  @override
  bool match(NodeInfo element, StandardAngular angular,
          ErrorReporter errorReporter) =>
      element is ElementInfo &&
      element.attributes.any((attribute) {
        if (attribute is TextAttribute && attribute.name == '#$letBoundName') {
          _validateMatch(element, attribute, angular, errorReporter);
          return true;
        }
        return false;
      });

  /// Validate against a matching [TextAttribute] on a matching [ElementInfo],
  /// for assignability to [containerType] errors.
  void _validateMatch(ElementInfo element, TextAttribute attr,
      StandardAngular angular, ErrorReporter errorReporter) {
    dart.DartType matchType;

    if (attr.value != "" && attr.value != null) {
      final possibleDirectives =
          element.directives.where((d) => d.exportAs.name == attr.value);
      if (possibleDirectives.isEmpty || possibleDirectives.length > 1) {
        // Don't validate based on an invalid state (that's reported as such).
        return;
      }
      // TODO instantiate this type to bounds
      matchType = possibleDirectives.first.classElement.type;
    } else if (element.localName == 'template') {
      matchType = angular.templateRef.type;
    } else {
      final possibleComponents =
          element.directives.where((d) => d is Component && !d.isHtml);
      if (possibleComponents.length > 1) {
        // Don't validate based on an invalid state (that's reported as such).
        return;
      }

      if (possibleComponents.isEmpty) {
        matchType = angular.elementRef.type;
      } else {
        // TODO instantiate this type to bounds
        matchType = possibleComponents.first.classElement.type;
      }
    }

    // Don't do isAssignable. Because we KNOW downcasting makes no sense here.
    if (!containerType.isSupertypeOf(matchType)) {
      errorReporter.reportErrorForOffset(
          AngularWarningCode.MATCHED_LET_BINDING_HAS_WRONG_TYPE,
          element.offset,
          element.length,
          [letBoundName, containerType, matchType]);
    }
  }
}

class DirectiveQueriedChildType extends AbstractQueriedChildType {
  final AbstractDirective directive;
  DirectiveQueriedChildType(this.directive);
  @override
  bool match(NodeInfo element, StandardAngular _, ErrorReporter __) =>
      element is ElementInfo &&
      element.directives.any((boundDirective) => boundDirective == directive);
}

class ContentChildField {
  final String fieldName;
  final SourceRange nameRange;
  final SourceRange typeRange;

  ContentChildField(this.fieldName, {this.nameRange, this.typeRange});
}

class ContentChild {
  final ContentChildField field;
  final AbstractQueriedChildType query;

  /// Look up a symbol from the injector. We don't track the injector yet.
  final String read;

  ContentChild(this.field, this.query, {this.read});
}

/// The model of an Angular component.
class Component extends AbstractDirective {
  View view;
  @override
  final bool isHtml;

  /// List of <ng-content> selectors in this component's view
  final ngContents = <NgContent>[];

  Component(dart.ClassElement classElement,
      {AngularElement exportAs,
      List<InputElement> inputs,
      List<OutputElement> outputs,
      Selector selector,
      List<ElementNameSelector> elementTags,
      this.isHtml,
      List<NgContent> ngContents,
      List<ContentChildField> contentChildFields,
      List<ContentChildField> contentChildrenFields})
      : super(classElement,
            exportAs: exportAs,
            inputs: inputs,
            outputs: outputs,
            selector: selector,
            elementTags: elementTags,
            contentChildFields: contentChildFields,
            contentChildrenFields: contentChildrenFields) {
    this.ngContents.addAll(ngContents ?? []);
  }

  List<ExportedIdentifier> get exports => view?.exports ?? [];
}

/// An [AngularElement] representing a [dart.Element].
class DartElement extends AngularElementImpl {
  final dart.Element element;

  DartElement(dart.Element element)
      : element = element,
        super(element.name, element.nameOffset, element.nameLength,
            element.source);
}

/// The model of an Angular directive.
class Directive extends AbstractDirective {
  @override
  bool get isHtml => false;

  Directive(dart.ClassElement classElement,
      {AngularElement exportAs,
      List<InputElement> inputs,
      List<OutputElement> outputs,
      Selector selector,
      List<ElementNameSelector> elementTags,
      List<ContentChildField> contentChildFields,
      List<ContentChildField> contentChildrenFields})
      : super(classElement,
            exportAs: exportAs,
            inputs: inputs,
            outputs: outputs,
            selector: selector,
            elementTags: elementTags,
            contentChildFields: contentChildFields,
            contentChildrenFields: contentChildrenFields);
}

/// An Angular template in an HTML file.
class HtmlTemplate extends Template {
  /// The [Source] of the template.
  final Source source;

  HtmlTemplate(View view, this.source) : super(view);
}

/// The model for an Angular input.
class InputElement extends AngularElementImpl {
  final dart.PropertyAccessorElement setter;

  final dart.DartType setterType;

  /// The [SourceRange] where [setter] is referenced in the input declaration.
  /// May be the same as this element offset/length in shorthand variants where
  /// names of a input and the setter are the same.
  final SourceRange setterRange;

  /// A given input can have an alternative name, or more 'conventional' name
  /// that differs from the name provided by dart:html source.
  /// For example: source -> 'className', but prefer 'class'.
  /// In this case, name = 'class' and originalName = 'originalName'.
  /// This should be null if there is no alternative name.
  final originalName;

  InputElement(String name, int nameOffset, int nameLength, Source source,
      this.setter, this.setterRange, this.setterType,
      {this.originalName})
      : super(name, nameOffset, nameLength, source);

  @override
  String toString() => 'InputElement($name, $nameOffset, $nameLength, $setter)';
}

/// The model for an Angular output.
class OutputElement extends AngularElementImpl {
  final dart.PropertyAccessorElement getter;

  final dart.DartType eventType;

  /// The [SourceRange] where [getter] is referenced in the input declaration.
  /// May be the same as this element offset/length in shorthand variants where
  /// names of a input and the getter are the same.
  final SourceRange getterRange;

  OutputElement(String name, int nameOffset, int nameLength, Source source,
      this.getter, this.getterRange, this.eventType)
      : super(name, nameOffset, nameLength, source);

  @override
  String toString() =>
      'OutputElement($name, $nameOffset, $nameLength, $getter)';
}

/// A pair of an [SourceRange] and the referenced [AngularElement].
class ResolvedRange {
  /// The [SourceRange] where [element] is referenced.
  final SourceRange range;

  /// The [AngularElement] referenced at [range].
  final AngularElement element;

  ResolvedRange(this.range, this.element);

  @override
  String toString() => '$range=[$element, '
      'nameOffset=${element.nameOffset}, '
      'nameLength=${element.nameLength}, '
      'source=${element.source}]';
}

class NgContent {
  final int offset;
  final int length;

  /// NOTE: May contain Null. Null in this case means no selector (all content).
  final Selector selector;
  final int selectorOffset;
  final int selectorLength;

  NgContent(this.offset, this.length)
      : selector = null,
        selectorOffset = null,
        selectorLength = null;

  NgContent.withSelector(this.offset, this.length, this.selector,
      this.selectorOffset, this.selectorLength);

  bool get matchesAll => selector == null;
}

/// An Angular template.
/// Templates can be embedded into Dart.
class Template {
  /// The [View] that describes the template.
  final View view;

  /// The [ResolvedRange]s of the template.
  final ranges = <ResolvedRange>[];

  /// The [ElementInfo] that begins the AST of the resolved template
  ElementInfo _ast;

  /// The errors that are ignored in this template
  final ignoredErrors = new HashSet<String>();

  Template(this.view);

  /// Records that the given [element] is referenced at the given [range].
  void addRange(SourceRange range, AngularElement element) {
    assert(range != null);
    assert(range.offset != null);
    assert(range.offset >= 0);
    ranges.add(new ResolvedRange(range, element));
  }

  @override
  String toString() => 'Template(ranges=$ranges)';

  ElementInfo get ast => _ast;
  set ast(ElementInfo ast) {
    if (_ast != null) {
      throw new StateError("AST is already set, shouldn't be set again");
    }

    _ast = ast;
  }
}

class ExportedIdentifier {
  final String prefix;
  final String identifier;
  final SourceRange span;
  dart.Element element;

  ExportedIdentifier(this.identifier, this.span,
      {this.element, this.prefix: ''});
}

/// The model of an Angular view.
class View implements AnalysisTarget {
  /// The [ClassElement] this view is associated with.
  final dart.ClassElement classElement;

  final Component component;
  final List<AbstractDirective> directives;
  final List<DirectiveReference> directiveReferences;
  final String templateText;
  final int templateOffset;
  final Source templateUriSource;
  final SourceRange templateUrlRange;
  final dart.Annotation annotation;

  final List<ExportedIdentifier> exports;

  Map<String, List<AbstractDirective>> _elementTagsInfo;

  int get end => templateOffset + templateText.length;

  Map<String, List<AbstractDirective>> get elementTagsInfo {
    if (_elementTagsInfo == null) {
      _elementTagsInfo = <String, List<AbstractDirective>>{};
      for (final directive in directives) {
        if (directive.elementTags != null && directive.elementTags.isNotEmpty) {
          for (final elementTag in directive.elementTags) {
            final tagName = elementTag.toString();
            _elementTagsInfo.putIfAbsent(tagName, () => <AbstractDirective>[]);
            _elementTagsInfo[tagName].add(directive);
          }
        }
      }
    }
    return _elementTagsInfo;
  }

  /// The [Template] of this view, `null` until built.
  Template template;

  View(this.classElement, this.component, this.directives,
      {this.templateText,
      this.templateOffset: 0,
      this.templateUriSource,
      this.templateUrlRange,
      this.annotation,
      this.directiveReferences,
      this.exports}) {
    // stability/error-recovery: @Component can be missing
    component?.view = this;
  }

  /// The source that contains this view.
  @override
  Source get source => classElement.source;

  /// The source that contains this template, [source] or [templateUriSource].
  Source get templateSource => templateUriSource ?? source;

  @override
  Source get librarySource => null;

  @override
  String toString() => 'View('
      'classElement=$classElement, '
      'component=$component, '
      'directives=$directives)';
}

class DirectiveReference {
  String name;
  String prefix;
  SourceRange range;

  DirectiveReference(this.name, this.prefix, this.range);
}
