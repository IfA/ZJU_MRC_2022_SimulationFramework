//$ mex mex_occupancy_grid_rangefinder_model.cpp # Maltab command for generating the MEX file
/*******************************************************/
/* Compute the log-likelihood update for an laser-rangefinder based occupancy grid mapping algorithm
 * Output: 
 * - matrix of log-likelihood updates 
 *Input: Parameter struct with fields
 * - pos: position of the rangefinder device (common ray origin) in world coordinates
 * - offset: offset of the requested map slice in world coordinates
 * - scale: grid resolution
 * - size: map size in cell coordinates, i.e. [width, height] in number of cells
 * - maxRange: maximum detection distance of the rangefinder in world coordinates
 * - rangeError: 1 sigma of the expected distance error (in world coordinates)
 * - ranges: row or column vector of range measurements
 * - bearings: row or column vector (same size as ranges) of ray orientations relative to the world coordinate system IN ASCENDING ORDER
 * - ...read the code below for further parameters
 */


#include "mex.h"
#include "matrix.h"
#include <cmath>
#include <algorithm>

#define printf mexPrintf

inline double absAngleDifference(double angle1, double angle2) {
    double difference = fabs(angle1 - angle2);
    if (difference > M_PI) return 2.0 * M_PI - difference;
    else return difference;
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {    
    if (nrhs != 1) mexErrMsgTxt("Missing input argument");
    if (nlhs != 1) mexErrMsgTxt("Missing output argument");

    const mxArray *mxArgs = prhs[0];
    if (!mxIsStruct(mxArgs) || mxGetNumberOfElements(mxArgs) != 1) 
        mexErrMsgTxt("Invalid input argument: expected (scalar) structure.");
    
    #define DECLARE_ARG_FIELD(fieldName, varName) \
        const mxArray *varName = mxGetField(mxArgs, 0, #fieldName); \
        if (!varName) mexErrMsgTxt("Required field \"" #fieldName "\" missing from argument struture");
    
    #define DECLARE_SCALAR_ARG(fieldName, varName) \
        DECLARE_ARG_FIELD(fieldName, mx##varName) \
        if (!mxIsNumeric(mx##varName) || mxIsComplex(mx##varName) || mxGetNumberOfElements(mx##varName) != 1) \
            mexErrMsgTxt("Invalid data in argument field \"" #fieldName "\": expected noncomplex scalar numeric value"); \
        double varName = mxGetScalar(mx##varName);
        
    DECLARE_ARG_FIELD(pos, mxPos)
    if (!mxIsDouble(mxPos) || mxIsComplex(mxPos) || mxGetNumberOfElements(mxPos) != 2)
        mexErrMsgTxt("Invalid data in argument field \"pos\": expected 2-element real-valued double vector");
    const double *scannerPos = mxGetPr(mxPos);
    
    DECLARE_ARG_FIELD(offset, mxOffset)
    if (!mxIsDouble(mxOffset) || mxIsComplex(mxOffset) || mxGetNumberOfElements(mxOffset) != 2)
        mexErrMsgTxt("Invalid data in argument field \"offset\": expected 2-element real-valued double vector");    
    const double *mapOffset = mxGetPr(mxOffset);

    DECLARE_SCALAR_ARG(scale, mapScale)

    DECLARE_ARG_FIELD(size, mxSize)
    if (!mxIsDouble(mxSize) || mxIsComplex(mxSize) || mxGetNumberOfElements(mxSize) != 2)
        mexErrMsgTxt("Invalid data in argument field \"size\": expected 2-element real-valued double vector");
    int mapWidth = (int)(mxGetPr(mxSize)[0] + 0.5);
    int mapHeight = (int)(mxGetPr(mxSize)[1] + 0.5);    
    if (mapWidth <= 0 || mapHeight <= 0) mexErrMsgTxt("Invalid map size: Both dimensions must be positive");
    
    DECLARE_SCALAR_ARG(maxRange, maxRange)
    if (maxRange <= 0.0) mexErrMsgTxt("Invalid parameter: maxRange must be positive!");
    
    DECLARE_SCALAR_ARG(rangeError, rangeError)    
    DECLARE_SCALAR_ARG(rayWidth, rayWidth)
    DECLARE_SCALAR_ARG(prior, prior)
    DECLARE_SCALAR_ARG(pFree, pFree)
    DECLARE_SCALAR_ARG(pOccupied, pOccupied)

    DECLARE_ARG_FIELD(bearings, mxBearings)
    if (!mxIsDouble(mxBearings) || mxIsComplex(mxBearings) || mxGetNumberOfDimensions(mxBearings) > 2 || (mxGetN(mxBearings) != 1 && mxGetM(mxBearings) != 1))
        mexErrMsgTxt("Invalid data in argument field \"bearings\": expected real-valued double vector (row or column)");
    const double *bearings = mxGetPr(mxBearings);
    unsigned nMeas = mxGetNumberOfElements(mxBearings);    
    DECLARE_ARG_FIELD(ranges, mxRanges)        
    if (!mxIsDouble(mxRanges) || mxIsComplex(mxRanges) || mxGetNumberOfDimensions(mxRanges) > 2 || (mxGetN(mxRanges) != 1 && mxGetM(mxRanges) != 1) || mxGetNumberOfElements(mxRanges) != nMeas)
        mexErrMsgTxt("Invalid data in argument field \"ranges\": expected real-valued double vector of the same size as field \"bearings\"");
    const double *ranges = mxGetPr(mxRanges);
            
    // generate output map
    mxArray *mxOut = plhs[0] = mxCreateDoubleMatrix(mapHeight, mapWidth, mxREAL);
    
    double *lMap = mxGetPr(mxOut);
    double x = mapOffset[0] - 0.5 * mapScale;
    double lOccupied = log(pOccupied / (1 - pOccupied));
    double lFree = log(pFree / (1 - pFree));
    double lPrior = log(prior / (1.0 - prior));
    
    rayWidth *= 0.5;
    for (unsigned iX = 0; iX < mapWidth; iX++) {
        double y = mapOffset[1] - 0.5 * mapScale;        
        unsigned rayIndex = 0;
        double rayDiffAngle = INFINITY;
        for (unsigned iY = 0; iY < mapHeight; iY++) {
            double dX = x - scannerPos[0];
            double dY = y - scannerPos[1];            
            double angle = atan2(dY, dX);
            double distance = sqrt(dX * dX + dY * dY);
            // search the best-matching ray
            if (iY == 0) {
                for (unsigned iRay = 0; iRay < nMeas; iRay++) {
                    double diffAngle = absAngleDifference(angle, bearings[iRay]);
                    if (diffAngle < rayDiffAngle) {
                        rayDiffAngle = diffAngle;
                        rayIndex = iRay;
                    }
                }
            } else {
                rayDiffAngle = absAngleDifference(angle, bearings[rayIndex]);
                
                if (x < scannerPos[0]) {
                    for (unsigned iCount = 0; iCount < nMeas; iCount++) {
                        int iRay = (rayIndex == 0) ? (nMeas - 1) : (rayIndex - 1);
                        double diffAngle = absAngleDifference(angle, bearings[iRay]);                    
                        if (diffAngle < rayDiffAngle) {
                            rayDiffAngle = diffAngle;
                            rayIndex = iRay;
                        } else break;                    
                    }
                } else {
                    for (unsigned iCount = 0; iCount < nMeas; iCount++) {
                        int iRay = (rayIndex >= nMeas - 1) ? 0 : (rayIndex + 1);
                        double diffAngle = absAngleDifference(angle, bearings[iRay]);
                        if (diffAngle < rayDiffAngle) {
                            rayDiffAngle = diffAngle;
                            rayIndex = iRay;
                        } else break;
                    }
                }
            }
            
            double range = ranges[rayIndex];
            if (rayDiffAngle <= rayWidth) {
                if (range <= maxRange) {
                    double rangeDiff = distance - range;
                    double rangeUncertainty = 3.0 * rangeError * range;
                    if (rangeUncertainty < mapScale) rangeUncertainty = mapScale;
                    if (rangeDiff < -rangeUncertainty) {
                        *lMap  = lFree;
                    } else if (rangeDiff < 0.0) {
                        *lMap  = lOccupied + (lFree - lOccupied) * -rangeDiff / rangeUncertainty;
                    } else if (rangeDiff < rangeUncertainty) {
                        *lMap  = lOccupied + (lPrior - lOccupied) * rangeDiff / rangeUncertainty;
                    } else *lMap  = lPrior;
                } else {
                    if (distance < maxRange) *lMap  = lFree;
                    else *lMap  = lPrior;
                }
            } else *lMap  = lPrior;
                
            
            lMap++;
            y += mapScale;
        }
        x += mapScale;
    }
    
}
