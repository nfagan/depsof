# depsof

`depsof` is a basic (and buggy) Matlab code parser and analyser that identifies dependencies of a function or class. A dependency is a user supplied .m code file -- i.e., not a built-in Matlab function, or a function in a Matlab toolbox directory.

## usage

`depsof( function_name, 'Display', true );` prints the dependencies of `function_name`, a character vector. References to user supplied functions on Matlab's search path are printed with a link to their source; identifiers that appear to be function references, but which do not refer to built-in functions or a function on Matlab's search path, are marked as "unresolved".
