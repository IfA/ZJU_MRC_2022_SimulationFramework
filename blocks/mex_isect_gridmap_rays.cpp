//$ mex mex_isect_gridmap_rays.cpp # Maltab command for generating the MEX file
/*******************************************************
 * test rays for intersection with an obstacle grid map and optionally 
 * return the distance from the start point to the first obstacle.
 * Outputs: 
 * - intersection = true for each ray that intersects an obstacle
 * - range = distance from start to first obstacle or NaN when no intersection was found
 *Inputs:
 * - obstacles: matrix (uint8 or mxLogical), map of obstacles
 * - rayStart: Mx2 matrix of ray start coordinates (relative to map)
 * - rayEnd: Mx2 matrix of ray end coordinates (relative to map)
 * - obstacleValue (optional) which value in the map should be treated as obstacle, 0/false by default
 */


#include "mex.h"
#include "matrix.h"
#include <cmath>
#include <memory>
#include <algorithm>
#include <functional>
#include <limits>

#define printf mexPrintf

#define radToDeg(rad) ((rad) * 180.0 / M_PI)
#define degToRad(deg) ((deg) * M_PI / 180.0)

#define INDEX_IN_MAP        0
#define INDEX_IN_START      1
#define INDEX_IN_END        2
#define IN_REQ_COUNT        3
#define INDEX_IN_OBSTVALUE  3
#define IN_MAX_COUNT		4

#define INDEX_OUT_ISECT     0
#define OUT_REQ_COUNT       1
#define INDEX_OUT_RANGE     1
#define OUT_MAX_COUNT       2

struct MxArrayDeleter {
    void operator()(mxArray *mx) { mxDestroyArray(mx); }
};

typedef std::unique_ptr<mxArray, MxArrayDeleter> UniqueMxArrayPointer;

class IntersectionDetector {
public:
    IntersectionDetector(const mxArray *mxMap, const mxArray *mxRayStart, const mxArray *mxRayEnd) {
        width = mxGetN(mxMap);
        height = mxGetM(mxMap);
        pitch = height;
        count = mxGetM(mxRayStart);
        rayStart.pX = mxGetPr(mxRayStart);
        rayStart.pY = rayStart.pX + count;
        rayEnd.pX = mxGetPr(mxRayEnd);
        rayEnd.pY = rayEnd.pX + count;        
    }    

    template <typename CellType>
    void operator()(const CellType *pMap, const CellType &obstacleValue = CellType(), bool generateRange = true) {
        mxISect_ = UniqueMxArrayPointer(mxCreateLogicalMatrix(count, 1));
        mxLogical *pISect = (mxLogical *)mxGetData(mxISect_.get());
        double *pRange = NULL;
        if (generateRange) {
            mxRange_ = UniqueMxArrayPointer(mxCreateDoubleMatrix(count, 1, mxREAL));
            pRange = mxGetPr(mxRange_.get());
        }        

        for (size_t i = 0; i < count; i++) {
            int xs = (int)(*rayStart.pX++); /* add rounding constant of 0.5 and subtract Matlab array-start-with-1-offset */
			int ys = (int)(*rayStart.pY++);
            if (xs >= 0 && ys >= 0 && xs < width && ys < height) {
                if (pMap[xs * pitch + ys] != obstacleValue) {
                    int xe = (int)(*rayEnd.pX++);
                    int ye = (int)(*rayEnd.pY++);
                    
					int dx = xe - xs;
					int dy = ye - ys;
                    int x, y, prevX, prevY;
                    bool isect;
                    
#define CHECK_CELL \
    if (pMap[x * pitch + y] != obstacleValue) { \
        prevX = x; \
        prevY = y; \
    } else break;

                    if (dx >= 0) { /* octants 1, 2, 7, 8 */
						if (dy >= 0) { /* octants 1, 2 */
							if (dx >= dy) { /* octant 1 */
                                int error = dx >> 1;				
								int xe_ = xe < width ? xe : (width - 1);
								for(prevX = x = xs, prevY = y = ys; x <= xe_; x++) { 
                                    CHECK_CELL						  
									error -= dy;
									if (error < 0) {
										if (++y >= height) break;
										error += dx;
									}
								}
                                isect = (x <= xe);
							} else { /* octant 2 */
								int error = dy >> 1;
								int ye_ = ye < height ? ye : (height - 1);
								for(prevX = x = xs, prevY = y = ys; y <= ye_; y++) {
									CHECK_CELL
									error -= dx;
									if (error < 0) {
										if (++x >= width) break;
										error += dy;
									}
								}
                                isect = (y <= ye);
							}				 
						} else { /* octants 7, 8 */
							dy = -dy;
							if ( dx >= dy) { /* octant 8 */
								int error = dx >> 1;
								int xe_ = xe < width ? xe : (width - 1);
								for(prevX = x = xs, prevY = y = ys; x <= xe_; x++) {
									CHECK_CELL
									error -= dy;
									if (error < 0) {
										if (--y < 0) break;
										error += dx;
									}
								}				
                                isect = (x <= xe);
							} else { /* octant 7 */
								int error = dy >> 1;
								int ye_ = ye < 0 ? 0 : ye;
								for(prevX = x = xs, prevY = y = ys; y >= ye_; y--) {
									CHECK_CELL
									error -= dx;
									if (error < 0) {
										if (++x >= width) break;
										error += dy;
									}
								} 
                                isect = (y >= ye);
                            }
						}
					} else { /* octants 3-6 */
						dx = -dx;
						if (dy >= 0) { /* octants 3, 4 */
							if (dx >= dy) { /* octant 4 */
								int error = dx >> 1;
								int xe_ = xe < 0 ? 0 : xe;
								for(prevX = x = xs, prevY = y = ys; x >= xe_; x--) {
									CHECK_CELL
									error -= dy;
									if (error < 0) {
										if (++y >= height) break;
										error += dx;
									}
								}
                                isect = (x >= xe);
							} else { /* octant 3 */
								int error = dy >> 1;
								int ye_ = ye < height ? ye : (height - 1);
								for(prevX = x = xs, prevY = y = ys; y <= ye_; y++) {
									CHECK_CELL
									error -= dx;
									if (error < 0) {
										if (--x < 0) break;
										error += dy;
									}
								} 
                                isect = (y <= ye);
							}
						} else { /* octants 5, 6 */
							dy = -dy;
							if (dx >= dy) { /* octant 5 */
								int error = dx >> 1;
								int xe_ = xe < 0 ? 0 : xe;
								for(prevX = x = xs, prevY = y = ys; x >= xe_; x--) {
									CHECK_CELL
									error -= dy;
									if (error < 0) {
										if (--y < 0) break;
										error += dx;
									}
								}
                                isect = (x >= xe);
							} else { /* octant 6 */
								int error = dy >> 1;
								int ye_ = ye < 0 ? 0 : ye;
								for(prevX = x = xs, prevY = y = ys; y >= ye_; y--) {
									CHECK_CELL
									error -= dx;
									if (error < 0) {
										if (--x < 0) break;
										error += dy;
									}
								} 				
                                isect = (y >= ye);
							}
						}
					} 
#undef CHECK_CELL

                    *pISect++ = isect;
                    if (pRange) {
                        *pRange++ = isect ? sqrt((double)((prevX - xs) * (prevX - xs) + (prevY - ys) * (prevY - ys))) : 
                                            std::numeric_limits<double>::signaling_NaN();
                    }
                    continue;
                }
            }
                
            // ray starts off the map or the start position is an obstacle
            *pISect++ = true;
            if (pRange) *pRange++ = 0.0;            
        }                     
    }
    
    UniqueMxArrayPointer mxISect() {
        return std::move(mxISect_);
    }
    UniqueMxArrayPointer mxRange() {
        return std::move(mxRange_);
    }
    
private:
    int width, height;
    unsigned pitch, count;
    struct {
        const double *pX;
        const double *pY;
    } rayStart, rayEnd;
    
    UniqueMxArrayPointer mxISect_, mxRange_;
};

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {    
    if (nrhs < IN_REQ_COUNT) mexErrMsgTxt("Too few input arguments");
	if (nrhs > IN_MAX_COUNT) mexErrMsgTxt("Too many input arguments");
	if (nlhs < OUT_REQ_COUNT) mexErrMsgTxt("Too few output arguments");
    if (nlhs > OUT_MAX_COUNT) mexErrMsgTxt("Too many output arguments");

    const mxArray *mxMap = prhs[INDEX_IN_MAP];
    const mxArray *mxRayStart = prhs[INDEX_IN_START];
    const mxArray *mxRayEnd = prhs[INDEX_IN_END];
    const mxArray *mxObstacleValue = (nrhs > INDEX_IN_OBSTVALUE) ? prhs[INDEX_IN_OBSTVALUE] : NULL;
    

	if (mxGetNumberOfDimensions(mxMap) != 2 || !(mxIsUint8(mxMap) || mxIsLogical(mxMap)) ||
		mxIsComplex(mxMap) || mxIsEmpty(mxMap)) 
        mexErrMsgTxt("Input argument 'map' must be a non-empty, real uint8 or logical matrix");

	if (mxGetNumberOfDimensions(mxRayStart) != 2 || mxGetN(mxRayStart) != 2 ||
		!mxIsDouble(mxRayStart) || mxIsComplex(mxRayStart)) 
        mexErrMsgTxt("Input argument 'rayStart' must be a Mx2 double matrix");

	if (mxGetNumberOfDimensions(mxRayEnd) != 2 || mxGetN(mxRayEnd) != 2 || mxGetM(mxRayStart) != mxGetM(mxRayEnd) ||
        !mxIsDouble(mxRayEnd) || mxIsComplex(mxRayEnd))
		mexErrMsgTxt("Input argument 'rayEnd' must be a double matrix of the same size as 'rayStart'");
    
    unsigned obstacleValue = 0;
    
	if(mxObstacleValue) {
        if (mxIsComplex(mxObstacleValue) || mxGetNumberOfElements(mxObstacleValue) != 1 ||
            !(mxIsNumeric(mxObstacleValue) || mxIsLogical(mxObstacleValue)))
            mexErrMsgTxt("Input argument 'obstacleValue' must be a noncomplex numeric scalar value");
        
        obstacleValue = (unsigned)mxGetScalar(mxObstacleValue);
	}   
    
    IntersectionDetector detector(mxMap, mxRayStart, mxRayEnd);
    
    if (mxIsUint8(mxMap)) {
        detector((const unsigned char *)mxGetData(mxMap), (unsigned char)obstacleValue, nlhs > INDEX_OUT_RANGE);
    } else if (mxIsLogical(mxMap)) {
        detector((const mxLogical *)mxGetData(mxMap), (mxLogical)obstacleValue, nlhs > INDEX_OUT_RANGE);
    } else mexErrMsgTxt("Unsupported data format. This should have been detected earlier!");
    
    plhs[INDEX_OUT_ISECT] = detector.mxISect().release();
    if (nlhs > INDEX_OUT_RANGE) plhs[INDEX_OUT_RANGE] = detector.mxRange().release();
}
