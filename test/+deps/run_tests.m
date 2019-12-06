function run_tests()

run_test_imports();
run_test_sibling_child();
run_test_empty_parent();
run_test_inputs();
run_test_nested_referencing()
run_test_imports_with_anonymous_functions();

end

function run_test_nested_referencing()

func_name = 'test_nested_referencing';
options = make_options( {}, {'something.one.two'} );

errs = run_test( func_name, options );
print_as_warning( errs );

end

function run_test_imports_with_anonymous_functions()

func_name = 'test_imports_with_anonymous_functions';
expect_resolved = {'deps.run_tests' };
options = make_options( expect_resolved, {} );

errs = run_test( func_name, options );
print_as_warning( errs );

end

function run_test_imports()

func_name = 'test_imports';
expect_resolved = {'deps.run_tests', 'pkg.Class', 'pkg.nested.nested'};
options = make_options( expect_resolved, {} );

errs = run_test( func_name, options );
print_as_warning( errs );

end

function run_test_empty_parent()

func_name = 'test_empty_parent';

options = make_options( {}, {} );

errs = run_test( func_name, options );
print_as_warning( errs );

end

function run_test_sibling_child()

func_name = 'test_sibling_child';
expect_unresolved = { 'child', 'parentss', 'another' };

options = make_options( {}, expect_unresolved );

errs = run_test( func_name, options );
print_as_warning( errs );

end

function run_test_inputs()

func_name = 'test_inputs';
options = make_options( {}, {} );

errs = run_test( func_name, options );
print_as_warning( errs );

end

function options = make_options(varargin)

cell_validator = @(name) @(v) validateattributes(v, {'cell'}, {}, mfilename, name);

p = inputParser();
p.addRequired( 'Resolved', cell_validator('ExpectResolved') );
p.addRequired( 'Unresolved', cell_validator('ExpectUnresolved') );
p.addParameter( 'ResolvedIn', [], cell_validator('ResolvedIn') );
p.addParameter( 'UnresolvedIn', [], @(v) cell_validator('UnresolvedIn') );

p.parse( varargin{:} );

options = p.Results;

end

function f = result_fields()

f = { 'Resolved', 'Unresolved', 'ResolvedIn', 'UnresolvedIn' };

end

function print_as_warning(errs)

for i = 1:numel(errs)
  if ( ~isempty(errs{i}) )
    warning( errs{i}.message );
  end
end

end

function errs = run_test(func_names, options)

func_names = cellstr( func_names );
d = depsof( func_names );
fs = result_fields();

errs = cell( numel(fs), 1 );

for i = 1:numel(fs)
  res = d.(fs{i});
  expect_match = options.(fs{i});
  
  should_skip = isempty( expect_match ) && isa( expect_match, 'double' );
  
  if ( should_skip )
    continue;
  end
  
  % Ensure same orientation.
  res = sort( res(:)' );  %#ok
  expect_match = sort( expect_match(:)' ); %#ok
  
  fname = sprintf( '%s-%s', fs{i}, strjoin(func_names, '-') );
  
  if ( ~isequal(res, expect_match) && (~isempty(res) || ~isempty(expect_match)) )
    try
      error( 'Expected subsets do not match for "%s".', fname );
    catch err
      errs{i} = err;
    end
  end
end

end