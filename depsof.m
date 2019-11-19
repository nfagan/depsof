function deps = depsof(varargin)

%   DEPSOF -- List dependencies of function.
%
%     deps = depsof( function_name ); returns a struct `deps` containing
%     information about the external dependencies of the m-file function
%     `function_name`. 
%
%     An external dependency is a user-created m-file; i.e., not a built-in
%     function (like sum) or an m-file residing in a Matlab toolbox (like
%     nanmean).
%
%     `deps` has fields 'Resolved', 'ResolvedFiles', 'Unresolved', 
%     'ResolvedIn', and 'UnresolvedIn'. 'Resolved' is a list of external 
%     function or class names referenced in `function_name` that exist on 
%     Matlab's search path, and 'ResolvedFiles' contains the absolute path
%     to each function or class file. 'Unresolved' is a list of identifiers 
%     in `function_name` that appear to be function references, but which 
%     do not exist on Matlab's search path. 'ResolvedIn' and 'UnresolvedIn' 
%     give the name of the function in which the corresponding identifiers 
%     appear.
%
%     deps = DEPSOF( function_names ); where `function_names` is a cell
%     array of strings, searches each function.
%
%     deps = DEPSOF( ..., 'Recursive', tf ); indicates whether to 
%     recursively search for external dependencies of each resolved 
%     function. Default is false.
%
%     deps = DEPSOF( ..., 'SkipToolboxes', tf ); indicates whether to avoid 
%     traversing m-files that exist in Matlab's toolbox directory. Default 
%     is true.
%
%     deps = DEPSOF( ..., 'Verbose', tf ); indicates whether to print 
%     information about the dependency-tracking process. Default is false.
%
%     deps = DEPSOF( ..., 'Display', tf ); indicates whether to
%     pretty-print the resolved and unresolved dependencies of each visited
%     function. Default is false.
%
%     Notes & limitations //
%
%     DEPSOF may mark class methods (and other functions that dispatch
%     based on their arguments) as unresolved.
%
%     DEPSOF assumes the function file is well-formed. A parse error may
%     result if the file contains non-ascii characters, or invalid Matlab
%     syntax or symbols.
%
%     DEPSOF has incomplete support for classdef files.
%
%     See also mfilename, which

deps = Dependencies.of( varargin{:} );

end