classdef DependencyGraph < handle
  properties (Access = private)
    Graph;
  end
  
  methods
    function obj = DependencyGraph()
      obj.Graph = digraph();
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
    
    function tf = is_node(obj, node_id)      
      try
        ind = findnode( obj.Graph, node_id );
        tf = ind ~= 0;
      catch
        tf = false;
      end
    end
    
    function require_node(obj, node_id)
      if ( ~is_node(obj, node_id) )
        obj.Graph = addnode( obj.Graph, node_id );
      end
    end
    
    function require_edge(obj, from, to)
      if ( findedge(obj.Graph, from, to) == 0 )
        obj.Graph = addedge( obj.Graph, from, to );
      end
    end
    
    function connect_nodes(obj, from, to, allow_self_loops)
      if ( nargin < 4 )
        allow_self_loops = false;
      end
      
      obj.require_node( to );
      
      if ( ~isempty(from) && (allow_self_loops || ~strcmp(to, from)) )
        obj.require_node( from );
        obj.require_edge( from, to );
      end
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
  end
end