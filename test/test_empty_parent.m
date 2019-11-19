function test_empty_parent()
end

function empty_parent()
  function child1()
    % should be found, unmarked.
    test_empty_parent();
    empty_parent();
  end
end