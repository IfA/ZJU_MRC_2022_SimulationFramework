% Wrap a mex function using the mex::object_wrapper paradigm into
% a Matlab handle class to have destructors called automatically when
% the object goes out of scope
classdef mex_object_handle < handle
    properties
        key;
        mexFunctionHandle;
    end
    methods
        function obj = mex_object_handle(mexFunc, varargin)
            obj.mexFunctionHandle = mexFunc;
            if isempty(varargin)
                obj.key = mexFunc();
            elseif length(varargin) == 1 && isstruct(varargin{1})
                obj.key = mexFunc(varargin{1});
            elseif length(varargin) > 1
                obj.key = mexFunc(struct(varargin{:}));
            else error('Invalid arguments');
            end
        end
        function varargout = invoke(obj, method, varargin)                         
            varargout = cell(1, nargout);
            if isempty(varargin)
                [varargout{:}] = obj.mexFunctionHandle(obj.key, method);
            elseif length(varargin) == 1 && isstruct(varargin{1})
                [varargout{:}] = obj.mexFunctionHandle(obj.key, method, varargin{1});
            elseif length(varargin) > 1
                [varargout{:}] = obj.mexFunctionHandle(obj.key, method, struct(varargin{:}));
            else error('Invalid arguments');
            end
        end
        function delete(obj)
            obj.mexFunctionHandle(obj.key, 'delete');
        end
    end
end

