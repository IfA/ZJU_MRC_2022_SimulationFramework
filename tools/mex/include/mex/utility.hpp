#ifndef MEX_UTILITY_HPP
#define MEX_UTILITY_HPP

#include <type_traits>
#include "matrix.h"

namespace mex {

template <typename T> struct get_class;

template <> struct get_class<signed char>: public std::integral_constant<mxClassID, mxINT8_CLASS> { };
template <> struct get_class<unsigned char>: public std::integral_constant<mxClassID, mxUINT8_CLASS> { };
template <> struct get_class<signed short>: public std::integral_constant<mxClassID, mxINT16_CLASS> { };
template <> struct get_class<unsigned short>: public std::integral_constant<mxClassID, mxUINT16_CLASS> { };
template <> struct get_class<signed int>: public std::integral_constant<mxClassID, mxINT32_CLASS> { };
template <> struct get_class<unsigned int>: public std::integral_constant<mxClassID, mxUINT32_CLASS> { };
template <> struct get_class<signed long>: public std::integral_constant<mxClassID, mxINT32_CLASS> { };
template <> struct get_class<unsigned long>: public std::integral_constant<mxClassID, mxUINT32_CLASS> { };
template <> struct get_class<signed long long>: public std::integral_constant<mxClassID, mxINT64_CLASS> { };
template <> struct get_class<unsigned long long>: public std::integral_constant<mxClassID, mxUINT64_CLASS> { };
template <> struct get_class<float>: public std::integral_constant<mxClassID, mxSINGLE_CLASS> { };
template <> struct get_class<double>: public std::integral_constant<mxClassID, mxDOUBLE_CLASS> { };    

static inline bool is_scalar(const mxArray *arr) {
    return (mxGetNumberOfElements(arr) == 1);
}

}

#endif // MEX_UTILITY_HPP
