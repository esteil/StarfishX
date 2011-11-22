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


#import "StarfishGenerator.h"
#import "SFXUtilities.h"

NSLock		*gLineLock;
int			gNextLine;


@interface StarfishGenerator (private)
- (id) initChildThread:(StarfishGenerator*)parent
						startingLine:(int)startLine
						endingLine:(int)endLine;
- (void) killChildThreads;
- (BOOL) spawnThreads;
- (void) startChildThreads;
- (void) stopChildThreads;
- (void) calculateStarfishPalette:(StarfishPalette*) it paletteIndex:(int)whichPalette paletteArray:(NSArray*)paletteList;
- (void) createRandomSize:(int)sizecode forScreen:(NSScreen*)theScreen customSize:(NSSize)custSize;
@end



@implementation StarfishGenerator

- (id) init:(int)patternSize
			usePalette:(int)whichPalette
			paletteArray:(NSArray*)paletteList
			forScreen:(NSScreen*)whichScreen
			usingAltivec:(BOOL)usingAltivec
			numberOfThreads:(int)numOfThreads
			customSize:(NSSize)custSize
			wrapEdges:(BOOL)wrap;
{
	BOOL				createdGenerator = NO;
	StarfishPalette		colors;
	int					sizecode = patternSize;

	self = [super init];

	_useAltivec = usingAltivec;
	_numThreads = numOfThreads;
//	_bitmap = nil;				// In case we fail below
//	_generating = NO;
	_mainThread = YES;
//	_childThreads = nil;
//	_parentThread = nil;

	if (gLineLock != nil)
		gLineLock = [[NSLock alloc] init];

	// Get the selected palette
	[self calculateStarfishPalette:&colors paletteIndex:whichPalette paletteArray:paletteList];

	// If the user picked "random", make the pattern whatever size will fit.
	if (patternSize == sizeCodeRandom)
		sizecode = irand(SIZE_CODE_RANGE + 1);
	else if (patternSize == sizeCodeRandomNoFullScreen)
		sizecode = irand(SIZE_CODE_RANGE_NO_FULL_SCREEN + 1);
	else
		irand(1);	// Just to keep the random numbers in sync if we're trying to generate the same thing with some different parameters

	while (sizecode >= sizeCodeSmall && !createdGenerator)
	{
		[self createRandomSize:sizecode forScreen:whichScreen customSize:custSize];
		_realMaxLines = _maxLines;
		//Create a GWorld to store the destination image.
		//Next create a pattern to match the size of this GWorld.
		_bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
						pixelsWide:_maxCol
						pixelsHigh:_maxLines
						bitsPerSample:8
						samplesPerPixel:4
						hasAlpha:YES
						isPlanar:NO
						colorSpaceName:NSDeviceRGBColorSpace
						bytesPerRow:0		// Let them figure it out
						bitsPerPixel:0];	// Let them figure it out
		if (_bitmap != nil)
		{
			_curLine = _curCol = 0;
			gNextLine = 1;
#if BUILD_ALTIVEC
				_generator = MakeStarfish(_maxCol, _maxLines, &colors, wrap, _useAltivec);
#else
				_generator = MakeStarfish(_maxCol, _maxLines, &colors, wrap);
#endif
			if (_generator != nil)
				createdGenerator = YES;
		} // if
		sizecode--;	// In case we failed
	} // while

	if (createdGenerator) {
		if (_numThreads > 1)
			[self spawnThreads];
	} else {
		if (_bitmap != nil)
			[_bitmap release];
		self = nil;
	} // if

	return self;
} // init:usePalette:paletteArray:forScreen:usingAltivec:numberOfThreads:

// -----

- (void) dealloc
{
	if (_generating)
		[self stopGenerating];

	if (_childThreads != nil) {
		[self killChildThreads];
		[_childThreads release];
	} // if

	// Child threads only have references to these objects, only the main thread owns them
	if (_mainThread) {
		if (_generator != nil) {
#if BUILD_ALTIVEC
			if (_useAltivec) {
#ifdef BUILD_20
				DumpStarfish(_generator);
#else
				DumpStarfish_AV(_generator);
#endif

#else
			if (false) {
#endif
			} else
				DumpStarfish(_generator);
		} // if
	
		if (_bitmap != nil)
			[_bitmap release];
	} // if

	[super dealloc];
} // dealloc

// -----

- (BOOL) done
{
	BOOL	done = (!_generating);

	if (_childThreads != nil) {
		unsigned		i;
		for (i = 0; i < [_childThreads count] && done; i++)
			done = [[_childThreads objectAtIndex:i] done];
	} // if

	return done;
} // done

// -----

- (void) generateImage
{
    unsigned char	*buff;

    if (_generating)
        return;
    buff = [_bitmap bitmapData];

    if (buff == nil)
        return;
	buff += (_curLine * _maxCol * sizeof(long));

	if (_childThreads != nil)
		[self startChildThreads];

	_generating = YES;
	_stop = NO;

	while (_curLine < _maxLines && !_stop) {
#if BUILD_ALTIVEC
		if (_useAltivec) {
			int		endloop = _maxCol;
			int		extra = endloop % PIXELS_PER_CALL;
			endloop -= extra;
		
			while (_curCol < endloop && !_stop) {
				GetStarfishPixel_AV(_curCol, _curLine, _generator, (vector unsigned char*) buff);
				buff += PIXELS_PER_CALL * sizeof(long);
				_curCol += PIXELS_PER_CALL;
			} // while
	
			if (extra != 0) {
				vector unsigned char		temp[PIXELS_PER_CALL / 4];	// 4 pixels per vector
				GetStarfishPixel_AV(_curCol, _curLine, _generator, temp);
				memcpy(buff, temp, extra * sizeof(long));
				buff += extra * sizeof(long);
			} // if
#else
		if (false) {
#endif
		} else {
			while (_curCol < _maxCol && !_stop) {
				pixel	srlColor;
	
				GetStarfishPixel(_curCol, _curLine, _generator, &srlColor);
				*buff++ = srlColor.red;
				*buff++ = srlColor.green;
				*buff++ = srlColor.blue;
				*buff++ = 255;	// srlColor.alpha;
				_curCol++;
			} // while
		} // if/else

		_curCol = 0;
//		_curLine++;
		[gLineLock lock];	// Blocks until we get the lock
		_curLine = gNextLine++;
		[gLineLock unlock];
		buff = [_bitmap bitmapData] + (_curLine * _maxCol * sizeof(long));
	} // while

	_generating = NO;
	[NSThread exit];
} // generateImage

// -----

- (BOOL) imageComplete
{
	BOOL	complete = (_curLine >= _maxLines);

	if (_childThreads != nil) {
		unsigned		i;
		for (i = 0; i < [_childThreads count] && complete; i++)
			complete = [[_childThreads objectAtIndex:i] imageComplete];
	} // if

	return complete;
} // imageComplete

// -----

- (NSData*) imageData:(BOOL)compress
{
	NSData	*data;

	if (compress)
		data = [_bitmap TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1.0];
	else
		data = [_bitmap TIFFRepresentation];
	return data;
} // imageData

// -----

- (NSData*) imageDataAsJPEG:(float)quality
{
	NSDictionary	*prop = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:quality], NSImageCompressionFactor, nil];
	NSData	*jpegData = [_bitmap representationUsingType:NSJPEGFileType properties:prop];
	return jpegData;
} // imageDataAsJPEG

// -----

- (double) maxProgress
{
	return (double) ((_realMaxLines) * (_maxCol));
} // maxProgress

// -----

- (int) paletteIndex
{
	return _paletteIndex;
} // paletteIndex

// -----

- (NSSize) patternSize
{
	return NSMakeSize((float) _maxCol, (float) _maxLines);
} // patternSize

// -----

- (double) progress
{
	return (gNextLine * _maxCol);
} // progress

// -----

- (void) stopGenerating
{
	_stop = YES;
	if (_childThreads != nil)
		[self stopChildThreads];
} // stopGenerating

@end

// -----

@implementation StarfishGenerator (private)

- (id) initChildThread:(StarfishGenerator*)parent
						startingLine:(int)beginLine
						endingLine:(int)endLine
{
	[super init];

//	_mainThread = NO;
	_parentThread = parent;
	_generator    = parent->_generator;
	_bitmap       = parent->_bitmap;
	_useAltivec   = parent->_useAltivec;
	_realMaxLines = parent->_realMaxLines;

//	_generating = NO;
//	_stop = NO;
//	_childThreads = nil;
	_numThreads = 1;

//	_curCol   = 0;
	_maxCol   = parent->_maxCol;
	_curLine  = beginLine;
	_maxLines = endLine;

	return self;
} // initChildThread:startingLine:endingLine

// -----

- (BOOL) spawnThreads
{
	int		i;

	_childThreads = [[NSMutableArray alloc] init];
	for (i = 0; i < _numThreads - 1; i++) {	// The main thread counts as one thread
		StarfishGenerator	*thread = [[StarfishGenerator alloc] initChildThread:self startingLine:gNextLine++ endingLine:_realMaxLines];
		if (thread != nil)
			[_childThreads addObject:thread];
		else
			return NO;
	} // for

	return YES;
} // spawnThreads

// -----

- (void) startChildThreads
{
	unsigned		i;
	for (i = 0; i < [_childThreads count]; i++)
		[NSThread detachNewThreadSelector:@selector(generateImage) toTarget:[_childThreads objectAtIndex:i] withObject:nil];
} // startChildThreads

// -----

- (void) killChildThreads
{
	int		i;
	for (i = [_childThreads count] - 1; i >= 0; i--) {
		StarfishGenerator	*thread = [_childThreads objectAtIndex:i];
		[_childThreads removeObjectAtIndex:i];
		[thread release];
	} // for
} // killChildThreads

// -----

- (void) stopChildThreads
{
	unsigned		i;
	for (i = 0; i < [_childThreads count]; i++)
		[[_childThreads objectAtIndex:i] stopGenerating];
} // stopChildThreads

// -----

- (void) calculateStarfishPalette:(StarfishPalette*) it paletteIndex:(int)whichPalette paletteArray:(NSArray*)paletteList
{
	int		i, randCount = MAX_PALETTE_ENTRIES;

	_paletteIndex = whichPalette - paletteFirstDynamic;
	
	if (paletteList != nil && whichPalette == paletteRandom)
		_paletteIndex = irand([paletteList count] + 1) - 1;		// Allow for full-spectrum as a random palette
	else if (paletteList != nil && whichPalette == paletteRandomNoFullSpectrum)
		_paletteIndex = irand([paletteList count]);				// No full-spectrum allowed for this setting
	else
		irand(1);	// Just to keep the random numbers in sync if we're trying to generate the same thing with some different parameters

	if (paletteList == nil || [paletteList count] == 0 || whichPalette == paletteFullSpectrum || _paletteIndex < 0) {
		_paletteIndex = -1;
#ifdef BUILD_20
		// Generate a bunch of random colors
		it->colourcount = irand(MAX_PALETTE_ENTRIES / 4 - 2) + 2;	// Must have at least two colors
		randCount--;
		for (i = it->colourcount - 1; i >= 0; i--) {
			it->colour[i].red   = irand(256);
			it->colour[i].green = irand(256);
			it->colour[i].blue  = irand(256);
			randCount -= 3;
		} // for
#else
		it->colourcount = 0;
#endif
	} else {
		NSDictionary	*palDict;

		palDict = [paletteList objectAtIndex:_paletteIndex];
		if (palDict != nil) {
			NSArray	*theColors  = [palDict objectForKey:@"colors"];
			int		nEntries = [theColors count];
			if (nEntries > MAX_PALETTE_ENTRIES)
				nEntries = MAX_PALETTE_ENTRIES;
			it->colourcount = nEntries;
			for (i = 0; i < nEntries; i++) {
				NSArray	*color = [theColors objectAtIndex:i];
				it->colour[i].red   = [[color objectAtIndex:0] floatValue] * 255;
				it->colour[i].green = [[color objectAtIndex:1] floatValue] * 255;
				it->colour[i].blue  = [[color objectAtIndex:2] floatValue] * 255;
			} // for
		} else
			it->colourcount = 0;
	} // if/else

#ifdef BUILD_20
	// Consume the remaining random numbers
	for (; randCount > 0; randCount--)
		irand(1);
#endif
} // calculateStarfishPalette:

// -----

- (void) createRandomSize:(int)sizecode forScreen:(NSScreen*)theScreen customSize:(NSSize)custSize
{
	/*
	Based on the suggestion of the given size-code, make up a random
	size for the output pattern.
	We range from MIN_SIZE to the width/height of the main monitor.
	*/
	int		maxWidth, maxHeight, combine;
    NSRect	frame;

    frame = [theScreen frame];

    maxWidth  = (int) NSWidth(frame);
    maxHeight = (int) NSHeight(frame);

    switch (sizecode)
    {
    case sizeCodeCustom:
    	_maxCol   = (int) custSize.width;
    	_maxLines = (int) custSize.height;
		irand(1);	// Just to keep the random numbers in sync if we're trying to generate the same thing with some different parameters
		irand(1);	// Just to keep the random numbers in sync if we're trying to generate the same thing with some different parameters
    	break;
    case sizeCodeFullScreen:
        //This one's easy. Just use the monitor dimensions.
        _maxCol   = maxWidth;
        _maxLines = maxHeight;
		irand(1);	// Just to keep the random numbers in sync if we're trying to generate the same thing with some different parameters
		irand(1);	// Just to keep the random numbers in sync if we're trying to generate the same thing with some different parameters
        break;
    case sizeCodeLarge:
        //For large patterns, we average the width and height.
        //The output values range between 1/4 and 1/2 that value.
        //The value must be at least 256, regardless of monitor size.
        combine = (maxWidth + maxHeight) / 8;
        if (combine < LARGE_MIN)
            combine = LARGE_MIN;
        _maxCol   = irand(combine) + combine;
        _maxLines = irand(combine) + combine;
        break;
    case sizeCodeMedium:
        //Medium patterns are similar to large patterns.
        //The output values range between 1/8 and 1/4 screen average.
        combine = (maxWidth + maxHeight) / 16;
        if (combine < MED_MIN)
            combine = MED_MIN;
        _maxCol   = irand(combine) + combine;
        _maxLines = irand(combine) + combine;
        break;
    case sizeCodeSmall:
        //Small patterns range from SMALL_MIN to 1/16 of the monitor.
        combine  = (maxWidth + maxHeight) / 32;
        _maxCol   = irand(combine) + SMALL_MIN;
        _maxLines = irand(combine) + SMALL_MIN;
        break;
    default:
        //If we don't recognize it, make it small.
		NSLog(@"Unrecognized sizecode: %d", sizecode);
		_maxCol   = SMALL_MIN;
        _maxLines = SMALL_MIN;
		irand(1);	// Just to keep the random numbers in sync if we're trying to generate the same thing with some different parameters
		irand(1);	// Just to keep the random numbers in sync if we're trying to generate the same thing with some different parameters
        break;
    } // switch

#if BUILD_ALTIVEC
	// If we're using Altive, make sure _maxCol is an even multiple of PIXELS_PER_CALL
	if (_useAltivec) {
		_maxCol -= _maxCol % PIXELS_PER_CALL;
		if (_maxCol == 0)
			_maxCol = PIXELS_PER_CALL;
	} // if
#endif
} // createRandomSize:forScreen:

// -----

@end

