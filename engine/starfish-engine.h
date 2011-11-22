/*

Copyright ©1999-2003 Mars Saxman
All Rights Reserved

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

#ifndef STARFISH_ENGINE_H
#define STARFISH_ENGINE_H

typedef struct StarfishGeneratorRec		*StarfishRef;

struct pixel
	{
	unsigned char red;
	unsigned char green;
	unsigned char blue;
	unsigned char alpha;
	};
typedef struct pixel pixel;

#define MAX_PALETTE_ENTRIES 256
struct StarfishPalette
	{
	int colourcount;
	pixel colour[MAX_PALETTE_ENTRIES];
	};
typedef struct StarfishPalette StarfishPalette;

/*
Create a starfish texture.
Ask for its pixels, in any order.
When you're finished, dump the texture.
*/

#ifdef __cplusplus
extern "C" {
#endif

void GetStarfishPixel( int x, int y, StarfishRef texture, pixel* out );
void DumpStarfish( StarfishRef it );

#if BUILD_ALTIVEC
void GetStarfishPixel_AV(int x, int y, StarfishRef texture, vector unsigned char *pixels);
StarfishRef MakeStarfish( int width, int height, const StarfishPalette* palette, bool wrapEdges, bool useAltivec );
#else
StarfishRef MakeStarfish( int width, int height, const StarfishPalette* palette, bool wrapEdges );
#endif

#ifdef __cplusplus
}
#endif

#endif //STARFISH_ENGINE_H
