% Utility block that extracts a single field from a struct input or an
% element (or a list of elements) from an array input

function block = block_extract(input, field_or_index)
    if ~isvarname(input)
        error('sim:block_transform', 'The "input" argument must be a nonempty string');
    end
    if ischar(field_or_index)
        if ~isvarname(field_or_index)
            error('sim:block_transform', 'The specified field value is not a valid matlab field name');
        end    
        block = block_transform(input, @(in)in.(field_or_index));
    elseif isnumeric(field_or_index)
        block = block_transform(input, @(in)in(field_or_index));
    else
        error('sim:block_transform', 'The type of the extract specification is not supported');
    end
end