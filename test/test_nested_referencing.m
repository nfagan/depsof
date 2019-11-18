function test_nested_referencing()

ncp = 0;
deltaP = 0;

if all(deltaP>0)
  ncp=[ncp(1)-abs(diff(ncp)) ncp(1)];
end

end