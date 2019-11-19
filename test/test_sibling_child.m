function test_sibling_child(a, b, c)

sibling();

end

function sibling()

  function child()
    sibling();
    child();
    non_existent();
    
    function another()
      function another2()
        another()
      end
    end    
  end

%   child();

end