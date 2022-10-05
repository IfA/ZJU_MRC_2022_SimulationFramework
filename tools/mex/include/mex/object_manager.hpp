#ifndef MEX_OBJECT_MANAGER_HPP
#define MEX_OBJECT_MANAGER_HPP

#include "matrix.h"
#include <iostream>
#include <map>
#include <utility>
#include <typeinfo>
#include <stdexcept>
#include <string>
#include <string.h>
#include <mex/utility.hpp>
#include <cstdint>
#ifdef __GNUG__
#include <cxxabi.h>
#endif
// manage objects that should persist between multiple calls to a mex function 
namespace mex {
    
template <typename Obj, typename MethodId = int, typename Key = uint64_t>
class object_manager {    
public:
    typedef Obj object_type;
    typedef MethodId method_id_type;
    typedef Key key_type;
    
    object_manager(): constructionRequiresArgument_(false) { };
    virtual ~object_manager() {
        if (instances_.empty()) return;
#ifdef __GNUG__        
        char *demangledName = abi::__cxa_demangle(typeid(Obj).name(), NULL, NULL, NULL);        
#else
        const char *demangledName = typeid(Obj).name();
#endif
        std::cout << "object_manager<" << demangledName << "> cleaning up all instances" << std::endl;
#ifdef __GNUG__
        free(demangledName);
#endif
        for(auto it = instances_.begin(); it != instances_.end(); ++it) delete it->second;
        instances_.clear();        
    }
    
    void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
        if (nrhs <= 1) {
            if (nlhs != 1) throw std::runtime_error("Constructor requires exactly one output argument");
            
            const mxArray *mxOpts = NULL;
            if (nrhs == 0) {
                if (constructionRequiresArgument_) throw std::runtime_error("Object construction requires an argument structure");
            } else {
                mxOpts = prhs[0];
                if (!mxIsStruct(mxOpts) || !mex::is_scalar(mxOpts)) throw std::runtime_error("Invalid constructor argument: scalar struct expected");
            }

            Obj *ptr = create(mxOpts);
            if (!ptr) throw std::runtime_error("Object construction failed.");
            
            Key key = (Key)ptr; // for now: use pointer as key
            while(instances_.find(key) != instances_.end()) key++; // to be sure...
            instances_.insert(std::make_pair(key, ptr));
            
            plhs[0] = mxCreateNumericMatrix(1, 1, mex::get_class<Key>::value, mxREAL);
            *static_cast<Key *>(mxGetData(plhs[0])) = key;                    
        } else if (nrhs <= 3) {
            // invoke function
            const mxArray *mxHandle = prhs[0];
            const mxArray *mxMethod = prhs[1];
            
            const mxArray *mxOpts = NULL;
            if (mxGetClassID(mxHandle) != mex::get_class<Key>::value || !mex::is_scalar(mxHandle)) 
                throw std::runtime_error("Invalid handle argument: Use return value of a constructor call!");
            Key key = *static_cast<const Key *>(mxGetData(mxHandle));
            
            auto it = instances_.find(key);
            if (it == instances_.end()) throw std::runtime_error("Invalid handle! Instance not found.");                        
            Obj *ptr = it->second;
            
            if (!mxIsChar(mxMethod)) throw std::runtime_error("Command argument must be a string");
#ifdef __GNUG__
            size_t methodStringSpace = mxGetNumberOfElements(mxMethod) + 1;
#else
            const size_t methodStringSpace = 256;
#endif            
            char methodString[methodStringSpace];
            if (mxGetString(mxMethod, methodString, methodStringSpace) == 1) throw std::runtime_error("Could not read command");
            
            if (nrhs >= 3) {
                mxOpts = prhs[2];
                if (!mxIsStruct(mxOpts) || !mex::is_scalar(mxOpts)) throw std::runtime_error("Invalid function argument: Scalar structure expected!");                
            }
            
            if (strcmp(methodString, "delete") == 0) {
                // destructor
                if (mxOpts) mexWarnMsgTxt("Parameters for 'delete' command ignored.");
                instances_.erase(it);
                delete ptr;
            } else {
                typename method_map::const_iterator itMethod = supportedMethods_.find(methodString);
                if (itMethod == supportedMethods_.end()) throw std::runtime_error("Unsupported method!");
                invoke(*ptr, itMethod->second, mxOpts, nlhs, plhs);
            }
        } else throw std::runtime_error("Too many input arguments");
    };
    
    virtual Obj *create(const mxArray *mxOpts) = 0;
    virtual void invoke(Obj &obj, MethodId methodId, const mxArray *mxOpts, int nlhs, mxArray *plhs[]) = 0;        

protected:
    void setConstructionRequiresArgument(bool b) { constructionRequiresArgument_ = b; }
    void addMethod(const std::string &name, MethodId id) {
        supportedMethods_[name] = id;
    }
private:
    typedef std::map<Key, Obj *> instance_map;
    typedef std::map<std::string, MethodId> method_map;
    
    instance_map instances_;
    bool constructionRequiresArgument_;    
    method_map supportedMethods_;
};

#define MEX_DECLARE_OBJECT_MANAGER(Type) \
    static Type mexObjectManager_; \
    void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) { \
        mexObjectManager_.mexFunction(nlhs, plhs, nrhs, prhs); \
    }

} // namespace mex
    
#endif // MEX_OBJECT_MANAGER_HPP
