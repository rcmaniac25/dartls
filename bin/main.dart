import 'dart:io';

import 'package:args/args.dart';

void main(List<String> args) {
  exitCode = 0;
  final parser = new ArgParser();

  var parsedArgs = parser.parse(args);
  var files = parsedArgs.rest;

  Directory dir;
  if (files.isEmpty) {
  	dir = Directory.current;
  } else {
  	dir = new Directory(files[0]); // XXX Does not appear to be handling relative paths as documented...
  }

  processArguments(dir, parsedArgs);
}

Future processArguments(Directory dir, ArgResults parsedArgs) {
  // TODO
  print('Dir ${dir.path}');
}