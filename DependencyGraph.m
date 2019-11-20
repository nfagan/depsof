classdef DependencyGraph
  properties (GetAccess = public, SetAccess = private)
    Graph;
  end
  
  methods
    function obj = DependencyGraph(dgraph)
      if ( nargin == 0 || isempty(dgraph) )
        dgraph = digraph();
      end
      
      obj.Graph = dgraph;     
    end

    function s = source_indices(obj)
      [~, s] = ismember( sources(obj), nodes(obj) );
    end

    function s = sink_indices(obj)
      [~, s] = ismember( sinks(obj), nodes(obj) );
    end
    
    function s = sources(obj)
      e = edges( obj );
      s = e(:, 1);
    end
    
    function s = sinks(obj)
      e = edges( obj );
      s = e(:, 2);
    end
    
    function names = nodes(obj)
      if ( isempty(obj.Graph.Nodes) )
        names = {};
      else
        names = obj.Graph.Nodes.Name;
      end
    end
    
    function e = edges(obj)
      if ( isempty(obj.Graph.Edges) )
        e = cell( 0, 2 );
      else
        e = obj.Graph.Edges.EndNodes;
      end
    end
    
    function h = plot(obj)
      h = plot( obj.Graph );
      labelnode( h, 1:numnodes(obj.Graph), nodes(obj) );
    end
    
    function obj = set.Graph(obj, to)
      validateattributes( to, {'digraph'}, {'scalar'}, mfilename, 'digraph' );
      obj.Graph = to;
    end
  end
end