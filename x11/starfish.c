/*

Starfish
A graphic texture generator.
Copyright ©1999-2000 Mars Saxman - All Rights Reserved

This is the Unix version. It uses the starfish engine
to create colourful and exotic desktop patterns and apply them
to the X11 desktop at user-selected intervals.

The starfish rendering code can be found in the 'portable' directory.
starfish-engine.h contains the main control routines.

Starfish can be run immediately as a command, or it can be launched
as a daemon, in which case it will fork itself off into the background
and produce patterns at regular intervals.


This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.


*/

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <stdio.h>
#include <ctype.h>
#include <X11/bitmaps/gray>
#include <unistd.h>
#include "starfish-engine.h"
#include "starfish-rasterlib.h"
#include "setdesktop.h"
#include "makepng.h"
#include "genutils.h"

void usage(void)
	{
	puts(
		"xstarfish 1.1\n"
		"Copyright (c) 1999-2000 Mars Saxman & others\n"
		"A simple hack to create tiled root window backgrounds.\n"
		"Usage: xstarfish [options...]\n"
		"Options include:\n"
		"-h,--help,--usage:\n"
		"		Print the message you're reading now\n"
		"-d,--daemon:	Fork off into the background. This offers two arguments.\n"
		"		The first argument is an interval between patterns;\n"
		"		Starfish will generate a pattern, sleep that many\n"
		"		seconds, then repeat. The second argument specifies the\n"
		"		units for the sleep interval: seconds, minutes, hours,\n"
		"		days, weeks. Seconds are the default interval.\n"
		"-v/--version:	current version of this program.\n"
		"-g/--geometry: size of desired image in WxH format. If you omit the height,\n"
		"		a square pattern WxW will be generated.\n"
		"-o,--outfile: specify an output file. If you use this option,\n"
		"		starfish will write a png file instead of setting the X11\n"
		"		desktop.\n"
		"-s,--size:	An approximate size in English. Valid size arguments are\n"
		"		small, medium, large, full, and random. Full size creates\n"
		"		patterns the exact size of your display's default monitor.\n"
		"		Small, medium, and large are randomly sizes at appropriate\n"
		"		fractions of the default monitor size. And random can be\n"
		"		any size from 64x64 up to the whole monitor. Size always\n"
		"		overrides geometry.\n"
	        "-r,--random:   specify seed for rand() call - for debugging.\n"
		"--display:	one argument, name of the desired target display.\n"
	    );
	}

void CalcRandomSize(int* width, int* height, const char* sizename, const char* displayname)
	{
	/*
	Figure out how big the default monitor is.
	Then come up with some reasonable size values based on that.
	Return them.
	*/
	int screen;
	int minH, maxH, minV, maxV;
	Display* display = XOpenDisplay(displayname);
	if(display)
		{
		screen = DefaultScreen(display);
		maxH = DisplayWidth(display, screen);
		maxV = DisplayHeight(display, screen);
		}
	else
		{
		/*
		In the case that someone tries to run this without X,
		we fabricate numbers based on the smallest common display.
		*/
		maxH = 640;
		maxV = 480;
		}
	minV = minH = 64;
	if(!strcmp(sizename, "full"))
		{
		minH = maxH;
		minV = maxV;
		}
	else if(!strcmp(sizename, "small"))
		{
		maxH /= 6;
		maxV /= 6;
		}
	else if(!strcmp(sizename, "medium"))
		{
		minH = maxH / 6;
		minV = maxV / 6;
		maxH /= 3;
		maxV /= 3;
		}	
	else if(!strcmp(sizename, "large"))
		{
		minH = maxH / 3;
		minV = maxV / 3;
		maxH /= 2;
		maxV /= 2;
		}
	*width = irandge(minH, maxH);
	*height = irandge(minV, maxV);
	if(display) XCloseDisplay(display);
	}

void ExtractGeometry(const char* geostr, int* width, int* height)
	{
	/*
	Turn the WWxHH string into width & height values.
	If there's no 'x', we use equal width and height.
	This is a cheap little string parser.
	*/
	*width = 0;
	*height = 0;
	while(isdigit(*geostr))
		{
		*width *= 10;
		*width += *geostr - '0';
		geostr++;
		}
	/*
	Is the next character an 'x' or 'X'?
	If yes, that means we have a height value following.
	If no, that means we have only a single value (width) which
	we will now copy into height.
	*/	
	if(*geostr == 'x' || *geostr == 'X')
		{
		geostr++;
		while(isdigit(*geostr))
			{
			*height *= 10;
			*height += *geostr - '0';
			geostr++;
			}
		}
	else *height = *width;
	/*
	Is the next character null? 
	If so, we ate our entire string and things are cool.
	If not, there's crap on the command line.
	*/
	if(*geostr) fprintf(stderr, "xstarfish: The geometry option is broken - \"%s\"\n", geostr);
	}

int main(int argc, char** argv)
	{
	/*
	Default behaviour is non-daemon. Starfish simply starts up, does its thing, and quits. 
	If daemon is specified but no time is given, Starfish uses 20 minutes interval.
	Default width and height are 256 pixels.
	Though the starfish engine supports colour palettes, there is currently no way to
	access that feature through the command line.

	mjs 13/12/2k - the following comment appeared in the original source but I never 
		implemented the functionality it describes. It is unlikely it ever will
		get implemented but it was kind of a neat idea:
	If no outfile is specified, Starfish checks to see if isatty(stdout). If yes, it tries
	to set the X root window's background pixmap with its results. If no, it writes its
	results to stdout in either PPM or raw format (I haven't decided which).
	If an outfile is specified, Starfish dumps its output to the file in whatever pixel
	format is easiest to write. I may someday add a fancy algorithm that guesses what type
	of image to write by the file extension (foo.png would get written in PNG format,
	foo.jpeg in JPEG format...) but that sounds too "tricky". Probably will just use pixmap.
	*/
	/*
	PD 13/12/2000
	The -o (--outfile) option now works, and writes a png file (no matter what
	the extension is). Needs libpng to build, but this is included with most
	distros. What about isatty(stdout)? Or checking that the extension is .png
	and writing raw bitmap data otherwise?
	*/
	int ctr;
	int width, height;
	int sleeptime;
	int daemon;
	StarfishRef texture;
	const char* displayName;
	const char* sizeName;
	const char* filename;
	char haveOutfile;
	/*
	Set up our defaults. These may be overridden by command line parameters.
	*/
	width = height = 256;
	sleeptime = 20 * 60;	/* measured in seconds */
	daemon = 0;
	displayName = NULL;
	sizeName = NULL;
	filename = NULL;
	haveOutfile = 0;
	srand(time(0));  /* we may override this when parsing the arguments */
	for(ctr = 1; ctr < argc; ctr++)
		{
		if(argv[ctr][0] != '-')
			{
			fprintf(stderr, "xstarfish: parameter \"%s\" is bogus.\n", argv[ctr]);
			return 1;
			}
		if(!strcmp(argv[ctr], "-d") || !strcmp(argv[ctr], "--daemon"))
			{
			/*
			If the next parameter is numeric, grab it. We'll use it as our sleep
			time. Otherwise, we'll leave the default in place.
			*/ 
			if(ctr + 1 < argc && isdigit(argv[ctr + 1][0]))
				{
				sleeptime = atoi(argv[++ctr]); 
				}
			daemon = 1;
			/*
			if we have more parameters, and the next one does not begin with -,
			we treat it as a units specifier
			*/
			if(ctr + 1 < argc && argv[ctr + 1][0] != '-')
				{
				ctr++;
				if(!strcmp(argv[ctr], "minutes")) sleeptime *= 60;
				else if(!strcmp(argv[ctr], "minute")) sleeptime *= 60;
				else if(!strcmp(argv[ctr], "hours")) sleeptime *= 3600;
				else if(!strcmp(argv[ctr], "hour")) sleeptime *= 3600;
				else if(!strcmp(argv[ctr], "days")) sleeptime *= 86400;
				else if(!strcmp(argv[ctr], "day")) sleeptime *= 86400;
				else if(!strcmp(argv[ctr], "weeks")) sleeptime *= 604800;
				else if(!strcmp(argv[ctr], "week")) sleeptime *= 604800;
				else if(!strcmp(argv[ctr], "seconds")) sleeptime *= 1;
				else if(!strcmp(argv[ctr], "second")) sleeptime *= 1;
				else
					{
					fprintf(stderr, "xstarfish: parameter \"%s\" is bogus.\n", argv[ctr]);
					return 1;
					}
				}
			}
		else if(!strcmp(argv[ctr], "-g") || !strcmp(argv[ctr], "--geometry"))
			{
			/*
			Parse a size string. The format is always WWxHH
			*/
			if(ctr + 1 < argc) ExtractGeometry(argv[++ctr], &width, &height);
				else fprintf(stderr, "xstarfish: geometry value is missing");
			}
		else if(!strcmp(argv[ctr], "-o") || !strcmp(argv[ctr], "--outfile"))
			{
			/*
			The next parameter is an output file name. Grab it.
			*/
			if(ctr + 1 < argc)
				{
				filename = argv[++ctr];
				haveOutfile = 1;
				}
			else
				{
                                fprintf(stderr, "xstarfish: %s requires an argument.\n", argv[ctr]);
				}
			}
		else if(!strcmp(argv[ctr], "-r") || !strcmp(argv[ctr], "--random"))
			{
			/*
			If the next parameter is numeric, grab it.
			*/ 
			if(ctr + 1 < argc && isdigit(argv[ctr + 1][0]))
				{
				srand(atoi(argv[++ctr]));
				}
			else
				{
			        fprintf(stderr, "xstarfish: \"-r\" requires an argument.\n");
				}			     
			}
		else if(!strcmp(argv[ctr], "-h") || !strcmp(argv[ctr], "--usage")
				|| !strcmp(argv[ctr], "--help"))
			{
			usage();
			return 0;
			}
		else if(!strcmp(argv[ctr], "-v") || !strcmp(argv[ctr], "--version"))
			{
			fprintf(stderr, "xstarfish 1.1\n"
				"Copyright 1999-2000 Mars Saxman & others\n"
				"\n"
				"This program comes with NO WARRANTY, to the extent permitted by law.\n"
				"You may redistribute copies of this program under the terms of the\n"
				"GNU General Public License.\n"
				"For more information, see the file named COPYING or visit\n"
				"http://www.gnu.org/copyleft/gpl.html.\n"
				);
			return 0;
			}
		else if(!strcmp(argv[ctr], "--display"))
			{
			ctr++;
			if(ctr < argc) displayName = argv[ctr];
			}
		else if(!strcmp(argv[ctr], "-s") || !strcmp(argv[ctr], "--size"))
			{
			ctr++;
			if(ctr < argc)
			   {
			   if		(	
					strcmp(argv[ctr], "small") &&
					strcmp(argv[ctr], "medium") &&
					strcmp(argv[ctr], "large") &&
					strcmp(argv[ctr], "full") &&
					strcmp(argv[ctr], "random")
			  		)
				{
				  fprintf(stderr, "xstarfish: size \"%s\" is bogus.\n", argv[ctr]);
				}
			   else
				{
			          sizeName = argv[ctr];
				}
			   }
			else
			   {
			   fprintf(stderr, "xstarfish: \"-s\" requires an argument.\n");
			   }
			}
		}
	/*
	This line relies on conditional evaluation.
	IIRC, that's in K&R, so it should be alright...
	*/
	if(daemon && fork()) return 0;
	/*
	Do the thing that makes Starfish worth installing.
	Create a seamlessly tiled, anti-aliased image. Then do with
	it whatever the user requested. If called with --output, we write
	the image to disk; otherwise, we set it as the X11 root background.
	*/
	//Make a starfish texture description we can pull pixels from.
	do
		{
		if(sizeName) CalcRandomSize(&width, &height, sizeName, displayName);
		texture = MakeStarfish(width, height, NULL);
		if(texture)
			{
			if(haveOutfile) MakePNGFile(texture, filename);
			else SetXDesktop(texture, displayName);
			DumpStarfish(texture);
			}
		else
			{
			fprintf(stderr, "xstarfish: was not able to create texture\n");
			return 1;
			}
		if(daemon){sleep(sleeptime);}
		}
	while(daemon);
	return 0;
	}

