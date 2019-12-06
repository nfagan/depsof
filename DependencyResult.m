classdef DependencyResult
  properties
    %   RESOLVED -- Set of functions located on Matlab's search path.
    %
    %     Resolved is a cell array of strings containing the names of
    %     functions located in a call to `depsof`.
    %
    %     See also DependencyResult.ResolvedIn, DependencyResult.Unresolved,
    %       DependencyResult
    Resolved;
    
    %   RESOLVEDFILES -- Absolute file paths to resolved functions.
    %
    %     ResolvedFiles is a cell array of strings the same size as
    %     Resolved. Each element of ResolvedFiles contains the absolute
    %     path to the file associated with the corresponding element of
    %     Resolved.
    %
    %     See also DependencyResult.Resolved, DependencyResult.Unresolved,
    %       DependencyResult
    ResolvedFiles;
    
    %   UNRESOLVED -- Set of unresolved function references.
    %     
    %     Unresolved is a cell array of strings containing identifiers that
    %     appear to be function references, but which do not exist on
    %     Matlab's search path.
    %
    %     See also DependencyResult.Resolved, DependencyResult
    Unresolved;
    
    %   RESOLVEDIN -- Functions in which dependent functions were resolved.
    %
    %     ResolvedIn is a cell array of strings the same size as Resolved.
    %     Each element contains the name of the function in which the
    %     corresponding element of Resolved was located.
    %
    %     See also DependencyResult.Resolved, DependencyResult
    ResolvedIn;
    
    %   RESOLVEDIN -- Functions in which unresolved functions were found.
    %
    %     UnresolvedIn is a cell array of strings the same size as Unresolved.
    %     Each element contains the name of the function in which the
    %     corresponding element of Unresolved was found.
    %
    %     See also DependencyResult.Unresolved, DependencyResult
    UnresolvedIn;
    
    %   GRAPH -- Dependency graph.
    %
    %     See also DependencyResult.Resolved, DependencyResult,
    %       DependencyGraph
    Graph;
  end
  
  methods
    function obj = DependencyResult(inputs)
      
      %   DEPENDENCYRESULT -- Result of search for dependent functions.
      %
      %     See also depsof, DependencyResult.Resolved,
      %       DependencyResult.show
      
      obj.Resolved = inputs.Resolved;
      obj.ResolvedFiles = inputs.ResolvedFiles;
      obj.Unresolved = inputs.Unresolved;
      obj.ResolvedIn = inputs.ResolvedIn;
      obj.UnresolvedIn = inputs.UnresolvedIn;
      obj.Graph = inputs.Graph;
    end
    
    function varargout = plot(obj)
      
      %   PLOT -- Plot the dependency graph.
      %
      %     plot( obj ); plots the graph of dependencies created during a
      %     call to Dependencies.of.
      %
      %     See also depsof
      
      [varargout{1:nargout}] = plot( obj.Graph );
    end
    
    function show(obj)
      
      %   SHOW -- Display results.
      %
      %     show( obj ); prints a list of function references in files
      %     traversed during a call to Dependencies.of. Function / classdef
      %     files that are resolved will be printed with a link to their 
      %     source; unresolved  function references will be marked as such.
      %
      %     See also depsof, Dependencies.of
      
      resolved_in = unique( obj.ResolvedIn );
      unresolved_in = unique( obj.UnresolvedIn );
      
      visited = union( resolved_in, unresolved_in );
      has_desktop = usejava( 'desktop' );
      
      if ( isempty(visited) )
        fprintf( '\n  No functions were visited.' );
        
      else
        for i = 1:numel(visited)
          if ( has_desktop )
            fprintf( '\n  <a href="%s" style="font-weight:bold">%s</a>' ...
              , visited{i}, visited{i} );
          else
            fprintf( '\n  %s', visited{i} );
          end

          obj.display_funcs( visited{i} ...
            , obj.ResolvedIn, obj.Resolved, '', has_desktop );
          obj.display_funcs( visited{i} ...
            , obj.UnresolvedIn, obj.Unresolved, 'Unresolved', has_desktop );

          fprintf( '\n' );
        end
      end
      
      fprintf( '\n' );
    end
  end
  
  methods (Access = private)
    function display_funcs(obj, visited, in_files, funcs, kind, has_desktop)
      is_target = strcmp( in_files, visited );
      target_funcs = funcs(is_target);

      for i = 1:numel(target_funcs)
        if ( ~isempty(kind) )
          fprintf( '\n    %s (%s)', target_funcs{i}, kind );
        else
          if ( has_desktop )
            fprintf( '\n    <a href="%s">%s</a>', target_funcs{i}, target_funcs{i} );
          else
            fprintf( '\n    %s', target_funcs{i} );
          end
        end
      end
    end
  end
end