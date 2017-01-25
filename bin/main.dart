import 'dart:io';

import 'package:args/args.dart';

import 'replay_stream.dart';

// Initial structure at this point based off https://www.dartlang.org/tutorials/dart-vm/cmdline
// While 'ls' was chosen prior to looking at docs, a "dumb" version is defined https://www.dartlang.org/guides/libraries/library-tour#dartio---io-for-command-line-apps (Listing files in a directory)

void main(List<String> args) {
  exitCode = 0;
  final parser = new ArgParser();

  //TODO: figure out what to do if terminalColumns is resized
  var consoleWidthInChars = stdout.terminalColumns;

  var parsedArgs = parser.parse(args);
  var files = parsedArgs.rest;

  Directory dir;
  if (files.isEmpty) {
    dir = Directory.current;
  } else {
    dir = new Directory(files[0]);
  }

  processArgumentsAndRun(dir, parsedArgs, consoleWidthInChars);
}

Future processArgumentsAndRun(Directory dir, ArgResults parsedArgs, num consoleWidthInChars) async {
  if (await dir.exists()) {
    var dirEntities = dir.list();
    var dorEntitiesList = await dirEntities.toList();
    writeTabulatedEntities(dorEntitiesList, consoleWidthInChars);
  } else {
    stderr.writeln('ls: cannot access ${dir.path}: No such file or directory');
  }
}

void writeTabulatedEntities(List<FileSystemEntity> dirEntities, num consoleWidthInChars) {
  var valuesWritten = false;
  var columnWiths = calculateColumnWidths(dirEntities, consoleWidthInChars);
  for (FileSystemEntity entity in dirEntities) {
    var entityName = getFileSystemEntitiyName(entity);

    //TODO: write each name to the column length
    if (entityName.isNotEmpty) {
      stdout.write("${entityName}${valuesWritten ? ' ' : ''}");
      valuesWritten = true;
    }
  }
  stdout.writeln();
}

String getFileSystemEntitiyName(FileSystemEntity entity) {
  var entitySegments = entity.uri.pathSegments;

  var entityName = entitySegments.last;
  if (entityName.isEmpty) {
    entityName = entitySegments[entitySegments.length - 2]; // Get the second-to-last
  }

  // Shortcut for later usage
  if (entityName.isNotEmpty) {
    if (entityName[0] == '.') {
      return '';
    }
  }

  return entityName;
}

List<int> calculateColumnWidths(List<FileSystemEntity> dirEntities, num consoleWidthInChars) {
  var totalLength = 0;
  var columns = new List<int>();
  for (FileSystemEntity entity in dirEntities) {
    var entityName = getFileSystemEntitiyName(entity);

    if (entityName.isNotEmpty) {
      //TODO: v1: for one full row, figure out the lengths to use
      //TODO: v2: for every element, figure out the row length
    }
  }
  return columns;
}
