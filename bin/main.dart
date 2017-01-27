import 'dart:io';

import 'package:args/args.dart';

import 'replay_stream.dart';

// Initial structure at this point based off https://www.dartlang.org/tutorials/dart-vm/cmdline
// While 'ls' was chosen prior to looking at docs, a "dumb" version is defined https://www.dartlang.org/guides/libraries/library-tour#dartio---io-for-command-line-apps (Listing files in a directory)

void main(List<String> args) {
  exitCode = 0;
  final parser = new ArgParser()
      ..addFlag('a', abbr: 'a')
      ..addFlag('A', abbr: 'A')
      ..addFlag('l', abbr: 'l');
  //TODO: need some better way to handle these options as "args" doesn't allow naming something without using it as an argument (AKA: the name 'a' can be used --a or -a when it should ONLY be -a, and is referenced 'a')

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
    var dirEntitiesList = await dirEntities.toList();

    if (!parsedArgs['A'] && parsedArgs['a']) {
      dirEntitiesList.insert(0, dir); //TODO: figure out how, for specified directories, to get their representation as a '.'
      if (dir.parent != dir) {
        dirEntitiesList.insert(1, dir.parent); //TODO: building on top of ^^, how do we get this represented by ..? (Currently it seems to just print out '.' regardless of what dir is)
      }
    }
    //TODO: alphabetize list, ignoring the '.', though . and .. come first

    var allowDotNames = parsedArgs['A'] || parsedArgs['a'];
    if (parsedArgs['l']) {
      writeLongFormEntities(dir, dirEntitiesList, consoleWidthInChars, allowDotNames);
    } else {
      writeTabulatedEntities(dirEntitiesList, consoleWidthInChars, allowDotNames);
    }
  } else {
    stderr.writeln('ls: cannot access ${dir.path}: No such file or directory');
  }
}

// ------- Utility -------

String getFileSystemEntitiyName(FileSystemEntity entity, bool allowDotNames) {
  var entitySegments = entity.uri.pathSegments;

  var entityName = entitySegments.last;
  if (entityName.isEmpty) {
    entityName = entitySegments[entitySegments.length - 2]; // Get the second-to-last
  }

  // Shortcut for later usage in when printing (we skip empty entries, if this is a dot name (.git), then we can just skip it)
  if (entityName.isNotEmpty) {
    if (!allowDotNames && entityName[0] == '.') {
      return '';
    }
  }

  return entityName;
}

Future<String> printDataSize(FileSystemEntity entity) async {
  var stat = await entity.stat();

  //TODO: support other formats
  return stat.size.toString();
}

String getEntityTypeString(FileSystemEntity entity) {
  if (entity is Directory) {
  	return 'd';
  } else {
  	return '-';
  }
}

Future<int> entitiesInDirectory(Directory dir, bool allowDotNames) async {
  var dirEntities = dir.list();

  var count = 0;
  await for (FileSystemEntity entity in dirEntities) {
  	var entityName = getFileSystemEntitiyName(entity, allowDotNames);

    if (entityName.isNotEmpty) {
      count++;
  	}
  }

  return count;
}

String createStringPadding(String value, int columnWidth, int maxWidth) { //XXX Is that max width?
  var paddingLength = columnWidth - value.length;
  var paddingCodes = new List<int>.filled(paddingLength.clamp(0, maxWidth), 0x20);
  return new String.fromCharCodes(paddingCodes);
}

String rightPadString(String value, int columnWidth, int maxWidth) { //XXX Is that max width?
  return '${value}${createStringPadding(value, columnWidth, maxWidth)}';
}

String leftPadString(String value, int columnWidth, int maxWidth) { //XXX Is that max width?
  return '${createStringPadding(value, columnWidth, maxWidth)}${value}';
}

// ----- Long Format -----

void writeLongFormEntities(Directory dir, List<FileSystemEntity> dirEntities, num consoleWidthInChars, bool allowDotNames) async {
  stdout.writeln('total ${await printDataSize(dir)}');

  //Need to calculate column widths
  var linkColumn = 0;
  var sizeColumn = 0;
  for (FileSystemEntity entity in dirEntities) {
    var entityName = getFileSystemEntitiyName(entity, allowDotNames);

    if (entityName.isNotEmpty) {
      var entityStat = await entity.stat();

      if (entity is Directory) {
      	var entityCount = await entitiesInDirectory(entity as Directory, allowDotNames);
      	var entityCountWidth = entityCount.toString().length;
      	if (entityCountWidth > linkColumn) {
	      linkColumn = entityCountWidth;
	    }
      } else if (linkColumn == 0) {
      	linkColumn = 1;
      }

      var sizeWidth = entityStat.size.toString().length;
      if (sizeWidth > sizeColumn) {
      	sizeColumn = sizeWidth;
      }
    }
  }

  // Write actual file strings
  for (FileSystemEntity entity in dirEntities) {
    var entityName = getFileSystemEntitiyName(entity, allowDotNames);

    if (entityName.isNotEmpty) {
      var entityStat = await entity.stat();

      var linkCount = 0;
      if (entity is Directory) {
      	linkCount = await entitiesInDirectory(entity as Directory, allowDotNames);
      } else {
      	linkCount = 1;
      }

      stdout.write('${getEntityTypeString(entity)}${entityStat.modeString()}. '); //Permissions //TODO: the '.' at the end can mean something. Docs don't say very well
      stdout.write('${leftPadString(linkCount.toString(), linkColumn, consoleWidthInChars)} '); //Link count
      //TODO: owner
      //TODO: group
      stdout.write('${leftPadString(entityStat.size.toString(), sizeColumn, consoleWidthInChars)} '); //Size
      //TODO: date and time
      stdout.writeln(entityName);
    }
  }
}

// ------ Tabulated ------

//TODO: suddenly, this no longer appears to be writing in columns?
void writeTabulatedEntities(List<FileSystemEntity> dirEntities, num consoleWidthInChars, bool allowDotNames) {
  var wroteNewline = false;
  var columnIndex = 0;
  var columnWidths = calculateColumnWidths(dirEntities, consoleWidthInChars, allowDotNames);

  //TODO: write in column format (see notes for example)

  for (FileSystemEntity entity in dirEntities) {
    var entityName = getFileSystemEntitiyName(entity, allowDotNames);

    if (entityName.isNotEmpty) {
      wroteNewline = false;

      var paddedEntity = rightPadString(entityName, columnWidths[columnIndex++], consoleWidthInChars);
      stdout.write(paddedEntity);

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
