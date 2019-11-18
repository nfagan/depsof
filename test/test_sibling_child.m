function test_sibling_child(a, b, c)

sibling();

end

function sibling()

  function child()
    non_existent();
    sibling();
    child();
  end

end