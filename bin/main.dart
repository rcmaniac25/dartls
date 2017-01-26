import 'dart:io';

import 'package:args/args.dart';

import 'replay_stream.dart';

// Initial structure at this point based off https://www.dartlang.org/tutorials/dart-vm/cmdline
// While 'ls' was chosen prior to looking at docs, a "dumb" version is defined https://www.dartlang.org/guides/libraries/library-tour#dartio---io-for-command-line-apps (Listing files in a directory)

void main(List<String> args) {
  exitCode = 0;
  final parser = new ArgParser()
      ..addFlag('a', abbr: 'a')
      ..addFlag('A', abbr: 'A');

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

    if (!parsedArgs['A'] && parsedArgs['a']) {
      dorEntitiesList.insert(0, dir); //TODO: figure out how, for specified directories, to get their representation as a '.'
      if (dir.parent != dir) {
      	dorEntitiesList.insert(1, dir.parent); //TODO: building on top of ^^, how do we get this represented by ..? (Currently it seems to just print out '.' regardless of what dir is)
      }
    }
    //TODO: alphabetize list, ignoring the '.', though . and .. come first

    //TODO: support list prints
    writeTabulatedEntities(dorEntitiesList, consoleWidthInChars, parsedArgs['A'] || parsedArgs['a']);
  } else {
    stderr.writeln('ls: cannot access ${dir.path}: No such file or directory');
  }
}

void writeTabulatedEntities(List<FileSystemEntity> dirEntities, num consoleWidthInChars, bool allowDotNames) {
  var wroteNewline = false;
  var columnIndex = 0;
  var columnWidths = calculateColumnWidths(dirEntities, consoleWidthInChars, allowDotNames);

  //TODO: write in column format (see notes for example)

  for (FileSystemEntity entity in dirEntities) {
    var entityName = getFileSystemEntitiyName(entity, allowDotNames);

    if (entityName.isNotEmpty) {
      wroteNewline = false;

      var paddingLength = columnWidths[columnIndex++] - entityName.length;
      var paddingCodes = new List<int>.filled(paddingLength.clamp(0, consoleWidthInChars), 0x20);
      var paddingString = new String.fromCharCodes(paddingCodes);

      stdout.write("${entityName}${paddingString}");

      if (columnIndex == columnWidths.length) {
      	stdout.writeln();
      	wroteNewline = true;
      	columnIndex = 0;
      }
    }
  }

  if (!wroteNewline) {
  	stdout.writeln();
  }
}

String getFileSystemEntitiyName(FileSystemEntity entity, bool allowDotNames) {
  var entitySegments = entity.uri.pathSegments;

  var entityName = entitySegments.last;
  if (entityName.isEmpty) {
    entityName = entitySegments[entitySegments.length - 2]; // Get the second-to-last
  }

  // Shortcut for later usage in writeTabulatedEntities
  if (entityName.isNotEmpty) {
    if (!allowDotNames && entityName[0] == '.') {
      return '';
    }
  }

  return entityName;
}

List<int> calculateColumnWidths(List<FileSystemEntity> dirEntities, num consoleWidthInChars, bool allowDotNames) {
  var totalLength = 0;
  var columns = new List<int>();

  for (FileSystemEntity entity in dirEntities) {
    var entityName = getFileSystemEntitiyName(entity, allowDotNames);

    if (entityName.isNotEmpty) {
      var entityLength = entityName.length;
      if (totalLength + entityLength > consoleWidthInChars) {
      	break;
      }

      // Space between chars unless it will make the padded string wrap to the next line
      var space = (totalLength + entityLength + 1) > consoleWidthInChars ? 0 : 1;
      columns.add(entityLength + space);
      totalLength += entityLength + space;

      //TODO: for every element, figure out the optimal column width (probably want to write a function to "write" the list, this way the column-wise formatting code doesn't need to be written twice)
    }
  }

  if (columns.isEmpty) {
  	columns.add(consoleWidthInChars);
  }

  return columns;
}
