function [resolved, unresolved] = test_resolveUnknownType(obj, unknownType)
% resolveUnknownType Add Extrinsic symbol to root set if file exists
    import matlab.depfun.internal.MatlabSymbol;
    import matlab.depfun.internal.MatlabType;
    import matlab.depfun.internal.cacheWhich;
    import matlab.depfun.internal.cacheExist;

    unresolved = {};
    resolved = {};
    for u = 1:numel(unknownType)
        % Full path to file, or file on the MATLAB path. (Check
        % here for MATLAB file types too, in case they were missed
        % by earlier classifications.)
        if ~isempty(unknownType{u})
            e = cacheExist(unknownType{u}, 'file');
            if e == 2 || e == 3 || e == 4 || e == 6
                [~,name,~]=fileparts(unknownType{u});
                % Do we have a full path, or do we need to look for 
                % the file with WHICH?
                if isfullpath(unknownType{u})
                    pth = unknownType{u};
                else
                    pth = cacheWhich(unknownType{u});
                end
                % Three-argument MatlabSymbol: specify name, type and
                % full path.                    
                uSym = MatlabSymbol(name, MatlabType.Extrinsic, pth);
                resolved = [ resolved, uSym ];
            else
                unresolved = [ unresolved, unknownType(u) ];
            end
        end
    end
end