//$ mex joyshow.c -lSDL
/* Show current state of all controls for a single joystick
 * 
 * joyshow    - Show information for first joystick
 * joyshow(n) - Show information for joystick n
 */

#include <mex.h>
#include <matrix.h>
#include <SDL/SDL.h>

#define printf mexPrintf

void mexFunction(
		 int          nlhs,
		 mxArray      *plhs[],
		 int          nrhs,
		 const mxArray *prhs[]
		 )
{
	int joystickIndex = 0;
	if(nrhs > 1) mexErrMsgTxt("Too many input argumets.");
	if(nrhs == 1) joystickIndex = (int)mxGetScalar(prhs[0]);
	

	SDL_Init( SDL_INIT_JOYSTICK | SDL_INIT_NOPARACHUTE );
	SDL_JoystickEventState( SDL_ENABLE );
	int num = SDL_NumJoysticks();
	if(joystickIndex >= num) mexErrMsgTxt("Joystick not found");
	
	
	SDL_Joystick* jstick = SDL_JoystickOpen(joystickIndex);
	if(!jstick) mexErrMsgTxt("Could not open joystick");
	
	printf("Information for %s\n", SDL_JoystickName(joystickIndex));
	int nAxes = SDL_JoystickNumAxes(jstick);
	for(int i = 0; i < nAxes; i++) {
		printf("Axis   %2d: %6d\n", i, SDL_JoystickGetAxis(jstick, i));
	}
	int nButtons = SDL_JoystickNumButtons(jstick);
	for(int i = 0; i < nButtons; i++) {
		printf("Button %2d: %s\n", i, SDL_JoystickGetButton(jstick, i) ? "Down" : "---");
	}
	int nHats = SDL_JoystickNumHats(jstick);
	for(int i = 0; i < nHats; i++) {
		int dirs = SDL_JoystickGetHat(jstick, i);
		printf("Hat    %2d: %s%s%s%s\n", i, dirs & SDL_HAT_UP ? "N" : "", dirs & SDL_HAT_DOWN ? "S" : "", dirs & SDL_HAT_LEFT ? "W" : "", dirs & SDL_HAT_RIGHT ? "E" : "");		
	}
	int nBalls = SDL_JoystickNumBalls(jstick);
	for(int i = 0; i < nBalls; i++) {
		int dx, dy;
		if(SDL_JoystickGetBall(jstick, i, &dx, &dy) == 0) printf("Ball %2d: %+d, %+d\n", i, dx, dy);
		else printf("Ball   %2d: <READ ERROR>\n", i);
	}
}

