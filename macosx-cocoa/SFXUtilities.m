#import "SFXUtilities.h"


// -----

float frand(float range)
	{
	float denom, max;
	denom = (float) random();
	max = RAND_MAX;
	denom /= max;
	return range * denom;
	}

// -----

int irand(int range)
	{
#if 1
	return (int) frand((float) range);		// This handles the big numbers better
#else
	// When RAND_MAX = 2b (as it does for OS X), this function would always return 0
	return ((random() & 0x00007FFFL) * range) / 32768;
#endif
	}

// -----

NSImage* MakeThumbnailFromImage(NSImage *image, NSSize thumbSize, NSImage *badge)
{
	NSImage		*thumb = [image copy];
	NSSize		imageSize = [image size];

	if (imageSize.width > thumbSize.width || imageSize.height > thumbSize.height) {
		float               xMag, yMag, mag;

		xMag = thumbSize.width / imageSize.width;
		yMag = thumbSize.height / imageSize.height;

		mag = (xMag <= yMag ? xMag : yMag);

		imageSize.width *= mag;
		imageSize.height *= mag;

		[thumb setScalesWhenResized:YES];
		[thumb setSize:imageSize];
	} // if

	if (badge != nil) {
		NSImage		*scaledBadge = [badge copy];		// So we don't munge the original image
		NSImage		*badgedImage = [[NSImage alloc] initWithSize:thumbSize];
		NSSize		badgeSize = [badge size];
		NSPoint		pt;
		float			xScale, yScale;

		// When adding the badge, make the thumbnail the full size specified (because it's going into the dock, and the dock doesn't scale proportionally)
		[badgedImage lockFocus];
		pt.x = (int) (thumbSize.width - imageSize.width) / 2.0;
		pt.y = (int) (thumbSize.height - imageSize.height) / 2.0;
		[thumb compositeToPoint:pt operation:NSCompositeSourceOver];
		[thumb release];

		// Make the badge 1/3 the size of the thumbnail
		xScale = (thumbSize.width  / badgeSize.width)  / 3.0;
		yScale = (thumbSize.height / badgeSize.height) / 3.0;
		badgeSize.width  *= xScale;
		badgeSize.height *= yScale;
		pt.x = thumbSize.width - badgeSize.width;
		pt.y = 0.0;
		[scaledBadge setScalesWhenResized:YES];
		[scaledBadge setSize:badgeSize];

		[scaledBadge compositeToPoint:pt operation:NSCompositeSourceOver];
		[scaledBadge release];
		[badgedImage unlockFocus];

		thumb = badgedImage;
	} // if

	return thumb;
} // MakeThumbnailFromImage


@implementation NSDrawer (my_extensions)

- (BOOL) drawerIsOpen
{
	return ([self state] == NSDrawerOpenState);
} // drawerIsOpen:

// -----

- (BOOL) drawerIsOpenOrOpening
{
	NSDrawerState		state;

	state = [self state];
	return (state == NSDrawerOpenState || state == NSDrawerOpeningState);
} // drawerIsOpenOrOpening:

@end

