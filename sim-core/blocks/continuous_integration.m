function [state, X_f] = continuous_integration(model_equations, X_0, tEnd, state, in)
    if isempty(state)           
        state = [tEnd X_0(:)']; 
    elseif ~isempty(in)            
        t = state(1);
        X = state(2:end);
        iIn = 1;        
        while t < tEnd
            if iIn < length(in)
                tPartEnd = in(iIn + 1).t; 
            else tPartEnd = tEnd; 
            end
            if (tPartEnd - t) > 1e-6
                inPart = in(iIn).data;
                % ode45 seems to have problems with very short time intervals                
                [~, X] = ode45(@(t, x)model_equations(t, x, inPart), [t, tPartEnd], X);
                X = X(end, :);
            end
            t = tPartEnd;
            iIn = iIn + 1;
        end
        state = [t X];
    end        
    X_f = state(2:end);
end