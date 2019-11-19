function test_sibling_child()

sibling();  % should be found, unmarked.
child();  % should be unresolved.

  function parentss()    
    function another()
    end
  end

end

function s = sibling()
  parentss(); % should be unresolved.

  function child()
    sibling();  % should be found, unmarked.
    another(); % should be unresolved.
  end
end

function s = sibling_empty()
  function child1()
    sibling_empty();  % should be found, unmarked.
  end
end