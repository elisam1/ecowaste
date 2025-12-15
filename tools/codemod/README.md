This codemod scans Dart files and replaces `withOpacity(x)` calls with `withValues(alpha: x)` using AST inspection.

Usage:
  cd tools/codemod
  dart pub get
  dart run replace_withopacity_codemod.dart

Backups: each modified file gets a `.bak` backup alongside it.
