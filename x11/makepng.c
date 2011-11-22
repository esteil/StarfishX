/*

Copyright ©2000 Philip Derrin
All Rights Reserved

This file is part of xstarfish

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

#include <stdio.h>
#include <png.h>
#include "starfish-engine.h"

/* takes a StarfishRef and returns a ptr to a 24-bit RGBA pixmap */
png_byte** PixFromStarfishTex(StarfishRef tex);

/* frees a pixmap created by the above function */
void DestroyPix(png_byte** pixmap, int height);

void MakePNGFile(StarfishRef tex, const char* filename)
{
	FILE* theFile;
	int width, height, x, y;
	png_byte** pixmap = NULL;
	png_infop theInfoPtr = NULL;
	png_structp theWritePtr = NULL;

	/* create the file */
	theFile = fopen(filename, "wb");
	if(!theFile)
	{
		fprintf(stderr, "xstarfish: could not open output file.\n");
		return;
	}
	
	/* turn the StarfishRef into something useable */
	width = StarfishWidth(tex);
	height = StarfishHeight(tex);
	pixmap = PixFromStarfishTex(tex);
	
	/* set up libpng */
	if(pixmap)
	{
		theWritePtr = png_create_write_struct
			(PNG_LIBPNG_VER_STRING, (png_voidp)NULL, NULL, NULL);
		if(!theWritePtr)
		{
			fprintf(stderr, "xstarfish: could not allocate png write struct\n");
			return;
		}
	}

	if(theWritePtr)
	{
		theInfoPtr = png_create_info_struct(theWritePtr);
		if(!theInfoPtr)
		{
			fprintf(stderr, "xstarfish: could not allocate png info struct\n");
			png_destroy_write_struct(&theWritePtr,
				(png_infopp)NULL);
			return;
		}
	}	

	if(theInfoPtr)
	{
		/* set up the png error handling. */
		if (setjmp(theWritePtr->jmpbuf))
		{
			png_destroy_write_struct(&theWritePtr, &theInfoPtr);
			fclose(theFile);
			fprintf(stderr, "xstarfish: there was an error writing the PNG file.\n");
			return;
		}
	
		/* tell libpng about the output file. */
		png_init_io(theWritePtr, theFile);
	
		/* set up the image info... */
		png_set_IHDR(theWritePtr, theInfoPtr, width, height, 8,
			PNG_COLOR_TYPE_RGB, PNG_INTERLACE_NONE,
			PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);
		
		/* ... and write it to the file. */
		png_write_info(theWritePtr, theInfoPtr);
		
		/* now write the image data. */
		png_write_image(theWritePtr, pixmap);
		
		/* clean up after libpng */
		png_write_end(theWritePtr, NULL);
		png_destroy_write_struct(&theWritePtr, &theInfoPtr);
	}
	
	/* clean up our stuff */
	DestroyPix(pixmap, height);
	fclose(theFile);
	
	return;
}

png_byte** PixFromStarfishTex(StarfishRef tex)
{
	png_byte** pixmap;
	int height = StarfishHeight(tex), width = StarfishWidth(tex);
	int curRow, curPixel;
	pixel thePixel;
	
	pixmap = malloc(height * sizeof(png_byte*));
	if( pixmap )
	{
		for(curRow = 0; curRow < height; curRow++)
		{
			pixmap[curRow] = malloc(width * sizeof(png_byte) * 3);
			for(curPixel = 0; curPixel < width; curPixel++)
			{
				GetStarfishPixel(curPixel, curRow, tex, &thePixel);
				pixmap[curRow][curPixel * 3] = thePixel.red;
				pixmap[curRow][curPixel * 3 + 1] = thePixel.green;
				pixmap[curRow][curPixel * 3 + 2] = thePixel.blue;
			}
		}
	}
	return pixmap;
}

void DestroyPix(png_byte** pixmap, int height)
{
	int curRow;
	for(curRow = 0; curRow < height; curRow++)
		free(pixmap[curRow]);
	free(pixmap);
}
