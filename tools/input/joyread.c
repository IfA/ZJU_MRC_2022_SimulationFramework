//$ mex joyread.c -lSDL
/* Read input from single joystick
 * 
 * joyread    - read from first joystick
 * joyread(n) - read from joystick n
 * 
 * The Information read is determined by the number of lhs arguments. 
 * You may use up to four arguments:
 * [axes] = joyread
 * [axes, buttons] = joyread
 * [axes, buttons, hats] = joyread
 * [axes, buttons, hats, balls] = joyread
 * 
 * axes are scaled from -1 to 1
 * buttons are 1 when pressed and 0 when released
 * hat values are a bitwise OR combination of UP(1), RIGHT(2), DOWN(4) and LEFT(8)
 * balls is a #balls times 2 matrix, with each row representing the [x, y] delta since the last query
 * 
 * See SDL_JoystickGet... function for further details
 *  
 */

#include <mex.h>
#include <matrix.h>
#include <SDL/SDL.h>
#include <math.h>

#define printf mexPrintf

void mexFunction(
		 int          nlhs,
		 mxArray      *plhs[],
		 int          nrhs,
		 const mxArray *prhs[]
		 )
{
	int joystickIndex = 0;
	if(nrhs > 1) mexErrMsgTxt("Too many input arguments.");
	if(nrhs == 1) joystickIndex = (int)mxGetScalar(prhs[0]);
	
	if(nlhs > 4) mexErrMsgTxt("Too many output arguments.");

	SDL_Init( SDL_INIT_JOYSTICK | SDL_INIT_NOPARACHUTE );
	SDL_JoystickEventState( SDL_ENABLE );
	int num = SDL_NumJoysticks();
	if(joystickIndex >= num) mexErrMsgTxt("Joystick not found");
		
	
	SDL_Joystick* jstick = SDL_JoystickOpen(joystickIndex);
	if(!jstick) mexErrMsgTxt("Could not open joystick");
	
	if(nlhs >= 1) {
		// read axes
		int nAxes = SDL_JoystickNumAxes(jstick);
		double *pAx = mxGetPr(plhs[0] = mxCreateDoubleMatrix(nAxes, 1, mxREAL));
		for(int i = 0; i < nAxes; i++) {
			int pos = SDL_JoystickGetAxis(jstick, i);
			pAx[i] = pos < 0 ? (double)pos / 32768.0 : (double)pos / 32767.0;
		}
	}
	if(nlhs >= 2) {
		// read buttons
		int nButtons = SDL_JoystickNumButtons(jstick);
		double *pBtn = mxGetPr(plhs[1] = mxCreateDoubleMatrix(nButtons, 1, mxREAL));
		for(int i = 0; i < nButtons; i++) pBtn[i] = SDL_JoystickGetButton(jstick, i) ? 1.0 : 0.0;
	}
	if(nlhs >= 3) {
		// read hats
		int nHats = SDL_JoystickNumHats(jstick);
		double *pHats = mxGetPr(plhs[2] = mxCreateDoubleMatrix(nHats, 1, mxREAL));
		for(int i = 0; i < nHats; i++) pHats[i] = (double)SDL_JoystickGetHat(jstick, i);
	}
	if(nlhs >= 4) {
		// read balls
		int nBalls = SDL_JoystickNumBalls(jstick);
		double *pBalls = mxGetPr(plhs[3] = mxCreateDoubleMatrix(nBalls, 2, mxREAL));
		for(int i = 0; i < nBalls; i++) {
			int dx, dy;
			if(SDL_JoystickGetBall(jstick, i, &dx, &dy) == 0) {
				pBalls[i] = dx;
				pBalls[nBalls + i] = dy;
			} else pBalls[i] = pBalls[nBalls + i] = NAN;
		}
	}
}

