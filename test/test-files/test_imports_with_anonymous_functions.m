function test_imports_with_anonymous_functions()

import deps.run_tests;

y = @(x) @(z) @(w) run_tests();

end