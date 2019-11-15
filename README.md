# depsof

`depsof` is a basic Matlab code parser and analyser that identifies dependencies of a function or class. A dependency is a user supplied code file -- i.e., not a built-in Matlab function, or a function in a Matlab toolbox directory.

## usage

`depsof( function_name, 'Display', true );` prints the dependencies of `function_name`, a character vector. References to user supplied functions on Matlab's search path are printed with a link to their source; identifiers that appear to be function references, but which do not refer to built-in functions or a function on Matlab's search path, are marked as "unresolved".

For additional options, see `help depsof`.

##  known issues

The parser is buggy; in particular, complex matrix constructions `[a; [b + c, d()]]';` may fail to parse correctly. Imports are not handled correctly in all cases, and there is only preliminary support for classdef files.
