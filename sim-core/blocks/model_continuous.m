% Wrapper around continuous_integration for very simple continuous blocks
% that do not need any input/output adjustments
function model = model_continuous(initialState, model_equations, input)
    model = block_base(0, input, @propagate);    
    model.log.uniform = true;
    model.default_initialState = initialState;
    
    function [state, out, debugOut] = propagate(block, t, state, in)
        debugOut = [];
        [state, out] = continuous_integration(model_equations, block.initialtate, t, state, in);        
    end   
end
