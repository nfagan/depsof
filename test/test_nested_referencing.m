function test_nested_referencing()

ncp = 0;
deltaP = 0;

if all(deltaP>0)
  ncp=[ncp(1)-abs(diff(ncp)) something.one.two() ncp(1)];
end

ncp=[ncp(1)-ncp{2} something.one.two() ncp(1)];

end