function test_imports()

import deps.run_tests;

run_tests();

end

function wildcard_import()

import deps.*;

run_tests();

end

function matlab_import()

import matlab.lang.makeValidName;

s = makeValidName( 'some value' );

end