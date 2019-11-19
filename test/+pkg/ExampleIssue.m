classdef ExampleIssue
  methods
    function obj = ExampleIssue()
      should_be_visible()
      should_be_invisible();
    end
  end
end

function should_be_visible()
  function should_be_invisible()
  end
end
