import 'dart:async';

import 'package:angular_ast/angular_ast.dart';
import 'package:angular_analyzer_plugin/src/angular_driver.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:analysis_server/plugin/edit/fix/fix_core.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart'
    hide AnalysisError, Element, ElementKind;

import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/src/utilities/change_builder/change_builder_core.dart';

class AngularFixContributor {
  Future<List<Fix>> computeFixes(AngularFixContext context) async {
    final processor = new AngularFixProcessor(context);
    final fixes = await processor.compute();
    return fixes;
    //Todo: Catch on CancelCorrectionException?
  }
}

/// An object used to provide information
/// for [AngularFixContributor]s. A context is
/// created for each error found.
class AngularFixContext {
  final AngularDriver angularDriver;
  final Template template;
  final AnalysisError error;

  AngularFixContext(this.angularDriver, this.template, this.error);
}

/// A computer for Angular fixes.
///
/// Primary role is to map a given error to the
/// fixes needed to resolve the error. One Processor
/// is made per error.
class AngularFixProcessor {
  AnalysisError error;
  AngularDriver driver;
  Template template;

  int errorOffset;
  int errorLength;
  int errorEnd;
  SourceRange errorRange;

  final changeBuilder = new ChangeBuilderImpl();
  final List<Fix> fixes = <Fix>[];

  AngularFixProcessor(AngularFixContext ngContext) {
    error = ngContext.error;
    driver = ngContext.angularDriver;
    template = ngContext.template;
  }

  Future<List<Fix>> compute() async {
    errorOffset = error.offset;
    errorLength = error.length;
    errorEnd = error.offset + error.length;
    errorRange = new SourceRange(errorOffset, errorLength);

    final errorCode = error.errorCode;

    if (errorCode == NgParserWarningCode.SUFFIX_PROPERTY) {
      final a = 5;
    }

    return fixes;
  }
}
