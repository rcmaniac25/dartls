import 'dart:io';

import 'package:args/args.dart';

const int _dataSizeBytes = 1;
const int _dataSizeHuman = 2;

const _monthStrings = const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

const _argumentAll = 'a';
const _argumentAllExceptHidden = 'A';
const _argumentLongFormat = 'l';
const _argumentHumanSizes = 'h';

// Initial structure at this point based off https://www.dartlang.org/tutorials/dart-vm/cmdline
// While 'ls' was chosen prior to looking at docs, a "dumb" version is defined https://www.dartlang.org/guides/libraries/library-tour#dartio---io-for-command-line-apps (Listing files in a directory)

void main(List<String> args) {
  exitCode = 0;
  final parser = new ArgParser()
      ..addFlag(_argumentAll, abbr: _argumentAll)
      ..addFlag(_argumentAllExceptHidden, abbr: _argumentAllExceptHidden)
      ..addFlag(_argumentLongFormat, abbr: _argumentLongFormat)
      ..addFlag(_argumentHumanSizes, abbr: _argumentHumanSizes);
  //TODO: need some better way to handle these options as "args" doesn't allow naming something without using it as an argument (AKA: the name 'a' can be used --a or -a when it should ONLY be -a, and is referenced 'a')

  var consoleWidthInChars = stdout.terminalColumns;

  var parsedArgs = parser.parse(args);
  var files = parsedArgs.rest;

  Directory dir;
  if (files.isEmpty) {
    dir = Directory.current;
  } else {
    dir = new Directory(files[0]);
  }

  // Dart's IO gets screwy if Directories aren't absolute
  if (!dir.isAbsolute) {
  	dir = new Directory(fixAbsolutePath(dir.absolute.path));
  }

  processArgumentsAndRun(dir, parsedArgs, consoleWidthInChars);
}

String fixAbsolutePath(String path) {
  var pathUri = new Uri.file(path);
  var cleanPath = pathUri.toFilePath();
  if (cleanPath[cleanPath.length - 1] == (Platform.isWindows ? '\\' : '/')) { // Extra '\' or '/' at the end screws up everything...
  	return cleanPath.substring(0, cleanPath.length - 1);
  }
  return cleanPath;
}

Future processArgumentsAndRun(Directory dir, ArgResults parsedArgs, num consoleWidthInChars) async {
  if (await dir.exists()) {
    var dirEntities = dir.list();
    var dirEntitiesList = await dirEntities.toList();

    if (!parsedArgs[_argumentAllExceptHidden] && parsedArgs[_argumentAll]) {
      dirEntitiesList.insert(0, dir);
      if (dir.parent.path != dir.path) {
        dirEntitiesList.insert(1, dir.parent);
      }
    }
    //TODO: alphabetize list, ignoring the '.', though . and .. come first

    var allowDotNames = parsedArgs[_argumentAllExceptHidden] || parsedArgs[_argumentAll];
    if (parsedArgs[_argumentLongFormat]) {
      var dataSizeType = _dataSizeBytes;
      if (parsedArgs[_argumentHumanSizes]) {
        dataSizeType = _dataSizeHuman;
      }
      writeLongFormEntities(dir, dirEntitiesList, consoleWidthInChars, allowDotNames, dataSizeType);
    } else {
      writeTabulatedEntities(dir, dirEntitiesList, consoleWidthInChars, allowDotNames);
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

Future<String> printDataSize(FileSystemEntity entity, int type) async {
  var stat = await entity.stat();
  return printDataSizeFromEntity(stat.size, type);
}

String printDataSizeFromEntity(int size, int type) {
  if (type == _dataSizeHuman) {
    //TODO: needs tweaking. I'm getting exponent notation...
    if (size < 1024) {
      return size.toString();
    }
    size /= 1024;
    if (size < 1024) {
      return '${size.toStringAsPrecision(2)}K';
    }
    size /= 1024;
    if (size < 1024) {
      return '${size.toStringAsPrecision(1)}M';
    }
    size /= 1024;
    if (size < 1024) {
      return '${size.toStringAsPrecision(1)}G';
    }
    size /= 1024;
    return '${size.toStringAsPrecision(1)}T';
  } else {
    return size.toString();
  }
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

String createStringPadding(String value, int columnWidth, int maxWidth, {int paddingChar = 0x20}) { //XXX Is that max width?
  var paddingLength = columnWidth - value.length;
  var paddingCodes = new List<int>.filled(paddingLength.clamp(0, maxWidth), paddingChar);
  return new String.fromCharCodes(paddingCodes);
}

String rightPadString(String value, int columnWidth, int maxWidth, {int paddingChar = 0x20}) { //XXX Is that max width?
  return '${value}${createStringPadding(value, columnWidth, maxWidth, paddingChar:paddingChar)}';
}

String leftPadString(String value, int columnWidth, int maxWidth, {int paddingChar = 0x20}) { //XXX Is that max width?
  return '${createStringPadding(value, columnWidth, maxWidth, paddingChar:paddingChar)}${value}';
}

DateTime subtractMonths(DateTime dateTime, int months) {
  final weekDuration = new Duration(days: 7);

  var desiredMonth = dateTime.month - months;
  if (desiredMonth < 1) {
    desiredMonth += 12;
  }

  //XXX: this is not going to produce proper dates
  while (dateTime.month != desiredMonth) {
    // One month of subtractions
    dateTime = dateTime.subtract(weekDuration)
        ..subtract(weekDuration)
        ..subtract(weekDuration)
        ..subtract(weekDuration);
  }

  return dateTime;
}

String getDesiredEntityName(Directory dir, FileSystemEntity entity, String realName) {
  if (entity.path == dir.path) {
    return '.';
  } else if (entity.path == dir.parent.path) {
    return '..';
  } else {
  	return realName;
  }
}

// ----- Long Format -----

void writeLongFormEntities(Directory dir, List<FileSystemEntity> dirEntities, num consoleWidthInChars, bool allowDotNames, int dataSizeType) async {
  stdout.writeln('total ${await printDataSize(dir, dataSizeType)}');

  var dateTimeThreshold = subtractMonths(new DateTime.now(), 6);

  //Need to calculate column widths
  var parsedEntities = new List();
  var linkColumn = 0;
  var sizeColumn = 0;
  var dateTimeDayColumn = 0;
  var dateTimeYearTimeColumn = 0;
  for (FileSystemEntity entity in dirEntities) {
    var entityName = getFileSystemEntitiyName(entity, allowDotNames);

    if (entityName.isNotEmpty) {
      var entityDetails = new Map();
      entityDetails['Name'] = getDesiredEntityName(dir, entity, entityName);
      entityDetails['Type'] = getEntityTypeString(entity);

      var entityStat = await entity.stat();
      entityDetails['Permissions'] = entityStat.modeString();

      // Link count
      if (entity is Directory) {
        var entityCount = await entitiesInDirectory(entity, allowDotNames);
        entityDetails['LinkCount'] = entityCount;

        var entityCountWidth = entityCount.toString().length;
        if (entityCountWidth > linkColumn) {
          linkColumn = entityCountWidth;
        }
      } else {
        entityDetails['LinkCount'] = 1;

        if (linkColumn == 0) {
          linkColumn = 1;
        }
      }

      // Size
      entityDetails['Size'] = entityStat.size;
      var sizeWidth = entityStat.size.toString().length;
      if (sizeWidth > sizeColumn) {
        sizeColumn = sizeWidth;
      }

      // Date/Time
      entityDetails['ModifiedMonth'] = _monthStrings[entityStat.modified.month];
      entityDetails['ModifiedDay'] = entityStat.modified.day.toString();
      if (entityStat.modified.isBefore(dateTimeThreshold)) {
        entityDetails['ModifiedYearTime'] = entityStat.modified.year.toString();
      } else {
        var hour = entityStat.modified.hour.toString();
        var minute = entityStat.modified.minute.toString();
        entityDetails['ModifiedYearTime'] = '${leftPadString(hour, 2, 2, paddingChar:0x30)}:${leftPadString(minute, 2, 2, paddingChar:0x30)}';
      }
      if (entityDetails['ModifiedDay'].length > dateTimeDayColumn) {
        dateTimeDayColumn = entityDetails['ModifiedDay'].length;
      }
      if (entityDetails['ModifiedYearTime'].length > dateTimeYearTimeColumn) {
        dateTimeYearTimeColumn = entityDetails['ModifiedYearTime'].length;
      }

      parsedEntities.add(entityDetails);
    }
  }

  // Write actual file strings
  for (Map entityDetails in parsedEntities) {
    stdout.write("${entityDetails['Type']}${entityDetails['Permissions']}. "); //Permissions //TODO: the '.' at the end can mean something. Docs don't say very well what it could be
    stdout.write('${leftPadString(entityDetails['LinkCount'].toString(), linkColumn, consoleWidthInChars)} '); //Link count
    //TODO: owner (Dart does not have a way to get this)
    //TODO: group (Dart does not have a way to get this)
    stdout.write("${leftPadString(printDataSizeFromEntity(entityDetails['Size'], dataSizeType), sizeColumn, consoleWidthInChars)} "); //Size
    stdout.write("${entityDetails['ModifiedMonth']} ${leftPadString(entityDetails['ModifiedDay'], dateTimeDayColumn, consoleWidthInChars)} ${leftPadString(entityDetails['ModifiedYearTime'], dateTimeYearTimeColumn, consoleWidthInChars)} "); //Date/Time
    stdout.writeln(entityDetails['Name']);
  }
}

// ------ Tabulated ------

//TODO: suddenly, this no longer appears to be writing in columns?
void writeTabulatedEntities(Directory dir, List<FileSystemEntity> dirEntities, num consoleWidthInChars, bool allowDotNames) {
  var wroteNewline = false;
  var columnIndex = 0;
  var columnWidths = calculateColumnWidths(dirEntities, consoleWidthInChars, allowDotNames);

  //TODO: write in column format (see notes for example)

  for (FileSystemEntity entity in dirEntities) {
    var entityName = getFileSystemEntitiyName(entity, allowDotNames);

    if (entityName.isNotEmpty) {
      wroteNewline = false;

      entityName = getDesiredEntityName(dir, entity, entityName);
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
