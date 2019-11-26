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

function nested_import()

import pkg.*;

s = nested.nested();

end

function class_import()

import pkg.Class;
import pkg.Class;

x = Class(1, 2, Class());

end