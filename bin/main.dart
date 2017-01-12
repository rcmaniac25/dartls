import 'dart:io';

import 'package:args/args.dart';

// Initial structure at this point based off https://www.dartlang.org/tutorials/dart-vm/cmdline
// While 'ls' was chosen prior to looking at docs, a "dumb" version is defined https://www.dartlang.org/guides/libraries/library-tour#dartio---io-for-command-line-apps (Listing files in a directory)

void main(List<String> args) {
  exitCode = 0;
  final parser = new ArgParser();

  //TODO: figure out how to get console width (and what happens when the console is resized)

  var parsedArgs = parser.parse(args);
  var files = parsedArgs.rest;

  Directory dir;
  if (files.isEmpty) {
  	dir = Directory.current;
  } else {
  	dir = new Directory(files[0]);
  }

  processArgumentsAndRun(dir, parsedArgs);
}

Future processArgumentsAndRun(Directory dir, ArgResults parsedArgs) async {
  if (await dir.exists()) {
  	var valuesWritten = false;

  	var dirEntities = dir.list();
  	await for (FileSystemEntity entity in dirEntities) {
  	  var entitySegments = entity.uri.pathSegments;
  	  
  	  var entityName = entitySegments.last;
  	  if (entityName.isEmpty) {
  	  	entityName = entitySegments[entitySegments.length - 2]; // Get the second-to-last
	  }

  	  if (entityName.isNotEmpty) {
  	  	if (entityName[0] != '.') {
  	  	  stdout.write("${entityName}${valuesWritten ? ' ' : ''}");
  	  	  valuesWritten = true;
  	  	}
  	  }
  	}
  	stdout.writeln();
  } else {
  	stderr.writeln('ls: cannot access ${dir.path}: No such file or directory');
  }
}