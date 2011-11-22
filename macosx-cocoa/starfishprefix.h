/*
 *  starfishprefix.h
 *  XStarFish
 *
 *  Created by mscott on Fri Oct 19 2001.
 *  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
 *
 */

#include <Carbon/Carbon.h>

// These are defines I want throughout the entire project, including the portable code.

//#define debug

#ifdef debug
	#define	TEST_ALTIVEC_GENERATORS	1
#else
	#define	TEST_ALTIVEC_GENERATORS	0
#endif

#define BUILD_MP			1
#define MAC_OSX_PIXEL_ORDER	1

#if BUILD_ALTIVEC
    #define VECTOR	vector
#endif

#include <vecLib/vecLib.h>
#include <math.h>

// OS X headers use slightly different names from OS 9
#define vDivf(x,y)		vdivf(x,y)
#define vATanf(x)		vatanf(x)
#define vATan2f(y,x)	vatan2f(y,x)
#define vPowf(x,y)		vpowf(x,y)
#define vSqrtf(x)		vsqrtf(x)
#define abs(x)			fabs(x)
#define vSinf(x)		vsinf(x)
#define vCosf(x)		vcosf(x)

// OS X doesn't define powf, so we'll use pow instead
#define powf(x,y)		pow(x,y)
