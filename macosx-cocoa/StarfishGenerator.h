/*

Copyright 2003 M. Scott Marcy
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


#import <Foundation/Foundation.h>
#import "StarfishController.h"


@interface StarfishGenerator : NSObject
{
	StarfishRef			_generator;
	int					_curCol, _maxCol;
	int					_curLine, _maxLines;
	int					_realMaxLines;
	NSBitmapImageRep*	_bitmap;
	BOOL				_useAltivec;
	int					_numThreads;
	BOOL				_generating;
	BOOL				_stop;
	BOOL				_mainThread;
	NSMutableArray*		_childThreads;
	StarfishGenerator*	_parentThread;
	int					_paletteIndex;
}

- (id) init:(int)patternSize
			usePalette:(int)whichPalette
			paletteArray:(NSArray*)paletteList
			forScreen:(NSScreen*)whichScreen
			usingAltivec:(BOOL)usingAltivec
			numberOfThreads:(int)numThreads
			customSize:(NSSize)custSize
			wrapEdges:(BOOL)wrap;
- (void) dealloc;

- (BOOL) done;
- (void) generateImage;
- (BOOL) imageComplete;
- (NSData*) imageData:(BOOL)compress;
- (NSData*) imageDataAsJPEG:(float)quality;
- (double) maxProgress;
- (double) progress;
- (void) stopGenerating;
- (int) paletteIndex;
- (NSSize) patternSize;
@end
