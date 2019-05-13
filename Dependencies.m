classdef Dependencies < handle
  properties (Access = public)
    VisitedFiles;
    VisitedFunctions;
    Tokens;
    NumTokens;
    TokenTypes;
    ScopeDepth;
    EnclosingFunction;
    IdentifierIndex;
    FunctionDefinitions;
    InternedStringMap;
    InternedStrings;
    Imports;
    ToolboxDirectory;
    ParseDepth;
    ResolvedDependentFunctions;
    UnresolvedDependentFunctions;
    ResolvedIn;
    UnresolvedIn;
    Verbose;
    Recursive;
    ImplicitFunctionEnd;
    ErrorHandler;
    FileContents;
    SkipToolboxFunctions;
    Warn;
  end
  
  methods (Access = private)
    function obj = Dependencies()
      obj.VisitedFiles = containers.Map();
      obj.VisitedFunctions = containers.Map();
      obj.TokenTypes = token_types();
      obj.ScopeDepth = 0;
      obj.EnclosingFunction = 0;
      obj.IdentifierIndex = 0;
      obj.Tokens = [];
      obj.NumTokens = 0;
      obj.FunctionDefinitions = {};
      obj.InternedStringMap = containers.Map();
      obj.InternedStrings = {};
      obj.Imports = obj.make_imports_container();
      obj.ToolboxDirectory = toolboxdir( '' );
      obj.ParseDepth = 0;
      obj.ResolvedDependentFunctions = {};
      obj.UnresolvedDependentFunctions = {};
      obj.ResolvedIn = {};
      obj.UnresolvedIn = {};
      obj.Verbose = false;
      obj.Recursive = false;
      obj.ImplicitFunctionEnd = false;
      obj.ErrorHandler = 'warn';
      obj.FileContents = [];
      obj.SkipToolboxFunctions = true;
      obj.Warn = true;
    end
    
    function tf = is_mex_file(obj, file_path)
      tf = ~isempty( strfind(file_path, '.mex') );
    end
    
    function tf = is_java_method(obj, file_path)
      tf = ~isempty( strfind(file_path, 'Java method') );
    end
    
    function tf = is_toolbox_function(obj, file_path)
      tf = strncmp( file_path, obj.ToolboxDirectory, numel(obj.ToolboxDirectory) );
    end
    
    function tf = is_builtin(obj, mfile, file_path)      
      tf = strncmp(file_path, 'built-in ', numel('built-in ')) || ...
        ~isempty(strfind(file_path, 'built-in '));
    end
    
    function tf = is_p_file(obj, file_path)
      tf = numel( file_path ) >= 2 && strcmp( file_path(end-1:end), '.p' );
    end
    
    function tf = should_skip_function(obj, mfile, file_path)
      tf = obj.is_builtin( mfile, file_path ) || ...
      (obj.is_toolbox_function(file_path) && obj.SkipToolboxFunctions) || ...
        obj.is_mex_file(file_path) || ...
        obj.is_java_method(file_path) || ...
        obj.is_p_file(file_path) || ...
        isKey( obj.VisitedFiles, file_path );
    end
    
    function imports = make_imports_container(obj)
      imports = containers.Map( 'keytype', 'double', 'valuetype', 'any' );
    end
    
    function begin_file(obj, tokens, contents)
      
      if ( ~isempty(tokens) && any(tokens(:, 1) == obj.TokenTypes.classdef) )
        error( 'Cannot track dependencies of class definition.' );
      end
      
      obj.Tokens = tokens;
      obj.NumTokens = size( tokens, 1 );
      obj.EnclosingFunction = 0;
      obj.ScopeDepth = 0;
      obj.IdentifierIndex = 0;
      obj.FunctionDefinitions = {};
      obj.ImplicitFunctionEnd = obj.is_implicitly_terminated_function( tokens );
      obj.FileContents = contents;
      obj.Imports = obj.make_imports_container();
    end
    
    function parse_files(obj, mfiles)
      for i = 1:numel(mfiles)
        obj.parse_file( mfiles{i}, true, '' );
      end
    end
    
    function parse_file(obj, mfile, first_entry, parent_func)      
      obj.VisitedFunctions(mfile) = 1;
      
      % Early-out for common built-ins like sum, error, etc. Avoids `which`.
      if ( is_known_builtin(mfile) )
        return
      end
      
      file_path = which( mfile );
      
      if ( isempty(file_path) )
        if ( first_entry )
          if ( obj.Warn )
            warning( 'Function "%s" not found.', mfile );
          end
        else          
          obj.UnresolvedDependentFunctions{end+1} = mfile;
          obj.UnresolvedIn{end+1} = parent_func;
        end
        return
      end
      
      if ( obj.should_skip_function(mfile, file_path) )
        return
      elseif ( ~first_entry )
        obj.ResolvedDependentFunctions{end+1} = mfile;
        obj.ResolvedIn{end+1} = parent_func;
      end
      
      obj.VisitedFiles(file_path) = 1;
      
      if ( ~obj.Recursive && obj.ParseDepth > 0 )
        return
      end
      
      if ( obj.Verbose )
        fprintf( '\n Parsing "%s" ...', mfile );
      end

      file_contents = fileread( file_path );

      try
        tokens = scan( file_contents );
      catch err
        if ( obj.Warn )
          fprintf( '\n' );
          warning( 'Failed to tokenize file "%s": %s', mfile, err.message );
        end
        tokens = [];
      end
      
      try
        obj.begin_file( tokens, file_contents );
        
        function_names = obj.parse();
      catch err        
        if ( obj.Warn )
          fprintf( '\n' );
          warning( 'Failed to parse "%s": %s', mfile, err.message );
        end
        function_names = {};
      end
      
      for i = 1:numel(function_names)
        func = function_names{i};
        
        if ( ~isKey(obj.VisitedFunctions, func) )
          obj.ParseDepth = obj.ParseDepth + 1;
          
          try
            obj.parse_file( func, false, mfile );
          catch err
            fprintf( '\n' );
            warning( 'Failed to parse "%s": %s', func, err.message );
          end
          
          obj.ParseDepth = obj.ParseDepth - 1;
        end
      end
    end
    
    function function_names = parse(obj)
      ids = {};
      i = 1;

      while ( i <= obj.NumTokens )
        current_type = obj.peek_type( i );

        if ( current_type == obj.TokenTypes.function )
          [ids, i] = obj.function_definition( i, ids );
          
        elseif ( current_type == obj.TokenTypes.classdef )
          error( 'Cannot track dependencies of class definition.' );
          [ids, i] = obj.class_definition( i, ids );

        elseif ( current_type == obj.TokenTypes.new_line )
          i = i + 1; 
        
        else
          [ids, i] = obj.statement( i, ids );
          
        end
      end
      
      ids = obj.finalize_parse( ids );
      
      if ( ~isempty(ids) )
        function_names = obj.find_functions( ids );
      else
        function_names = {};
      end
    end
    
    function intern_function_strings(obj)
      for i = 1:numel(obj.FunctionDefinitions)
        % Last element is enclosing function index, not a string.
        for j = 1:numel(obj.FunctionDefinitions{i})-1
          obj.FunctionDefinitions{i}{j} = ...
            obj.intern_strings( obj.FileContents, obj.FunctionDefinitions{i}{j} );
        end
      end
    end
    
    function intern_import_strings(obj)
      import_ids = keys( obj.Imports );
      
      for i = 1:numel(import_ids)
        imports = obj.Imports(import_ids{i});
        obj.Imports(import_ids{i}) = obj.intern_strings( obj.FileContents, imports );
      end
    end
    
    function ids = finalize_parse(obj, ids)
      ids = horzcat( ids{:} );      
      ids = obj.intern_strings( obj.FileContents, ids );
      
      obj.intern_import_strings();
      obj.intern_function_strings();
    end
    
    function tf = is_visible_function_name(obj, funcs, var_id)
      for i = 1:numel(funcs)
        name = obj.FunctionDefinitions{funcs(i)}{1};

        if ( ~isempty(name) && name == var_id )
          tf = true;
          return
        end
      end
      
      tf = false;
    end
    
    function is_start = is_identifier_start(obj, ids)
      starts = diff( ids(4, :) );
      is_start = [ true, starts > 0 ];
    end
    
    function is_stop = is_identifier_stop(obj, ids)
      stops = diff( ids(4, :) );
      is_stop = [ stops > 0, true ];
    end
    
    function i = id_start_from_stop(obj, ids, id_idx)
      i = id_idx + 1;
      id_id = ids(4, id_idx);
      
      while ( i > 1 && ids(4, i-1) == id_id )
        i = i - 1;
      end
    end
    
    function id_idx = id_stop_from_start(obj, ids, id_idx)
      n = size( ids, 2 );
      id_id = ids(4, id_idx);
      
      while ( id_idx < n && ids(4, id_idx+1) == id_id )
        id_idx = id_idx + 1;
      end
    end
    
    function tf = is_variable(obj, ids)
      tf = ids(1, :) < 0;
    end
    
    function str = make_function_name(obj, ids, id_idx, max_count)
      
      n_ids = size( ids, 2 );
      id_id = ids(4, id_idx);
      str = '';
      count = 0;
      
      while ( id_idx <= n_ids && ids(4, id_idx) == id_id && count < max_count )         
        base_str = obj.InternedStrings{abs(ids(1, id_idx))};

        if ( isempty(str) )
          str = base_str;
        else
          str = sprintf( '%s.%s', str, base_str );
        end

        id_idx = id_idx + 1;
        count = count + 1;
      end
    end
    
    function sz = id_size(obj, ids, id_idx)
      
      i = id_idx;
      id_id = ids(id_idx, 4);
      n = size( ids, 2 );
      sz = 0;
      
      while ( i <= n && ids(i, 4) == id_id )
        i = i + 1;
        sz = sz + 1;
      end
    end
    
    function tf = is_id_matching_function(obj, ids, func_idx)
      tf = ids(3, :) == func_idx;
    end
    
    function [tf, name] = is_complete_import(obj, ids, imports ...
        , var_id, id_idx, complete_import_stops)
      
      tf = false;
      name = '';
      
      for i = 1:numel(complete_import_stops)
        import_stop_idx = complete_import_stops(i);

        if ( imports(1, import_stop_idx) == var_id )
          import_start_idx = obj.id_start_from_stop( imports, import_stop_idx );
          n_import_ids = import_stop_idx - import_start_idx + 1;
          
          var_stop_idx = obj.id_stop_from_start( ids, id_idx );
          n_var_ids = var_stop_idx - id_idx + 1;
          
          import_name = obj.make_function_name( imports, import_start_idx, n_import_ids );
          var_name = obj.make_function_name( ids, id_idx, n_var_ids-1 );
          
          if ( ~isempty(var_name) )
            name = sprintf( '%s.%s', import_name, var_name );
          else
            name = import_name;
          end
          
          tf = true;
          return
        end
      end  
    end
    
    function [tf, name] = is_wildcard_import(obj, ids, id_idx, wildcard_import_names)
      
      tf = false;
      name = '';
      
      var_name = obj.make_function_name( ids, id_idx, inf );
      assert( ~isempty(var_name), 'Expected non-empty variable name.' );
      
      for i = 1:numel(wildcard_import_names)
        joined_name = sprintf( '%s.%s', wildcard_import_names{i}, var_name );
        
        if ( ~isempty(which(joined_name)) )
          tf = true;
          name = joined_name;
          return
        end
      end
    end
    
    function names = make_wildcard_import_names(obj, imports, start_idx)
      names = cell( 1, numel(start_idx) );
      for i = 1:numel(start_idx)
        names{i} = obj.make_function_name( imports, start_idx(i), inf );
      end
    end
    
    function insert_names_for_function(obj, ids, function_names, function_def_index ...
        , is_variable, is_identifier_start)
      
      % Matches this function.
      is_func = obj.is_id_matching_function( ids, function_def_index );
      identifiers_this_func = find( is_func & ~is_variable & is_identifier_start );
      
      imports = [];
      has_imports = isKey( obj.Imports, function_def_index );
      
      % Check imports
      if ( has_imports )
        imports = obj.Imports(function_def_index);

        is_import_start = obj.is_identifier_start( imports );
        is_import_stop = obj.is_identifier_stop( imports );
        is_import_func = obj.is_id_matching_function( imports, function_def_index );
        
        is_complete_import = ~imports(6, :);
        complete_import_stops = find( is_import_func & is_import_stop & is_complete_import );
        wildcard_import_starts = find( is_import_func & is_import_start & ~is_complete_import );
        
        wildcard_import_names = obj.make_wildcard_import_names( imports, wildcard_import_starts );
      end

      for j = 1:numel(identifiers_this_func)
        id_idx = identifiers_this_func(j);

        var_id = ids(1, id_idx);
        scope = ids(2, id_idx);
        current_func_index = ids(3, id_idx);

        is_maybe_variable_ref = ids(1, :) == -var_id & is_func & is_identifier_start;

        if ( nnz(is_maybe_variable_ref) > 0 )
          variable_idxs = ids(5, is_maybe_variable_ref);
          function_idx = ids(5, id_idx);

          if ( function_idx > min(variable_idxs) )
            % Function occurs after first variable declaration, is a
            % variable reference.
            continue;
          end
        end

        % Not a variable in current scope -- check if input argument.
        if ( function_def_index > 0 )
          inputs = obj.FunctionDefinitions{function_def_index}{2};

          if ( any(inputs == var_id) )
            % Is an input.
            continue;
          end
        end
        
        if ( scope > 0 )
          % If we're in an inner scope, check to see whether the
          % identifier is an input of the parent scope.
          is_maybe_func = true;
          scope_idx = scope;
          func_idx = current_func_index;

          while ( scope_idx >= 0 )
            enclosing_func = obj.FunctionDefinitions{func_idx}{4};
            enclosing_inputs = obj.FunctionDefinitions{func_idx}{2};

            if ( isempty(enclosing_func) )
              enclosing_func = 1;
            end

            is_enclosing = ids(3, :) == enclosing_func;
            is_maybe_var_ref = ids(1, :) == -var_id;

            if ( any(is_enclosing & is_maybe_var_ref) )
              is_maybe_func = false;
              break;
            elseif ( any(enclosing_inputs == var_id) )
              is_maybe_func = false;
              break;
            end

            scope_idx = scope_idx - 1;
            func_idx = enclosing_func;
          end

          if ( ~is_maybe_func )
            continue;
          end
        end

        % Check to see whether this is a reference to a local
        % function.
        %
        %   Function is visible if 
        %     1) in scope < current scope (i.e., in any outer scope).
        %     2) is a sibling of another function.
        %     3) is a child of the current function.

        % 1) Ancestor
        is_less_scope = ids(2, :) < scope;
        funcs_less_scope = unique( ids(3, is_less_scope) );

        if ( obj.is_visible_function_name(funcs_less_scope, var_id) )
          continue;
        end

        % 2) Sibling
        if ( function_def_index > 0 )
          current_enclosing = obj.FunctionDefinitions{current_func_index}{4};

          sibling_functions = find( cellfun(@(x) isequal(current_enclosing, x{4}) ...
            , obj.FunctionDefinitions) );

          if ( obj.is_visible_function_name(sibling_functions, var_id) )  %#ok
            continue;
          end
        end

        % 3) Child
        child_functions = find( cellfun(@(x) isequal(current_func_index, x{4}) ...
          , obj.FunctionDefinitions) );

        if ( obj.is_visible_function_name(child_functions, var_id) )  %#ok
          continue;
        end
        
        %   Check to see whether this name could refer to an imported
        %   function.
        is_complete_import = false; 
        is_wildcard_import = false;
        
        if ( has_imports )
          [is_complete_import, complete_import_name] = ...
            obj.is_complete_import( ids, imports, var_id, id_idx, complete_import_stops );
          
          if ( ~is_complete_import )
            [is_wildcard_import, wildcard_import_name] = ...
              obj.is_wildcard_import( ids, id_idx, wildcard_import_names );
          end
        end
        
        if ( is_complete_import )
          %   Maybe reference to fully-qualified import.
          func_name = complete_import_name;
        elseif ( is_wildcard_import )
          %   Definitely reference to import.
          func_name = wildcard_import_name;
        else
          %   Maybe function.
          func_name = obj.make_function_name( ids, id_idx, inf );
        end

        if ( ~isKey(function_names, func_name) && ~isKey(obj.VisitedFunctions, func_name) )
          function_names(func_name) = 1;
        end
      end
    end
    
    function function_names = find_functions(obj, ids)
      
      n_funcs = numel( obj.FunctionDefinitions );
      
      is_variable = obj.is_variable( ids );
      is_identifier_start = obj.is_identifier_start( ids );
      
      function_names = containers.Map();
      
%       if ( n_funcs == 0 )
%         loop_sequence = 0;
%       else
%         loop_sequence = 1:n_funcs;
%       end
      loop_sequence = 0:n_funcs;
      
      for i = loop_sequence
        obj.insert_names_for_function( ids, function_names, i, ...
          is_variable, is_identifier_start );
      end
      
      function_names = keys( function_names );
    end
    
    function ids = intern_strings(obj, str, ids)      
      for i = 1:size(ids, 2)
        idx = abs( ids(1, i) );
        sgn = sign( ids(1, i) );
        
        lexeme = str(obj.Tokens(idx, 2):obj.Tokens(idx, 3));
        
        if ( ~isKey(obj.InternedStringMap, lexeme) )
          obj.InternedStringMap(lexeme) = numel( obj.InternedStrings ) + 1;
          obj.InternedStrings{end+1} = lexeme;
        end
        
        ids(1, i) = sgn * obj.InternedStringMap(lexeme);
      end
    end
    
    function [ids, i] = grouping_expression(obj, begin, ids)
      [ids, i] = obj.expression( begin + 1, ids );
      i = obj.consume_tokens( obj.TokenTypes.right_parens, i );
    end

    function [tmp, includes_end] = prune_ends(obj, tmp)

      keep_tmp = true( size(tmp) );
      includes_end = false;

      for i = 1:numel(tmp)
        to_keep = true( 1, size(tmp{i}, 2) );

        for j = 1:size(tmp{i}, 2)
          if ( tmp{i}(1, j) == 0 )
            includes_end = true;
            to_keep(j) = false;
          end
        end

        tmp{i} = tmp{i}(:, to_keep);
        keep_tmp(i) = any( to_keep );
      end

      tmp = tmp(keep_tmp);
    end
    
    function [ids, i, includes_end] = brace_or_parens_reference_expression(obj, begin, ids, terminator)
      i = begin + 1;
      n = obj.NumTokens;
      includes_end = false;

      while ( i <= n && obj.peek_type(i) ~= terminator )        
        [tmp, i] = obj.expression( i-1, {} );

        if ( ~isempty(tmp) )    
          [tmp, tmp_includes_end] = obj.prune_ends( tmp );

          if ( ~isempty(tmp) )
            ids(end+1:end+numel(tmp)) = tmp;
          end
          
          if ( tmp_includes_end )
            includes_end = true;
          end
        end

        if ( obj.peek_type(i) == obj.TokenTypes.comma )
          i = i + 1;
        end
      end

      i = obj.consume_tokens( terminator, i );
    end

    function [ids, i, includes_end] = parens_reference_expression(obj, begin, ids)
      [ids, i, includes_end] = ...
        obj.brace_or_parens_reference_expression( begin, ids, obj.TokenTypes.right_parens );
    end
    
    function [ids, i, includes_end] = brace_reference_expression(obj, begin, ids)
      [ids, i, includes_end] = ...
        obj.brace_or_parens_reference_expression( begin, ids, obj.TokenTypes.right_brace );
    end
    
    function [ids, i] = command_expression(obj, begin, ids)
      i = begin + 1;
      
      assert( obj.peek_type(i) == obj.TokenTypes.identifier )
      ids{end+1} = obj.make_id( i );
      
      while ( i <= obj.NumTokens )
        next_type = obj.peek_type( i );
        
        if ( next_type == obj.TokenTypes.identifier || ...
            next_type == obj.TokenTypes.string_literal )
          i = i + 1;
        else
          break;
        end
      end
    end
    
    function tf = is_preceding_reference(obj, i)
      prev_type = obj.peek_type( i );
      tf = prev_type == obj.TokenTypes.right_parens || ...
        prev_type == obj.TokenTypes.right_bracket || ...
        prev_type == obj.TokenTypes.right_brace;
    end
    
    function [ids, i] = identifier_expression(obj, begin, ids, aggregate)
      if ( nargin < 4 )
        aggregate = true;
      end
      
      i = begin + 1;
      n = obj.NumTokens;
      tmp = [];
      is_maybe_function = true;
      prev = char( 0 );
      first_identifier = true;
      
      while ( i <= n )
        if ( obj.peek_type(i) == obj.TokenTypes.identifier )          
          if ( ~aggregate && ~first_identifier && obj.is_preceding_reference(i-1) )
            break;
          end
          
          tmp(end+1) = i;
          i = i + 1;
          prev = char( 0 );
          first_identifier = false;
        end
        
        if ( obj.peek_type(i) == obj.TokenTypes.period )
          if ( prev ~= 0 && prev ~= '.' )
            is_maybe_function = false;
          end
          
          prev = '.';
          i = i + 1;
          
          continue;
        end
        
        if ( obj.peek_type(i) == obj.TokenTypes.left_parens )
          [ids, i, includes_end] = obj.parens_reference_expression( i, ids );

          if ( includes_end || prev == '.' )
            % This is a variable reference expression -- e.g., a(1, end) rather
            % than a function call.
            is_maybe_function = false;
          end
          prev = '(';
          
          continue;
        end
        
        if ( obj.peek_type(i) == obj.TokenTypes.left_brace )
          % Can't be function with brace reference.
          [ids, i, ~] = obj.brace_reference_expression( i, ids );
          is_maybe_function = false;
          prev = '}';
          continue;
        end
        
        break;
      end
      
      if ( obj.peek_type(i) == obj.TokenTypes.equal )
        % This is a variable assignment expression -- e.g. a = 10, rather than a
        % function call
        [ids, i] = obj.expression( i, ids );
        is_maybe_function = false;
      end
      
      if ( obj.peek_type(i) == obj.TokenTypes.postfix_operator )
        % Consume postfix.
        i = i + 1;
      end
      
      if ( ~is_maybe_function )
        tmp(1) = -tmp(1);
      end

      ids{end+1} = obj.make_id( tmp );
    end
    
    function [ids, i] = bracket_or_brace_expression(obj, begin, ids, terminator)      
      i = begin + 1;
      
      while ( i <= obj.NumTokens && obj.peek_type(i) ~= terminator )        
        if ( obj.peek_type(i) == obj.TokenTypes.identifier )
          [ids, i] = obj.identifier_expression( i-1, ids, false );
        else
          [ids, i] = obj.expression( i-1, ids, false );
        end
        
        if ( obj.is_delimiter(obj.peek_type(i)) )
          i = i + 1;
        end
      end
      
      i = obj.consume_tokens( terminator, i );
    end
    
    function [ids, i] = bracket_expression(obj, begin, ids)
      [ids, i] = obj.bracket_or_brace_expression( begin, ids, obj.TokenTypes.right_bracket );
    end
    
    function [ids, i] = brace_expression(obj, begin, ids)
      [ids, i] = obj.bracket_or_brace_expression( begin, ids, obj.TokenTypes.right_brace );
    end
    
    function tf = is_unary_operable(obj, i)
      tf = obj.peek_type( i ) == obj.TokenTypes.not;
    end
    
    function tf = is_delimiter(obj, t)
      tf = t == obj.TokenTypes.comma || ...
           t == obj.TokenTypes.semicolon || ...
           t == obj.TokenTypes.new_line;
    end
    
    function [ids, i] = function_handle_expression(obj, begin, ids)
      is_ident = obj.peek_type( begin+1 ) == obj.TokenTypes.identifier;
      
      if ( is_ident )
        [ids, i] = obj.expression( begin, ids );
      else               
        [ids, i] = obj.anonymous_function_definition( begin, ids );
      end
    end

    function [ids, i] = expression(obj, begin, ids, make_null_ids)
      if ( nargin < 4 )
        make_null_ids = true;
      end
      
      i = begin + 1;
      next_type = obj.peek_type( i );

      if ( next_type == obj.TokenTypes.left_parens )
        [ids, i] = obj.grouping_expression( begin, ids );
        
      elseif ( next_type == obj.TokenTypes.period )
        error( 'Period in expression.' );

      elseif ( next_type == obj.TokenTypes.identifier )
        [ids, i] = obj.identifier_expression( begin, ids );

      elseif ( next_type == obj.TokenTypes.number_literal || ...
          next_type == obj.TokenTypes.string_literal )
        i = i + 1;
        
      elseif ( obj.is_unary_operable(i) )
        [ids, i] = obj.expression( i, ids );

      elseif ( next_type == obj.TokenTypes.end || ...
          next_type == obj.TokenTypes.colon )
        i = i + 1;
        if ( make_null_ids )
          ids{end+1} = obj.make_id( 0 );
        end

      elseif ( next_type == obj.TokenTypes.at )
        [ids, i] = obj.function_handle_expression( i, ids );
        
      elseif ( next_type == obj.TokenTypes.left_bracket )
        [ids, i] = obj.bracket_expression( i, ids );
        
      elseif ( next_type == obj.TokenTypes.left_brace )
        [ids, i] = obj.brace_expression( i, ids );
        
      elseif ( next_type == obj.TokenTypes.postfix_operator )
        i = i + 1;

      elseif ( next_type == obj.TokenTypes.comma || ...
          next_type == obj.TokenTypes.right_parens || ...
          next_type == obj.TokenTypes.right_brace || ...
          next_type == obj.TokenTypes.semicolon || ...
          next_type == obj.TokenTypes.new_line )
        return
      end
      
      while ( obj.peek_type(i) == obj.TokenTypes.colon )
        [ids, i] = obj.expression( i, ids );
      end
        
      if ( obj.peek_type(i) == obj.TokenTypes.binary_operator )
        [rhs, i] = obj.expression( i, {} );
        ids = [ids, rhs];
      end

    end
    
    function [ids, i] = if_statement(obj, begin, ids)
      % Condition
      [ids, i] = obj.expression( begin, ids );
      [ids, i] = obj.statement( i, ids );
      
      while ( obj.peek_type(i) == obj.TokenTypes.elseif )
        [ids, i] = obj.expression( i, ids );
        [ids, i] = obj.statement( i, ids );
      end
      
      if ( obj.peek_type(i) == obj.TokenTypes.else )
        [ids, i] = obj.statement( i+1, ids );
      end

      i = obj.consume_tokens( obj.TokenTypes.end, i );
    end
    
    function [ids, i] = for_statement(obj, begin, ids)
      % Initializer
      [ids, i] = obj.expression( begin, ids );
      [ids, i] = obj.statement( i, ids );
      
      i = obj.consume_tokens( obj.TokenTypes.end, i );
    end
    
    function [ids, i] = persistent_or_global_statement(obj, begin, ids)
      i = begin + 1;
      orig_size = numel( ids );
      
      while ( i <= obj.NumTokens && obj.peek_type(i) == obj.TokenTypes.identifier )
        id = obj.make_id( i );
        id(1) = -id(1); % Definitely variable.
        ids{end+1} = id;
        i = i + 1;
      end
      
      new_size = numel( ids );
      
      if ( new_size == orig_size )
        error( 'Expected identifier after persistent or global declaration.' );
      else
        if ( ~obj.is_delimiter(obj.peek_type(i)) )
          error( 'Expect expression delimiter after persistent or global declaration.' );
        end
        
        i = i + 1;
      end
    end
    
    function [ids, i] = while_statement(obj, begin, ids)
      % Initializer
      [ids, i] = obj.expression( begin, ids );
      [ids, i] = obj.statement( i, ids );
      
      i = obj.consume_tokens( obj.TokenTypes.end, i );
    end
    
    function [ids, i] = try_statement(obj, begin, ids)
      [ids, i] = obj.statement( begin+1, ids );
      
      if ( obj.peek_type(i) == obj.TokenTypes.catch )
        n_orig = numel( ids );
        [ids, i] = obj.expression( i, ids );
        n_now = numel( ids );
        
        if ( n_now - n_orig == 1 )
          % Mark identifier of caught exception as variable.
          ids{end}(1) = -abs( ids{end}(1) );
        end
        
        [ids, i] = obj.statement( i+1, ids );
      end
            
      i = obj.consume_tokens( obj.TokenTypes.end, i );
    end
    
    function [ids, i] = switch_statement(obj, begin, ids)
      [ids, i] = obj.expression( begin, ids );
      
      while ( obj.peek_type(i) ~= obj.TokenTypes.case && ...
          obj.peek_type(i) ~= obj.TokenTypes.end )
        i = i + 1;
      end
      
      while ( obj.peek_type(i) == obj.TokenTypes.case )
        [ids, i] = obj.expression( i, ids );
        [ids, i] = obj.statement( i, ids );
      end
      
      if ( obj.peek_type(i) == obj.TokenTypes.otherwise )
        [ids, i] = obj.statement( i+1, ids );
      end
      
      i = obj.consume_tokens( obj.TokenTypes.end, i );
    end
    
    function [ids, i] = spmd_statement(obj, begin, ids)
      i = begin + 1;
      
      if ( obj.peek_type(i) == obj.TokenTypes.left_parens )
        [ids, i] = obj.expression( i-1, ids );
      end
      
      [ids, i] = obj.statement( i, ids );
      i = obj.consume_tokens( obj.TokenTypes.end, i );
    end
    
    function [ids, i] = import_statement(obj, begin, ids)      
      i = begin + 1;
      parse_err_msg = 'Expect .* or statement delimiter after imported identifier.';
      enclosing_func = obj.enclosing_function();
      
      while ( i <= obj.NumTokens && ~obj.is_delimiter(obj.peek_type(i)) )        
        if ( obj.peek_type(i) ~= obj.TokenTypes.identifier )
          error( 'Expect identifiers after import statement.' );
        end
        
        is_wildcard = 0;
        [idents, i] = obj.identifier_expression( i-1, {} );
      
        if ( obj.peek_type(i) == obj.TokenTypes.binary_operator )
          if ( ~strcmp(obj.peek_lexeme(i), '.*') )
            error( parse_err_msg );
          end
          
          i = i + 1;
          is_wildcard = 1;
        end
        
        if ( numel(idents) ~= 1 )
          error( 'Expected single identifier expression after import statement.' );
        end
        
        if ( ~isKey(obj.Imports, enclosing_func) )
          imports = [];
        else
          imports = obj.Imports(enclosing_func);
        end
        
        idents = idents{1};
        
        idents(end+1, :) = is_wildcard;
        imports = [ imports, idents ];
        
        obj.Imports(enclosing_func) = imports;
      end
      
      if ( ~obj.is_delimiter(obj.peek_type(i)) )
        error( parse_err_msg );
      end
      
      i = i + 1;
    end
    
    function [ids, i] = statement(obj, i, ids)

      while ( i <= obj.NumTokens )
        current_type = obj.peek_type( i );

        if ( current_type == obj.TokenTypes.if )
          [ids, i] = obj.if_statement( i, ids );
          
        elseif ( current_type == obj.TokenTypes.for || ...
            current_type == obj.TokenTypes.parfor )
          [ids, i] = obj.for_statement( i, ids );
          
        elseif ( current_type == obj.TokenTypes.while )
          [ids, i] = obj.while_statement( i, ids );
          
        elseif ( current_type == obj.TokenTypes.persistent || ...
            current_type == obj.TokenTypes.global )
          [ids, i] = obj.persistent_or_global_statement( i, ids );
          
        elseif ( current_type == obj.TokenTypes.try )
          [ids, i] = obj.try_statement( i, ids );
          
        elseif ( current_type == obj.TokenTypes.switch )
          [ids, i] = obj.switch_statement( i, ids );
          
        elseif ( current_type == obj.TokenTypes.import )
          [ids, i] = obj.import_statement( i, ids );

        elseif ( current_type == obj.TokenTypes.identifier )
          next_type = obj.peek_type( i+1 );
          
          if ( next_type == obj.TokenTypes.identifier || ...
              next_type == obj.TokenTypes.string_literal )
            % Command syntax: hold on
            [ids, i] = obj.command_expression( i-1, ids );
          else
            [ids, i] = obj.identifier_expression( i-1, ids );
          end

        elseif ( current_type == obj.TokenTypes.function )
          if ( obj.ImplicitFunctionEnd )
            % Functions with implicit ends do not nest.
            return
          else
            obj.ScopeDepth = obj.ScopeDepth + 1;
            [new_ids, i] = obj.function_definition( i, {} );
            obj.ScopeDepth = obj.ScopeDepth - 1;
            ids(end+1:end+numel(new_ids)) = new_ids;
          end

        elseif ( current_type == obj.TokenTypes.left_bracket )
          % [a, b] = func()
          [ids, i] = obj.output_argument_expression( i, ids );

        elseif ( current_type == obj.TokenTypes.end || ...
            current_type == obj.TokenTypes.catch || ...
            current_type == obj.TokenTypes.elseif || ...
            current_type == obj.TokenTypes.else )
          break;
          
        elseif ( current_type == obj.TokenTypes.spmd )
          [ids, i] = obj.spmd_statement( i, ids );
        else
          i = i + 1;
        end
      end
    end
    
    function enter_function(obj)
      obj.EnclosingFunction(end+1) = numel( obj.FunctionDefinitions ) + 1;
    end
    
    function exit_function(obj)
      obj.EnclosingFunction(end) = [];
    end
    
    function f = enclosing_function(obj)
      assert( ~isempty(obj.EnclosingFunction) );
      f = obj.EnclosingFunction(end);
    end
    
    function [ids, i] = anonymous_function_definition(obj, begin, ids)
      
      enclosing_func = obj.enclosing_function();
      
      obj.ScopeDepth = obj.ScopeDepth + 1;
      obj.enter_function();
      
      current_func = obj.enclosing_function();
      
      [inputs, i] = obj.input_arguments( begin+1 );
      def = { [], inputs, [], enclosing_func };
      obj.FunctionDefinitions{current_func} = def;
      
      [ids, i] = obj.expression( i-1, ids );
      
      obj.exit_function();
      obj.ScopeDepth = obj.ScopeDepth - 1;
    end
    
    function [ids, i] = function_definition(obj, begin, ids)
      
      enclosing_func = obj.enclosing_function();
      obj.enter_function();

      i = begin + 1;

      inputs = [];
      outputs = [];

      if ( obj.peek_type(i) == obj.TokenTypes.left_bracket )
        % Multiple outputs
        [outputs, i] = obj.output_arguments( i );

      elseif ( obj.peek_type(i) == obj.TokenTypes.identifier )
        if ( obj.peek_type(i+1) == obj.TokenTypes.equal )
          % Single output
          outputs = i;
          i = i + 2;
        end
      else
        error( 'Unexpected token: "%s".', token_typename(obj.peek_type(i)) );
      end

      i = obj.consume_tokens( obj.TokenTypes.identifier, i );
      name = i - 1;

      if ( name < 1 )
        error( 'Expected function name.' );
      end

      if ( obj.peek_type(i) == obj.TokenTypes.left_parens )
        [inputs, i] = obj.input_arguments( i );
      end
      
      % Function header.
      def = { name, inputs, outputs, enclosing_func };

      obj.FunctionDefinitions{end+1} = def;
      
      [ids, i] = obj.statement( i, ids );
      
      if ( obj.peek_type(i) == obj.TokenTypes.end )
        i = i + 1;
      end
      
      obj.exit_function();
    end
    
    function [args, i] = arguments(obj, begin, terminator, require_commas)

      args = [];
      i = begin + 1;

      while ( i <= obj.NumTokens && obj.peek_type(i) ~= terminator )
        if ( obj.peek_type(i) == obj.TokenTypes.not )
          i = i + 1;
        else
          i = obj.consume_tokens( obj.TokenTypes.identifier, i );
          args(end+1) = i - 1;
        end

        if ( obj.peek_type(i) == obj.TokenTypes.comma )
          i = i + 1;
        elseif ( require_commas )
          % Ok to ignore output -- just using as validation.
          obj.consume_tokens( terminator, i );
        end
      end

      i = obj.consume_tokens( terminator, i );
    end
    
    function [ids, i] = output_argument_expression(obj, begin, ids)
      
      i = begin + 1;

      while ( i <= obj.NumTokens && obj.peek_type(i) ~= obj.TokenTypes.right_bracket )
        if ( obj.peek_type(i) == obj.TokenTypes.not )
          i = i + 1;
        end
        
        [tmp, i] = obj.expression( i-1, {} );
        [~, min_idx] = min( cellfun(@(x) min(x(1, :)), tmp) );

        if ( ~isempty(min_idx) )
          % Earliest identifier is variable.
          tmp{min_idx}(1) = -abs( tmp{min_idx}(1) );
        end

        ids = [ ids, tmp ];

        if ( obj.peek_type(i) == obj.TokenTypes.comma )
          i = i + 1;
        end
      end

      i = obj.consume_tokens( obj.TokenTypes.right_bracket, i );
      i = obj.consume_tokens( obj.TokenTypes.equal, i );
      
      [ids, i] = obj.expression( i-1, ids );
    end

    function [args, i] = output_arguments(obj, begin)
      [args, i] = obj.arguments( begin, obj.TokenTypes.right_bracket, false );
      i = obj.consume_tokens( obj.TokenTypes.equal, i );
    end

    function [args, i] = input_arguments(obj, begin)
      [args, i] = obj.arguments( begin, obj.TokenTypes.right_parens, true );
    end
    
    function tf = is_reference_token_type(obj, type)
      tf = type == obj.TokenTypes.left_parens || ...
        type == obj.TokenTypes.left_brace || type == obj.TokenTypes.period;
    end
    
    function tf = is_end_terminable_token(obj, type)
      tf = type == obj.TokenTypes.if || ...
          type == obj.TokenTypes.for || ...
          type == obj.TokenTypes.parfor || ...
          type == obj.TokenTypes.while || ...
          type == obj.TokenTypes.spmd || ...
          type == obj.TokenTypes.try || ...
          type == obj.TokenTypes.function || ...
          type == obj.TokenTypes.switch;
    end
    
    function tf = is_implicitly_terminated_function(obj, tokens)
      parens = 0;
      braces = 0;
      ends = 0;
      starts = 0;
      types = obj.TokenTypes;
      funcs = 0;
      tf = false;
      
      for i = 1:size(tokens, 1)
        t = tokens(i, 1);
        
        switch ( t )
          case types.left_parens
            parens = parens + 1;
          case types.right_parens
            parens = parens - 1;            
          case types.left_brace
            braces = braces + 1;
          case types.right_brace
            braces = braces - 1;
          case types.end
            if ( braces == 0 && parens == 0 )
              ends = ends + 1;
            end
          otherwise
            if ( obj.is_end_terminable_token(t) )
              starts = starts + 1;
              if ( t == types.function )
                funcs = funcs + 1;
              end
            end
        end
        
        if ( parens < 0 || braces < 0 )
          error( 'Unbalanced parenthese or bracket.' );
        end
      end
      
      if ( starts == ends )
        return
      elseif ( starts - ends ~= funcs )
        error( ['Cannot mix non-`end` terminated and `end`' ...
            , ' terminated functions in function file.'] );
      else
        tf = true;
      end
    end
    
    function t = peek_typename(obj, at)
      t = token_typename( obj.peek_type(at) );
    end
    
    function print_preceding(obj, at, n)
      for i = 1:n
        fprintf( '\n %s', obj.peek_tokenstr(at-i) );
      end
      fprintf( '\n ' );
    end
    
    function str = peek_lexeme(obj, at)
      if ( at == obj.TokenTypes.never )
        str = '<never>';
      else
        tok = obj.Tokens(at, :);
        str = obj.FileContents(tok(2):tok(3));
      end
    end
    
    function t = peek_tokenstr(obj, at)
      typename = obj.peek_typename( at );
      lexeme = obj.peek_lexeme( at );
      
      t = sprintf( '%s: %s', typename, lexeme );
    end
    
    function t = peek_type(obj, at)
      if ( at <= 0 || at > obj.NumTokens )
        t = obj.TokenTypes.never;
      else
        t = obj.Tokens(at, 1);
      end
    end
    
    function [tf, i] = is_sequence(obj, types, begin)
      tf = true;

      for i = 1:numel(types)
        actual_type = obj.peek_type(i - 1 + begin);

        if ( actual_type ~= types(i) )
          tf = false;
          return
        end
      end
    end
    
    function ind = consume_tokens(obj, types, begin)
      [tf, err_ind] = obj.is_sequence( types, begin );

      if ( ~tf )
        expected_t = token_typename( types(err_ind) );
        actual_t = token_typename( obj.peek_type(err_ind + begin - 1) );
        error( 'Expected token type: "%s"; got "%s".', expected_t, actual_t );
      end

      ind = begin + numel( types );
    end
    
    function id = make_id(obj, token_index)      
      sz = size( token_index );
      
      sd = repmat( obj.ScopeDepth, sz );
      ef = repmat( obj.enclosing_function(), sz );
      id_id = repmat( obj.IdentifierIndex, sz );
      
      if ( nnz(token_index) == numel(token_index) )
        tok_start = reshape( obj.Tokens(abs(token_index), 2), 1, [] );
      else
        tok_start = zeros( sz );
      end
      
      id = [ token_index; sd; ef; id_id; tok_start ];
      
      obj.IdentifierIndex = obj.IdentifierIndex + 1;
    end
  end
  
  methods (Access = private, Static = true)
    
    function mfiles = ensure_cellstr_func_names(mfiles)
      try
        mfiles = cellstr( mfiles );
      catch
        if ( ~iscell(mfiles) )
          mfiles = { mfiles };
        end
        
        mfiles = cellfun( @char, mfiles, 'un', 0 );
      end
    end
    
    function display_funcs(visited, in_files, funcs, kind)
      is_target = strcmp( in_files, visited );
      target_funcs = funcs(is_target);

      for i = 1:numel(target_funcs)
        if ( ~isempty(kind) )
          fprintf( '\n    %s (%s)', target_funcs{i}, kind );
        else
          fprintf( '\n    <a href="%s">%s</a>', target_funcs{i}, target_funcs{i} );
        end
      end
    end
    
    function display_results(deps)
      resolved_in = unique( deps.ResolvedIn );
      unresolved_in = unique( deps.UnresolvedIn );
      
      visited = union( resolved_in, unresolved_in );
      
      if ( isempty(visited) )
        fprintf( '\n  No functions were visited.' );
        
      else
        for i = 1:numel(visited)
          fprintf( '\n  <a href="%s" style="font-weight:bold">%s</a>', visited{i}, visited{i} );

          Dependencies.display_funcs( visited{i}, deps.ResolvedIn, deps.Resolved, '' );
          Dependencies.display_funcs( visited{i}, deps.UnresolvedIn, deps.Unresolved, 'Unresolved' );

          fprintf( '\n' );
        end
      end
      
      fprintf( '\n' );
    end
  end
  
  methods (Access = public, Static = true)
    function deps = of(mfile, varargin)
      
      logical_validator = ...
        @(x, name) validateattributes(x, {'logical'}, {'scalar'}, mfilename, name);
      
      p = inputParser();
      p.addParameter( 'Recursive', false, @(x) logical_validator(x, 'Recursive') );
      p.addParameter( 'Verbose', false, @(x) logical_validator(x, 'Verbose') );
      p.addParameter( 'SkipToolboxes', true, @(x) logical_validator(x, 'SkipToolboxes') );
      p.addParameter( 'Display', false, @(x) logical_validator(x, 'Display') );
      p.addParameter( 'Warn', true, @(x) logical_validator(x, 'Warn') );
      
      p.parse( varargin{:} );
      
      obj = Dependencies();
      obj.Verbose = p.Results.Verbose;
      obj.Recursive = p.Results.Recursive;
      obj.SkipToolboxFunctions = p.Results.SkipToolboxes;
      obj.Warn = p.Results.Warn;
      
      mfile = Dependencies.ensure_cellstr_func_names( mfile );
      obj.parse_files( mfile );
      
      [sorted_rs, sorted_rs_idx] = sort( obj.ResolvedDependentFunctions );
      [sorted_urs, sorted_urs_idx] = sort( obj.UnresolvedDependentFunctions );
      
      deps = struct();
      deps.Resolved = sorted_rs;
      deps.Unresolved = sorted_urs;
      deps.ResolvedIn = obj.ResolvedIn(sorted_rs_idx);
      deps.UnresolvedIn = obj.UnresolvedIn(sorted_urs_idx);
      
      if ( p.Results.Display )
        Dependencies.display_results( deps );
      end
    end
  end
end

function [tokens, i] = scan(file_contents)

i = 1;
n = numel( file_contents );
tokens = [];
meta = make_meta();

while ( i <= n )
  c = file_contents(i);
  
  if ( is_whitespace(c) && c ~= 10 )
    i = i + 1;
    continue;
  end
  
  add_token = true;
  
  if ( is_alpha(c) )
    [token, i] = identifier_or_keyword( file_contents, meta, i );
    
  elseif ( c == 10 )
    [token, i] = punctuation( file_contents, meta, i );
    
  elseif ( is_punct(c) )
    if ( c == apostr && ~is_primeable(file_contents(i-1)) )
      [token, i] = string_literal( file_contents, meta, i, apostr );
      
    elseif ( c == quote && ~is_primeable(file_contents(i-1)) )
      [token, i] = string_literal( file_contents, meta, i, quote );
      
    elseif ( c == percent )
      i = handle_comment( file_contents, meta, i );
      add_token = false;
      
    else
      if ( c == '.' && peek(file_contents, i) == '.' && peek(file_contents, i) == '.' )
        i = line_continuation( file_contents, meta, i + 3 );
        continue;
      elseif ( c == '.' && is_digit(peek(file_contents, i)) )
        [token, i] = number_literal( file_contents, meta, i );
      else
        [token, i] = punctuation( file_contents, meta, i );
      end
    end
    
  elseif ( is_digit(c) )
    [token, i] = number_literal( file_contents, meta, i );
    
  elseif ( c == 0 )
    i = i + 1;
    continue;
  else
    error( 'Unrecognized character: "%s"; %d.', c, real(c) );
  end
  
  if ( add_token )
    tokens(end+1, :) = token;
  end
end

end

function meta = make_meta()

meta = struct();
meta.token_types = token_types();
meta.scope = 0;

end

function name = token_typename(t)

types = token_types();
fs = fieldnames( types );

for i = 1:numel(fs)
  if ( types.(fs{i}) == t )
    name = fs{i};
    return
  end
end

error( 'Unrecognized type id: %d.', t );

end

function out_types = token_types()

persistent types;

if ( isempty(types) )
  types = struct();
  types.never = -1;
  types.function = 0;
  types.left_parens = 1;
  types.right_parens = 2;
  types.left_brace = 3;
  types.right_brace = 4;
  types.left_bracket = 5;
  types.right_bracket = 6;
  types.period = 7;
  types.equal = 8;
  types.equal_equal = 9;
  types.not_equal = 10;
  types.not = 11;
  types.colon = 12;
  types.identifier = 13;
  types.punctuation = 14;
  types.string_literal = 15;
  types.number_literal = 16;
  types.at = 17;
  types.comma = 18;
  types.binary_operator = 19;
  types.new_line = 20;
  types.colon = 21;
  types.semicolon = 22;
  types.for = 23;
  types.while = 24;
  types.postfix_operator = 25;

  last = numel( fieldnames(types) ) - 1;
  kws = iskeyword();
  kws{end+1} = 'import';

  for i = 1:numel(kws)
    types.(kws{i}) = last + i;
  end
end

out_types = types;

end

function token = make_token(type, lex_begin, lex_end)

token = [ type, lex_begin, lex_end ];

end

function i = line_continuation(contents, meta, begin)

n = numel( contents );
i = begin - 1;

while ( i <= n && peek(contents, i) ~= 10 )
  i = i + 1;
end

i = i + 2;  % consume newline.

if ( i > n )
  error( 'Unterminated line continuation (...) sequence.' );
end

end

function [token, i] = number_literal(contents, meta, begin)

n = numel( contents );
i = begin;
was_decimal = false;

while ( i <= n )
  c = contents(i);
  
  if ( ~is_digit(c) )
    if ( c ~= '.' )
      break;
    elseif ( was_decimal )
      if ( is_binary_operator(peek(contents, i)) )
        break;
      else
        error( 'Multiple decimal points in number literal.' );
      end
    else
      was_decimal = true;
    end
  end
  
  i = i + 1;
end

if ( peek(contents, i-1) == 'e' )
  while ( i < n && is_digit(contents(i+1)) )
    i = i + 1;
  end
  
  i = i + 1;
end

token = make_token( meta.token_types.number_literal, begin, i-1 );

end

function i = handle_comment(file_contents, meta, i)

if ( peek(file_contents, i) == '{'  )
  i = block_comment( file_contents, meta, i );
else
  i = comment( file_contents, meta, i );
end

end

function i = block_comment(contents, meta, begin)

n = numel( contents );
i = begin + 1;
terminated = false;

while ( i <= n && peek(contents, i) ~= 10 )
  i = i + 1;
end

i = i + 1;  % consume newline

while ( i <= n-1 )
  if ( peek(contents, i) == '%' && peek(contents, i+1) == '}' )
    i = i + 3;
    terminated = true;
    break;
  else
    i = i + 1;
  end
end

if ( ~terminated )
  error( 'Unterminated block comment.' );
end

end

function i = comment(contents, meta, begin)

n = numel( contents );
i = begin;

while ( i <= n && contents(i) ~= 10 )
  i = i + 1;
end

end

function [token, i] = string_literal(contents, meta, begin, str_char)

n = numel( contents );
i = begin + 1;
terminated = false;

while ( i <= n && ~terminated )
  c = contents(i);
  
  if ( c == str_char )
    if ( peek(contents, i) == str_char )
      i = i + 1;
    else
      terminated = true;
    end
  end
  
  i = i + 1;
end

stop = i - 1;

if ( ~terminated )
  error( 'Unterminated string literal.' );
end

token = make_token( meta.token_types.string_literal, begin, stop );

end

function [token, i] = identifier_or_keyword(contents, meta, begin)

n = numel( contents );
i = begin;

while ( i <= n && (is_alpha_numeric(contents(i)) || contents(i) == '_') )
  i = i + 1;
end

stop = i - 1;
id = contents(begin:stop);

if ( is_keyword(id) )
  if ( strcmp(id, 'end') && begin > 1 && contents(begin-1) == '.' )
    % end used as a field access: a.end
    token_type = meta.token_types.identifier;
  else
    token_type = meta.token_types.(id);
  end
else
  token_type = meta.token_types.identifier;
end

token = make_token( token_type, begin, stop );

end

function c = peek(contents, current)

if ( current >= numel(contents) )
  c = 0;
else
  c = contents(current + 1);
end

end

function [token, i] = punctuation(contents, meta, begin)

c = contents(begin);
stop = begin;
type = meta.token_types.punctuation;

switch ( c )
  case {'<', '>'}
    if ( peek(contents, begin) == '=' )
      stop = stop + 1;
    end
    type = meta.token_types.binary_operator;
  case '&'
    if ( peek(contents, begin) == '&' )
      stop = stop + 1;
    end
    type = meta.token_types.binary_operator;
  case '@'
    type = meta.token_types.at;
  case '|'
    if ( peek(contents, begin) == '|' )
      stop = stop + 1;
    end
    type = meta.token_types.binary_operator;
  case '='
    if ( peek(contents, begin) == '=' )
      type = meta.token_types.binary_operator;
      stop = stop + 1;
    else
      type = meta.token_types.equal;
    end
  case '~'
    if ( peek(contents, begin) == '=' )
      type = meta.token_types.binary_operator;
      stop = stop + 1;
    else
      type = meta.token_types.not;
    end
  case '.'
    if ( peek(contents, begin) == apostr )
      stop = stop + 1;
      type = meta.token_types.postfix_operator;
    elseif ( is_binary_operator(peek(contents, begin)) )
      stop = stop + 1;
      type = meta.token_types.binary_operator;
    else
      type = meta.token_types.period;
    end
  case apostr
    type = meta.token_types.postfix_operator;
  case ':'
    type = meta.token_types.colon;
  case ';'
    type = meta.token_types.semicolon;
  case ','
    type = meta.token_types.comma;
  case '('
    type = meta.token_types.left_parens;
  case ')'
    type = meta.token_types.right_parens;
  case '['
    type = meta.token_types.left_bracket;
  case ']'
    type = meta.token_types.right_bracket;
  case '{'
    type = meta.token_types.left_brace;
  case '}'
    type = meta.token_types.right_brace;
  case 10
    type = meta.token_types.new_line;
  otherwise
    if ( is_binary_operator(c) )
      type = meta.token_types.binary_operator;
    end
end

token = make_token( type, begin, stop );
i = stop + 1;

end

function c = apostr()
c = '''';
end

function c = quote()
c = '"';
end

function c = percent()
c = '%';
end

function tf = is_punct(a)
tf = isstrprop( a, 'punct' ) || is_unary_operator( a ) || a == '=' || ...
  is_binary_operator( a );
end

function tf = is_whitespace(a)
tf = isstrprop( a, 'wspace' );
end

function tf = is_digit(a)
tf = a >= '0' && a <= '9';
end

function tf = is_alpha(a)
tf = (a >= 'A' && a <= 'Z') || (a >= 'a' && a <= 'z');
end

function tf = is_alpha_numeric(a)
tf = (a >= 'A' && a <= 'Z') || (a >= 'a' && a <= 'z') || (a >= '0' && a <= '9');
end

function tf = is_unary_operator(a)
tf = a == '~' || a == '-';
end

function tf = is_keyword(str)
tf = iskeyword( str ) || strcmp( str, 'import' );
end

function tf = is_binary_operator(a)
tf = a == '+' || a == '-' || a == '/' || a == '*' || a == '<' || a == '>' || ...
  a == '|' || a == '&' || a == '^';
end

function tf = is_primeable(a)

tf = is_alpha_numeric( a ) || a == '.' || a == '_' || a == ')' || a == ']' || ...
  a == '}';

end

function tf = is_known_builtin(func_name)
  persistent funcs;

  if ( isequal(funcs, []) )
    funcs = containers.Map();
    
    known_builtins = { ...
        'error', 'numel', 'length', 'size', 'sum', 'prod' ...
      , 'char', 'double', 'single', 'cell', 'struct', 'logical' ...
      , 'arrayfun', 'cellfun', 'structfun' ...
      , 'strcmp', 'strncmp', 'strcmpi', 'strncmpi' ...
    };

    for i = 1:numel(known_builtins)
      funcs(known_builtins{i}) = 1;       
    end
  end
  
  tf = isKey( funcs, func_name );
end