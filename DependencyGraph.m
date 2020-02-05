classdef DependencyGraph < handle
  properties (Access = public)
    Graph;
    Vertices;
    VerticesToNames;
    NamesToVertices;
  end
  
  methods
    function obj = DependencyGraph()
      obj.Graph = digraph();
      obj.Vertices = {};
      obj.VerticesToNames = containers.Map( 'keytype', 'double', 'valuetype', 'char' );
      obj.NamesToVertices = containers.Map( 'keytype', 'char', 'valuetype', 'double' );
    end
    
    function tf = isempty(obj)
      tf = isempty( obj.Vertices );
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
      if ( ~isKey(obj.NamesToVertices, node_id) )
        vertex_ind = numel( obj.Vertices ) + 1;
        obj.NamesToVertices(node_id) = vertex_ind;
        obj.VerticesToNames(vertex_ind) = node_id;
        obj.Vertices{end+1} = [];
      end
    end
    
    function require_edge(obj, from, to)
      if ( findedge(obj.Graph, from, to) == 0 )
        obj.Graph = addedge( obj.Graph, from, to );
      end
      
      from_ind = obj.NamesToVertices(from);
      to_ind = obj.NamesToVertices(to);
      
      if ( ~ismember(to_ind, obj.Vertices{from_ind}) )
        obj.Vertices{from_ind}(end+1) = to_ind;
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
    
    function df_traverse(obj, from, visitor, depth, visited)
      if ( ~isKey(obj.NamesToVertices, from) )
        return
      end
      if ( nargin < 4 )
        depth = 0;
      end
      if ( nargin < 5 )
        visited = containers.Map( 'keytype', 'double', 'valuetype', 'any' );
      end
      
      from_ind = obj.NamesToVertices(from);
      edges = obj.Vertices{from_ind};
      
      visitor( from, depth );
      
      for i = 1:numel(edges)        
        if ( ~isKey(visited, from_ind) )
          visited_edges = [];
        else
          visited_edges = visited(from_ind);
        end
        
        if ( ~ismember(edges(i), visited_edges) )
          visited_edges(end+1) = edges(i);
          visited(from_ind) = visited_edges;
          
          obj.df_traverse( obj.VerticesToNames(edges(i)), visitor, depth + 1, visited );
        end
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