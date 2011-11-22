/*

Copyright ©1999-2003 Mars Saxman
All Rights Reserved

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

*/

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "starfish-engine.h"

#if BUILD_ALTIVEC
#include "starfish-altivec.h"

bool			gUseAltivec;

#ifndef TEST_ALTIVEC
	#define TEST_ALTIVEC 0
#endif
#if !TEST_ALTIVEC
	#define Value_AV	Value
#endif
#endif

#ifdef assert						// Mac OS X defines this
#undef assert
#endif

#define assert(cond) do { if (!(cond)) {printf("failed assertion: %s, %d", __FILE__, __LINE__ ); die_nicely();} } while (0) 


static void die_nicely(void)
	{
	// this is just here so I can set a breakpoint on it
	abort();
	}

static float rnd(void)
	{
	// this sucks. replace it.
	return (float) random() / (float) RAND_MAX;
	}

inline float min( float a, float b )
	{
	return a<b ? a : b;
	}

inline float max( float a, float b )
	{
	return a>b ? a : b;
	}

#ifndef __CARBON__
const double pi = 3.1415926535898;				// This is defined in OS X in fp.h
#endif
const double twopi = 6.2831853072;
const double halfpi = 1.5707963268;
const double halfpiRecip = 1.0 / halfpi;


#pragma mark -

#pragma mark class LinearWave
class LinearWave
	{
	public:
		virtual float Value( float d ) const = 0;
		virtual ~LinearWave() {}
#if BUILD_ALTIVEC
		virtual vector float Value_AV(vector float d) const
		{
			// This code allows the Altivec code to still function when we add new scalar generators
			// It simply calls the scalar code for each component of the vector
			// Once the altivec implementation is written, it will override this routine
			vector_accessor		in, out;
			in.vf = d;
			out.f[0] = Value(in.f[0]);
			out.f[1] = Value(in.f[1]);
			out.f[2] = Value(in.f[2]);
			out.f[3] = Value(in.f[3]);
			return out.vf;
		}
#endif
	};

#pragma mark class PlanarWave
class PlanarWave
	{
	public:
		virtual float Value( float x, float y ) const = 0;
		virtual ~PlanarWave() {}
#if BUILD_ALTIVEC
		virtual vector float Value_AV(vector float x, vector float y) const
		{
			// This code allows the Altivec code to still function when we add new scalar generators
			// It simply calls the scalar code for each component of the vector
			// Once the altivec implementation is written, it will override this routine
			vector_accessor		inX, inY, out;
			inX.vf = x;
			inY.vf = y;
			out.f[0] = Value(inX.f[0], inY.f[0]);
			out.f[1] = Value(inX.f[1], inY.f[1]);
			out.f[2] = Value(inX.f[2], inY.f[2]);
			out.f[3] = Value(inX.f[3], inY.f[3]);
			return out.vf;
		}
#endif
	};

#pragma mark -
#pragma mark class ImageLayer
class ImageLayer
	{
	public:
		virtual pixel Value( float x, float y ) const = 0;
		virtual ~ImageLayer() {}
#if BUILD_ALTIVEC
		virtual void Value_AV(vector float x, vector float y, vector signed int &outRed, vector signed int &outGreen, vector signed int &outBlue) const
		{
			// This code allows the Altivec code to still function when we add new scalar generators
			// It simply calls the scalar code for each component of the vector
			// Once the altivec implementation is written, it will override this routine
			vector_accessor		inX, inY;
			pixel				out[4];
			inX.vf = x;
			inY.vf = y;
			out[0] = Value(inX.f[0], inY.f[0]);
			out[1] = Value(inX.f[1], inY.f[1]);
			out[2] = Value(inX.f[2], inY.f[2]);
			out[3] = Value(inX.f[3], inY.f[3]);
			inX.sl[0] = out[0].red; inX.sl[1] = out[1].red; inX.sl[2] = out[2].red; inX.sl[3] = out[3].red;
			outRed = inX.vsl;
			inX.sl[0] = out[0].green; inX.sl[1] = out[1].green; inX.sl[2] = out[2].green; inX.sl[3] = out[3].green;
			outGreen = inX.vsl;
			inX.sl[0] = out[0].blue; inX.sl[1] = out[1].blue; inX.sl[2] = out[2].blue; inX.sl[3] = out[3].blue;
			outBlue = inX.vsl;
			return;
		}
#endif
	};

#pragma mark class Coswave
class Coswave : public LinearWave
	{
	public:
		Coswave()
			{
			// Phase is anywhere along one full rotation.
			mPhase = rnd() * pi;
			// Pick a reasonable period. We want this to be able
			// to use really large periods so we get some very
			// tightly packed waves, but there is more apparent
			// difference between the small values than the
			// large values so we need to bias the random value
			// toward the low end.
			mPeriod = pi / pow( rnd(), 0.5 );

#if BUILD_ALTIVEC
			if (gUseAltivec) Init_AV();
#endif
			}
//-----------------------------------------------------------------------------
		float Value( float d ) const
			{
			return cos( d * mPeriod + mPhase );
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		void Init_AV(void)
			{
			mPhaseV  = vSplatf(mPhase);
			mPeriodV = vSplatf(mPeriod);
			}
		vector float Value_AV(vector float d) const
			{
//			return cos( d * mPeriod + mPhase );
			return vCosf(vec_madd(d, mPeriodV, mPhaseV));
			}
#endif
//-----------------------------------------------------------------------------
	protected:
		float mPeriod;
		float mPhase;
#if BUILD_ALTIVEC
		vector float mPeriodV, mPhaseV;
#endif
	};

#pragma mark class Sawtooth
class Sawtooth : public LinearWave
	{
	public:
		Sawtooth()
			{
			// pick a random period. we will multiply the input
			// by this value.
			mPeriod = 1.0 / pow( rnd(), 0.5 );
			mPhase = rnd() * 2.0;
			// half the time, we invert the ramp, so we don't
			// accidentally favour one orientation over another.
			mFlipSign = 1.0;
			if( rnd() >= 0.5 ) mFlipSign = -mFlipSign;

#if BUILD_ALTIVEC
			if (gUseAltivec) Init_AV();
#endif
			}
//-----------------------------------------------------------------------------
		float Value( float d ) const
			{
			//Sawtooth wave: the input is the output,
			//truncated to the range -1..1.
			d = (d + mPhase) * mPeriod;
			d = d - floor( d );
			d = (d * 2.0) - 1.0;
			return d * mFlipSign; 
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		void Init_AV(void)
			{
				mFlipSignV = vSplatf(mFlipSign);
				mPeriodV   = vSplatf(mPeriod);
				mPhaseV    = vSplatf(mPhase);
			}
		vector float Value_AV(vector float d) const
			{
//			d = (d + mPhase) * mPeriod;
			d = vec_madd(mPeriodV, vec_add(d, mPhaseV), gZeroF);
//			d = d - floor( d );
			d = vec_sub(d, vec_floor(d));
//			d = (d * 2.0) - 1.0;
			d = vec_madd(d, gTwoF, gMinusOneF);
//			return d * mFlipSign; 
			return vec_madd(d, mFlipSignV, gZeroF);
			}
#endif
//-----------------------------------------------------------------------------
	protected:
		float mFlipSign;
		float mPeriod;
		float mPhase;
#if BUILD_ALTIVEC
		vector float mFlipSignV, mPeriodV, mPhaseV;
#endif
	};

#pragma mark class Ess
class Ess : public LinearWave
	{
	public:
		Ess()
			{
			// This is not a particularly interesting wave,
			// but it adds some subtle interest to other waves
			// and acts as a calming influence on the pattern
			// in general. It is aperiodic and fairly large.
			mAcceleration = rnd();
			if( rnd() >= 0.5 )
				{
				mAcceleration = 1.0 / (1.0 - mAcceleration);
				}
			mSignflip = 1.0;
			if( rnd() >= 0.5 ) mSignflip = -mSignflip;

#if BUILD_ALTIVEC
			if (gUseAltivec) Init_AV();
#endif
			}
//-----------------------------------------------------------------------------
		float Value(float d) const
			{
			return ((2.0/(mAcceleration*d*d+1.0))-1.0) * mSignflip;
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		void Init_AV(void)
			{
				mAccelerationV = vSplatf(mAcceleration);
				mSignflipV     = vSplatf(mSignflip);
			}
		vector float Value_AV(vector float d) const
			{
//			return ((2.0/(mAcceleration*d*d+1.0))-1.0) * mSignflip;
			d = vec_madd(mAccelerationV, vec_madd(d, d, gZeroF), gOneF);	// (mAcceleration*d*d+1.0)
			d = vec_sub(vDivf(gTwoF, d), gOneF);							// (2.0/d)-1.0
			return vec_madd(d, mSignflipV, gZeroF);							// d * mSignflip
			}
#endif
//-----------------------------------------------------------------------------
	protected: 
		float mAcceleration;
		float mSignflip;
#if BUILD_ALTIVEC
		vector float mAccelerationV, mSignflipV;
#endif
	};

#pragma mark class InvertWave
class InvertWave : public LinearWave
	{
	public:
		InvertWave(LinearWave* target)
			{
			mSource = target;
			}
		~InvertWave()
			{
			delete mSource;
			}
//-----------------------------------------------------------------------------
		float Value(float d) const
			{
			return -mSource->Value( d );
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		vector float Value_AV(vector float d) const
			{
//			return -mSource->Value( d );
			return vec_sub(gZeroF, mSource->Value(d));
			}
#endif
//-----------------------------------------------------------------------------
	protected: 
		LinearWave* mSource;
	};

#pragma mark class InsertWavePeaks
class InsertWavePeaks : public LinearWave
	{
	public:
		InsertWavePeaks(LinearWave* target)
			{
			mSource = target;
			mScale = (rnd() * rnd() * 8.0) + 1.0;
			mProcessSign = (rnd() >= 0.5);
#if BUILD_ALTIVEC
			if (gUseAltivec) Init_AV();
#endif
			}
		~InsertWavePeaks()
			{
			delete mSource;
			}
//-----------------------------------------------------------------------------
		float Value(float d) const
			{
			float skt;
			skt = mSource->Value( d );
			if( mProcessSign )
				{
				skt = (skt + 1.0) / 2.0;
				}
			skt = skt * mScale;
			if( skt < 0 )
				{
				skt = skt - ceil( skt );
				}
			else 
				{
				skt = skt - floor( skt );
				}
			if( mProcessSign )
				{
				skt = (skt * 2.0) - 1.0;
				}
			return skt;
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		void Init_AV(void)
			{
				mScaleV       = vSplatf(mScale);
				mProcessSignV = vSplatSelector(mProcessSign);
			}
		vector float Value_AV(vector float d) const
			{
			vector float skt;
			skt = mSource->Value( d );
//			if( mProcessSign )
//				skt = (skt + 1.0) / 2.0;
			skt = vec_sel(skt, vec_madd(vec_add(skt, gOneF), gOneHalf, gZeroF), mProcessSignV);
//			skt = skt * mScale;
			skt = vec_madd(skt, mScaleV, gZeroF);
//			if( skt < 0 )
//				skt = skt - ceil( skt );
//			else 
//				skt = skt - floor( skt );
			skt = vec_sub(skt, vec_sel(vec_floor(skt), vec_ceil(skt), vec_cmplt(skt, gZeroF)));
//			if( mProcessSign )
//				skt = (skt * 2.0) - 1.0;
			skt = vec_sel(skt, vec_madd(skt, gTwoF, gMinusOneF), mProcessSignV);
			return skt;
			}
#endif
//-----------------------------------------------------------------------------
	protected: 
		bool mProcessSign;
		float mScale;
		LinearWave* mSource;
#if BUILD_ALTIVEC
		vector unsigned int		mProcessSignV;
		vector float			mScaleV;
#endif
	};

#pragma mark class Modulator
class Modulator : public LinearWave
	{
	public:
		Modulator( LinearWave* target, LinearWave* wobbler )
			{
			mSource = target;
			mWobbler = wobbler;
			}
		~Modulator()
			{
			delete mSource;
			delete mWobbler;
			}
//-----------------------------------------------------------------------------
		float Value( float d ) const
			{
			return mSource->Value( d + mWobbler->Value( d ) );
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		vector float Value_AV(vector float d) const
			{
//			return mSource->Value( d + mWobbler->Value( d ) );
			return mSource->Value(vec_add(d, mWobbler->Value(d)));
			}
#endif
//-----------------------------------------------------------------------------
	protected: 
		LinearWave* mSource;
		LinearWave* mWobbler;
	};

#pragma mark class MixLinear
class MixLinear : public LinearWave
	{
	public:
		MixLinear( LinearWave* a, LinearWave* b )
			{
			mAWave = a;
			mBWave = b;
			mAFactor = rnd();
			mBFactor = rnd();
			mSumFactor = mAFactor + mBFactor;
#if BUILD_ALTIVEC
			if (gUseAltivec) Init_AV();
#endif
			}
		~MixLinear()
			{
			delete mAWave;
			delete mBWave;
			}
//-----------------------------------------------------------------------------
		float Value( float d ) const
			{
			return (mAWave->Value(d) * mAFactor + mBWave->Value(d) * mBFactor) / mSumFactor;
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		void Init_AV(void)
			{
				mAFactorV        = vSplatf(mAFactor);
				mBFactorV        = vSplatf(mBFactor);
				mSumFactorRecipV = vSplatf(1.0 / mSumFactor);	// Multiply by reciprocal--it's much faster for Altivec.
			}
		vector float Value_AV(vector float d) const
			{
//			return (mAWave->Value(d) * mAFactor + mBWave->Value(d) * mBFactor) / mSumFactor;
			return vec_madd(vec_madd(mAWave->Value(d), mAFactorV, vec_madd(mBWave->Value(d), mBFactorV, gZeroF)), mSumFactorRecipV, gZeroF);
			}
#endif
//-----------------------------------------------------------------------------
	protected: 
		float mAFactor;
		LinearWave* mAWave;
		float mBFactor;
		LinearWave* mBWave;
		float mSumFactor;
#if BUILD_ALTIVEC
		vector float mAFactorV, mBFactorV, mSumFactorRecipV;
#endif
	};

#pragma mark class MinimaxLinear
class MinimaxLinear : public LinearWave
	{
	public:
		MinimaxLinear( LinearWave* a, LinearWave* b )
			{
			mASrc = a;
			mBSrc = b;
			mMin = rnd() >= 0.5;
#if BUILD_ALTIVEC
			if (gUseAltivec) Init_AV();
#endif
			}
		~MinimaxLinear()
			{
			delete mASrc;
			delete mBSrc;
			}
//-----------------------------------------------------------------------------
		float Value( float d ) const
			{
			if( mMin )
				{
				return min( mASrc->Value( d ), mBSrc->Value( d ) );
				}
			else
				{
				return max( mASrc->Value( d ), mBSrc->Value( d ) );
				}
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		void Init_AV(void)
			{
				mMinV = vSplatSelector(mMin);
			}
		vector float Value_AV(vector float d) const
			{
//			if( mMin )
//				return min( mASrc->Value( d ), mBSrc->Value( d ) );
//			else
//				return max( mASrc->Value( d ), mBSrc->Value( d ) );
			vector	float	a = mASrc->Value(d);
			vector	float	b = mBSrc->Value(d);
			return vec_sel(vec_max(a, b), vec_min(a, b), mMinV);
			}
#endif
//-----------------------------------------------------------------------------
	protected: 
		LinearWave* mASrc;
		LinearWave* mBSrc;
		bool mMin;
#if BUILD_ALTIVEC
		vector unsigned int	mMinV;
#endif
	};

#pragma mark class MultiplyLinear
class MultiplyLinear : public LinearWave
	{
	public:
		MultiplyLinear( LinearWave* a, LinearWave* b )
			{
			mASrc = a;
			mBSrc = b;
			}
		~MultiplyLinear()
			{
			delete mASrc;
			delete mBSrc;
			}
//-----------------------------------------------------------------------------
		float Value( float d ) const
			{
			return mASrc->Value( d ) * mBSrc->Value( d );
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		vector float Value_AV(vector float d) const
			{
//			return mASrc->Value( d ) * mBSrc->Value( d );
			return vec_madd(mASrc->Value(d), mBSrc->Value(d), gZeroF);
			}
#endif
//-----------------------------------------------------------------------------
	protected:
		LinearWave* mASrc;
		LinearWave* mBSrc;
	};

#pragma mark class GammaLinear
class GammaLinear : public LinearWave
	{
	public:
		GammaLinear( LinearWave* target )
			{
   			mSource = target;
  			mExp = 1.0 / (rnd() * 2.0);
#if BUILD_ALTIVEC
			if (gUseAltivec) Init_AV();
#endif
			}
		~GammaLinear()
			{
			delete mSource;
			}
//-----------------------------------------------------------------------------
		float Value( float d ) const
			{
			float cpf;
			cpf = (mSource->Value( d ) + 1.0) / 2.0;
			cpf = pow( cpf, mExp );
			return cpf * 2.0 + - 1.0;
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		void Init_AV(void)
			{
				mExpV = vSplatf(mExp);
			}
		vector float Value_AV(vector float d ) const
			{
			vector float cpf;
//			cpf = (mSource->Value( d ) + 1.0) / 2.0;
			cpf = vec_madd(vec_add(mSource->Value(d), gOneF), gOneHalf, gZeroF);
//			cpf = pow( cpf, mExp );
			cpf = vPowf(cpf, mExpV);
//			return cpf * 2.0 + - 1.0;
			return vec_madd(cpf, gTwoF, gMinusOneF);
			}
#endif
//-----------------------------------------------------------------------------
	protected:
		float mExp;
		LinearWave* mSource;
#if BUILD_ALTIVEC
		vector float mExpV;
#endif
	};

#pragma mark class Pebbledrop
class Pebbledrop : public PlanarWave
	{
	public:
		Pebbledrop( LinearWave* target )
			{
			mSource = target;
			}
		~Pebbledrop()
			{
			delete mSource;
			}
//-----------------------------------------------------------------------------
		float Value( float x, float y ) const
			{
			// Compute the value for this point.
			// We take this point's distance from the origin,
			// then take its cosine.
			float hypotenuse;
			hypotenuse = sqrt(x*x + y*y);
			// Shift the phase by some predetermined amount
			// and multiply the distance by some value to change
			// the wave period.
			return mSource->Value( hypotenuse );
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		vector float Value_AV(vector float x, vector float y) const
			{
			vector float hypotenuse;
//			hypotenuse = sqrt(x*x + y*y);
			hypotenuse = vSqrtfX(vec_madd(x, x, vec_madd(y, y, gZeroF)));
			return mSource->Value( hypotenuse );
			}
#endif
//-----------------------------------------------------------------------------
	protected:
		LinearWave* mSource;
	};

#pragma mark class Curtain
class Curtain : public PlanarWave
	{
	public:
		Curtain( LinearWave* source )
			{
			mSource = source;
			}
		~Curtain()
			{
			delete mSource;
			}
//-----------------------------------------------------------------------------
		float Value( float x, float y ) const
			{
			return mSource->Value( x );
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		vector float Value_AV(vector float x, vector float y) const
			{
			return mSource->Value( x );
			}
#endif
//-----------------------------------------------------------------------------
	protected:
		LinearWave* mSource;
	};

#pragma mark class Zigzag
class Zigzag : public PlanarWave
	{
	public:
		Zigzag( LinearWave* source, LinearWave* oscillator)
			{
			mSource = source;
			mOscillator = oscillator;
			mAmplitude = rnd();
#if BUILD_ALTIVEC
			if (gUseAltivec) Init_AV();
#endif
			}
		~Zigzag()
			{
			delete mOscillator;
			delete mSource;
			}
//-----------------------------------------------------------------------------
		float Value( float x, float y ) const
			{
			return mSource->Value( x + mOscillator->Value( y ) * mAmplitude );
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		void Init_AV(void)
			{
			mAmplitudeV = vSplatf(mAmplitude);
			}
		vector float Value_AV(vector float x, vector float y) const
			{
//			return mSource->Value( x + mOscillator->Value( y ) * mAmplitude );
			return mSource->Value(vec_madd(mOscillator->Value(y), mAmplitudeV, x));
			}
#endif
//-----------------------------------------------------------------------------
	protected:
		float mAmplitude;
		LinearWave* mOscillator;
		LinearWave* mSource;
#if BUILD_ALTIVEC
		vector float mAmplitudeV;
#endif
	};

#pragma mark class Starfish
class Starfish : public PlanarWave
	{
	public:
		Starfish( LinearWave* source, LinearWave* oscillator )
			{
			mSource = source;
			mOscillator = oscillator;
			mAmplitude = rnd();
			mAttenuation = 1.0 / rnd();
			mSpinRate = rnd();
#if BUILD_ALTIVEC
			if (gUseAltivec) Init_AV();
#endif
			}
		~Starfish()
			{
			delete mOscillator;
			delete mSource;
			}
//-----------------------------------------------------------------------------
		float Value( float x, float y ) const
			{
			float hypotenuse;
			float angle;
			float amp;
			angle = atan2( y, x ) * mSpinRate;
			hypotenuse = sqrt(x*x + y*y);
			amp = mAmplitude * (1.0 - (1.0 / (mAttenuation * hypotenuse * hypotenuse + 1.0)));
			return mSource->Value( hypotenuse + mOscillator->Value( angle ) * amp );
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		void Init_AV(void)
			{
			mAmplitudeV   = vSplatf(mAmplitude);
			mAttenuationV = vSplatf(mAttenuation);
			mSpinRateV    = vSplatf(mSpinRate);
			}
		vector float Value_AV(vector float x, vector float y) const
			{
			vector float hypotenuse;
			vector float angle;
			vector float amp;
//			angle = atan2( y, x ) * mSpinRate;
			angle = vec_madd(vATan2f(y, x), mSpinRateV, gZeroF);
//			hypotenuse = sqrt(x*x + y*y);
			hypotenuse = vSqrtfX(vec_madd(x, x, vec_madd(y, y, gZeroF)));
//			amp = mAmplitude * (1.0 - (1.0 / (mAttenuation * hypotenuse * hypotenuse + 1.0)));
			amp = vec_madd(mAttenuationV, vec_madd(hypotenuse, hypotenuse, gZeroF), gOneF);		// (mAttenuation * hypotenuse * hypotenuse + 1.0)
			amp = vec_madd(mAmplitudeV, vec_sub(gOneF, vDivf(gOneF, amp)), gZeroF);
//			return mSource->Value( hypotenuse + mOscillator->Value( angle ) * amp );
			return mSource->Value(vec_madd(mOscillator->Value(angle), amp, hypotenuse));
			}
#endif
//-----------------------------------------------------------------------------
	protected: 
		float mAmplitude;
		float mAttenuation;
		LinearWave* mOscillator;
		LinearWave* mSource;
		float mSpinRate;
#if BUILD_ALTIVEC
		vector float mAmplitudeV, mAttenuationV, mSpinRateV;
#endif
	};

#pragma mark class Spinflake
class Spinflake : public PlanarWave
	{
	public:
		Spinflake( LinearWave* source )
			{
			mSource = source;
			// Radius determines where the flake's edge is.
			// 1.0 is a good normal value; it should shift some for
			// variety, but it shouldn't usually go too far away.
			mRadius = pow( rnd(), 3.0 );
			if( rnd() >= 0.5 ) mRadius = -mRadius;
			mRadius = mRadius + 1.0;
			// Amplitude determines the level of effect the oscillator has
			// on the radius. We generally want this to stay small, or the
			// pattern will get chaotic. 
			mAmplitude = pow( rnd(), 4.0 ) + 0.05;
			// "sharpness" determines the flatness of the central
			// plateau. We take the ratio of the distance to the
			// radius, and raise it to this power. Therefore, the
			// higher the power the more abrupt the curve.
			mSharpness = rnd() * 10.0;
			// To make this pattern less directional, we arbitrarily
			// sign-flip it half the time.
			mSignflip = (rnd() >= 0.5) ? 1.0 : -1.0;
#if BUILD_ALTIVEC
			if (gUseAltivec) Init_AV();
#endif
			}
		~Spinflake()
			{
			delete mSource;
			}
//-----------------------------------------------------------------------------
		float Value( float x, float y ) const
			{
			// first, get the distance from the origin.
			// we use two different functions to get the height,
			// depending on whether we are within the origin or
			// beyond it.
			float hypotenuse;
			float value;
			hypotenuse = sqrt(x*x + y*y);
			// next, get the angle. we pass this into our source
			// function to get the radius modulation.
			float angle;
			angle = atan2(y,x);
			// compute the wave value for this angle; add it
			// to the hypotenuse.
			hypotenuse = hypotenuse + mSource->Value( angle ) * mAmplitude;
			if( hypotenuse < 0 ) hypotenuse = 0;
			// ok: is this greater or less than the radius?
			// we have one function for each case. Both return
			// values in the 0..1 range, which we will have to
			// "correct" out to -1..1.
			if( hypotenuse > mRadius )
				{
				value = atan( hypotenuse - mRadius ) / halfpi;
				}
			else
				{
				value = 1.0 - pow( hypotenuse / mRadius, mSharpness );
				}
			return mSignflip * ((value * 2.0) - 1.0);
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		void Init_AV(void)
			{
			mAmplitudeV   = vSplatf(mAmplitude);
			mRadiusV      = vSplatf(mRadius);
			mRadiusRecipV = vSplatf(1.0 / mRadius);		// Used to multiple by reciprocal--much faster than division
			mSharpnessV   = vSplatf(mSharpness);
			mSignflipV    = vSplatf(mSignflip);
			}
		vector float Value_AV(vector float x, vector float y) const
			{
			vector float hypotenuse;
			vector float value;
//			hypotenuse = sqrt(x*x + y*y);
			hypotenuse = vSqrtfX(vec_madd(x, x, vec_madd(y, y, gZeroF)));

			vector float angle;
//			angle = atan2(y,x);
			angle = vATan2f(y,x);

//			hypotenuse = hypotenuse + mSource->Value( angle ) * mAmplitude;
			hypotenuse = vec_madd(mSource->Value(angle), mAmplitudeV, hypotenuse);
//			if( hypotenuse < 0 ) hypotenuse = 0;
			hypotenuse = vec_sel(hypotenuse, gZeroF, vec_cmplt(hypotenuse, gZeroF));

//			if( hypotenuse > mRadius )
//				value = atan( hypotenuse - mRadius ) / halfpi;
//			else
//				value = 1.0 - pow( hypotenuse / mRadius, mSharpness );
			value = vec_sel(vec_sub(gOneF, vPowf(vec_madd(hypotenuse, mRadiusRecipV,gZeroF), mSharpnessV)),	// 1.0 - pow( hypotenuse / mRadius, mSharpness )
							vec_madd(vATanf(vec_sub(hypotenuse, mRadiusV)), gHalfPiRecip, gZeroF),			// atan( hypotenuse - mRadius ) / halfpi
							vec_cmpgt(hypotenuse, mRadiusV));
//			return mSignflip * ((value * 2.0) - 1.0);
			return vec_madd(mSignflipV, vec_madd(value, gTwoF, gMinusOneF), gZeroF);
			}
#endif
//-----------------------------------------------------------------------------
	protected: 
		float mAmplitude;
		float mRadius;
		float mSharpness;
		float mSignflip;
		LinearWave* mSource;
#if BUILD_ALTIVEC
		vector float mAmplitudeV, mRadiusV, mRadiusRecipV, mSharpnessV, mSignflipV;
#endif
	};

#pragma mark class InvertPlane
class InvertPlane : public PlanarWave
	{
	public:
		InvertPlane( PlanarWave* source )
			{
			mSource = source;
			}
		~InvertPlane()
			{
			delete mSource;
			}
//-----------------------------------------------------------------------------
		float Value( float x, float y ) const
			{
			return -mSource->Value( x, y );
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		vector float Value_AV(vector float x, vector float y) const
			{
//			return -mSource->Value( x, y );
			return vec_sub(gZeroF, mSource->Value(x, y));
			}
#endif
//-----------------------------------------------------------------------------
	protected: 
		PlanarWave* mSource;
	};

#pragma mark class MinimaxPlanar
class MinimaxPlanar : public PlanarWave
	{
	public:
		MinimaxPlanar( PlanarWave* a, PlanarWave* b )
			{
			mASrc = a;
			mBSrc = b;
			mMin = rnd() >= 0.5;
#if BUILD_ALTIVEC
			if (gUseAltivec) Init_AV();
#endif
			}
		~MinimaxPlanar()
			{
			delete mASrc;
			delete mBSrc;
			}
//-----------------------------------------------------------------------------
		float Value( float x, float y ) const
			{
			if( mMin )
				{
				return min( mASrc->Value( x,y ), mBSrc->Value( x,y ) );
				}
			else 
				{
				return max( mASrc->Value( x,y ), mBSrc->Value( x,y ) );
				}
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		void Init_AV(void)
			{
			mMinV = vSplatSelector(mMin);
			}
		vector float Value_AV(vector float x, vector float y) const
			{
//			if( mMin )
//				return min( mASrc->Value( x,y ), mBSrc->Value( x,y ) );
//			else 
//				return max( mASrc->Value( x,y ), mBSrc->Value( x,y ) );
			vector float	a = mASrc->Value(x, y);
			vector float	b = mBSrc->Value(x, y);
			return vec_sel(vec_max(a, b), vec_min(a, b), mMinV);
			}
#endif
//-----------------------------------------------------------------------------
	protected: 
		PlanarWave* mASrc;
		PlanarWave* mBSrc;
		bool mMin;
#if BUILD_ALTIVEC
		vector unsigned int mMinV;
#endif
	};

#pragma mark class MixPlanar
class MixPlanar : public PlanarWave
	{
	public:
		MixPlanar( PlanarWave* a, PlanarWave* b )
			{
			mASrc = a;
			mBSrc = b;
			mABias = rnd();
			mBBias = 1.0 - mABias;
#if BUILD_ALTIVEC
			if (gUseAltivec) Init_AV();
#endif
			}
		~MixPlanar()
			{
			delete mASrc;
			delete mBSrc;
			}
//-----------------------------------------------------------------------------
		float Value(float x, float y) const
			{
			return mASrc->Value(x,y) * mABias + mBSrc->Value(x,y) * mBBias;
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		void Init_AV(void)
			{
			mABiasV = vSplatf(mABias);
			mBBiasV = vSplatf(mBBias);
			}
		vector float Value_AV(vector float x, vector float y) const
			{
//			return mASrc->Value(x,y) * mABias + mBSrc->Value(x,y) * mBBias;
			return vec_madd(mASrc->Value(x,y), mABiasV, vec_madd(mBSrc->Value(x,y), mBBiasV, gZeroF));
			}
#endif
//-----------------------------------------------------------------------------
	protected:
		float mABias;
		PlanarWave* mASrc;
		float mBBias;
		PlanarWave* mBSrc;
#if BUILD_ALTIVEC
		vector float mABiasV, mBBiasV;
#endif
	};

#pragma mark class WarpPlane
class WarpPlane : public PlanarWave
	{
	public:
		WarpPlane( PlanarWave* source, LinearWave* modulator )
			{
			mSource = source;
			mModulator = modulator;
//			mTheta = rnd() * twopi;
			rnd();		// Eat random number to get us back in sync with original engine
			mAmplitude = rnd();
			mAcceleration = rnd();
			mAttenuation = 1.0 / pow( rnd(), 2.0 );
#if BUILD_ALTIVEC
			if (gUseAltivec) Init_AV();
#endif
			}
		~WarpPlane()
			{
			delete mModulator;
			delete mSource;
			}
//-----------------------------------------------------------------------------
		float Value( float x, float y ) const
			{
			// Warp the coordinate space for the source function.
			// We take the angle and distance along some line from the
			// origin and supply that to our wave function. The wave
			// function's result is then added to the coordinates, at
			// right angles to the chosen axis.
			float amp;
			amp = mAmplitude / (mAttenuation * y * y + 1.0);
			y = y + mModulator->Value( x * mAcceleration ) * amp;
			return mSource->Value( x, y );
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		void Init_AV(void)
			{
			mAccelerationV = vSplatf(mAcceleration);
			mAmplitudeV    = vSplatf(mAmplitude);
			mAttenuationV  = vSplatf(mAttenuation);
			}
		vector float Value_AV(vector float x, vector float y) const
			{
			vector float amp;
//			amp = mAmplitude / (mAttenuation * y * y + 1.0);
			amp = vDivf(mAmplitudeV, vec_madd(mAttenuationV, vec_madd(y, y, gZeroF), gOneF));
//			y = y + mModulator->Value( x * mAcceleration ) * amp;
			y = vec_madd(mModulator->Value(vec_madd(x, mAccelerationV, gZeroF)), amp, y);
			return mSource->Value( x, y );
			}
#endif
//-----------------------------------------------------------------------------
	protected:
		float mAcceleration;
		float mAmplitude;
		float mAttenuation;
		LinearWave* mModulator;
		PlanarWave* mSource;
//		float mTheta;
#if BUILD_ALTIVEC
		vector float mAccelerationV, mAmplitudeV, mAttenuationV;
#endif
	};

#pragma mark class Reflector
class Reflector : public PlanarWave
	{
	public:
		Reflector( PlanarWave* source )
			{
			// introduces bilateral or quadrilateral symmetry.
			// symmetry is pretty. let's make some.
			mSource = source;
			mMode = (int) floor( rnd() * 3.0 );
#if BUILD_ALTIVEC
			if (gUseAltivec) Init_AV();
#endif
			}
		~Reflector()
			{
			delete mSource;
			}
//-----------------------------------------------------------------------------
		float Value( float x, float y ) const
			{
			// reflect this image around the y-axis.
			// this is easy: take the absolute value of x.
			// we trust the mixmaster to make this interesting.
			float ty;
			ty = y;
			switch( mMode )
				{
				case 0:
					{
					// bilateral symmetry
					} break;
				case 1:
					{
					// bilateral symmetry, halves reversed
					if( x < 0 ) ty = -y;
					} break;
				case 2:
					{
					// quadrilateral symmetry
					ty = abs( ty );
					} break;
				}
			return mSource->Value( abs( x ), ty );
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		void Init_AV(void)
			{
			mModeSel0 = vSplatSelector(mMode == 0);
			mModeSel2 = vSplatSelector(mMode == 2);
			}
		vector float Value_AV(vector float x, vector float y) const
			{
			vector float ty;
#if 0
			ty = y;
			switch( mMode ) {
				case 0:		// bilateral symmetry
					break;
				case 1:		// bilateral symmetry, halves reversed
//					if( x < 0 ) ty = -y;
					ty = vec_sel(y, vec_sub(gZeroF, y), vec_cmplt(x, gZeroF));
					break;
				case 2:		// quadrilateral symmetry
//					ty = abs( ty );
					ty = vec_abs(y);
					break;
				}
#else
			// This is faster than the switch statement version because it's only 6 instructions and doesn't introduce any pipeline bubbles
			// (How much faster, you ask? Well, it saves almost 10% in total generation time when generating pattern with seed 376450272)
			ty = vec_sel(y, vec_sub(gZeroF, y), vec_cmplt(x, gZeroF));	// Case 1, selects ty = (x < 0 > -y : y)
			ty = vec_sel(ty, y, mModeSel0);								// Case 0, selects ty = y
			ty = vec_sel(ty, vec_abs(y), mModeSel2);					// Case 2, selects ty = abs(y)
#endif
//			return mSource->Value( abs( x ), ty );
			return mSource->Value(vec_abs(x), ty);
			}
#endif
//-----------------------------------------------------------------------------
	protected: 
		int mMode;
		PlanarWave* mSource;
#if BUILD_ALTIVEC
		vector unsigned int		mModeSel0, mModeSel2;
#endif
	};

#pragma mark class GammaPlanar
class GammaPlanar : public PlanarWave
	{
	public:
		GammaPlanar( PlanarWave* source )
			{
			mSource = source;
			mExp = 1.0 / (rnd() * 2.0);
#if BUILD_ALTIVEC
			if (gUseAltivec) Init_AV();
#endif
			}
		~GammaPlanar()
			{
			delete mSource;
			}
//-----------------------------------------------------------------------------
		float Value( float x, float y ) const
			{
			float cpf;
			cpf = (mSource->Value( x, y ) + 1.0) / 2.0;
			cpf = pow( cpf, mExp );
			return cpf * 2.0 + - 1.0;
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		void Init_AV(void)
			{
			mExpV = vSplatf(mExp);
			}
		vector float Value_AV(vector float x, vector float y) const
			{
			vector float cpf;
//			cpf = (mSource->Value( x, y ) + 1.0) / 2.0;
			cpf = vec_madd(vec_add(mSource->Value(x, y), gOneF), gOneHalf, gZeroF);
//			cpf = pow( cpf, mExp );
			cpf = vPowf(cpf, mExpV);
//			return cpf * 2.0 + - 1.0;
			return vec_madd(cpf, gTwoF, gMinusOneF);
			}
#endif
//-----------------------------------------------------------------------------
	protected:
		float mExp;
		PlanarWave* mSource;
#if BUILD_ALTIVEC
		vector float mExpV;
#endif
	};

#pragma mark class MultiplyPlanar
class MultiplyPlanar : public PlanarWave
	{
	public:
		MultiplyPlanar( PlanarWave* a, PlanarWave* b )
			{
			mASrc = a;
			mBSrc = b;
			}
		~MultiplyPlanar()
			{
			delete mASrc;
			delete mBSrc;
			}
//-----------------------------------------------------------------------------
		float Value( float x, float y ) const
			{
			return mASrc->Value( x, y ) * mBSrc->Value( x, y );
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		vector float Value_AV(vector float x, vector float y) const
			{
//			return mASrc->Value( x, y ) * mBSrc->Value( x, y );
			return vec_madd(mASrc->Value(x, y), mBSrc->Value(x, y), gZeroF);
			}
#endif
//-----------------------------------------------------------------------------
	protected:
		PlanarWave* mASrc;
		PlanarWave* mBSrc;
	};

#pragma mark class Quadratesselator
class Quadratesselator : public PlanarWave
	{
	public:
		Quadratesselator( PlanarWave* source )
			{
			mSource = source;
			mHSize = (4.0 / rnd()) - 4.0;
			mVSize = (4.0 / rnd()) - 4.0;
#if BUILD_ALTIVEC
			if (gUseAltivec) Init_AV();
#endif
			}
		~Quadratesselator()
			{
			delete mSource;
			}
//-----------------------------------------------------------------------------
		float Value( float x, float y ) const
			{
			// shift from -1..1 coordinates into 0..1 coordinates
			x = (x + 1.0) / 2.0;
			y = (y + 1.0) / 2.0;
			// magnify the coordinates by the size on each axis
			x = x * mHSize;
			y = y * mVSize;
			// truncate, so the values return to 0..1 range
			x = x - floor( x );
			y = y - floor( y );
			// un-magnify
			x = x / mHSize;
			y = y / mVSize;
			// shrink the coordinates back to normal range
			x = (x * 2.0) - 1.0;
			y = (y * 2.0) - 1.0;
			// get the value from the source wave
			return mSource->Value( x, y);
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		void Init_AV(void)
			{
			mHSizeV      = vSplatf(mHSize);
			mHSizeRecipV = vSplatf(1.0 / mHSize);	// Used to multiple by reciprocal--much faster than division for altivec
			mVSizeV      = vSplatf(mVSize);
			mVSizeRecipV = vSplatf(1.0 / mVSize);	// Used to multiple by reciprocal--much faster than division for altivec
			}
		vector float Value_AV(vector float x, vector float y) const
			{
//			x = (x + 1.0) / 2.0;
			x = vec_madd(vec_add(x, gOneF), gOneHalf, gZeroF);
//			y = (y + 1.0) / 2.0;
			y = vec_madd(vec_add(y, gOneF), gOneHalf, gZeroF);
//			x = x * mHSize;
			x = vec_madd(x, mHSizeV, gZeroF);
//			y = y * mVSize;
			y = vec_madd(y, mVSizeV, gZeroF);
//			x = x - floor( x );
			x = vec_sub(x, vec_floor(x));
//			y = y - floor( y );
			y = vec_sub(y, vec_floor(y));
//			x = x / mHSize;
			x = vec_madd(x, mHSizeRecipV, gZeroF);
//			y = y / mVSize;
			y = vec_madd(y, mVSizeRecipV, gZeroF);
//			x = (x * 2.0) - 1.0;
			x = vec_madd(x, gTwoF, gMinusOneF);
//			y = (y * 2.0) - 1.0;
			y = vec_madd(y, gTwoF, gMinusOneF);
			return mSource->Value(x, y);
			}
#endif
//-----------------------------------------------------------------------------
	protected:
		float mHSize;
		float mVSize;
		PlanarWave* mSource;
#if BUILD_ALTIVEC
		vector float mHSizeV;
		vector float mHSizeRecipV;
		vector float mVSizeV;
		vector float mVSizeRecipV;
#endif
	};

#pragma mark class Hexatesselator

	const float cosThirdPi= 0.5;
	const float sinThirdPi = 0.866025;
	const float twiceSinThirdPi = 1.73205;
	const float tanThirdPi = 1.73205;

#if BUILD_ALTIVEC
	#define cosThirdPiV	gOneHalf			// Rather than another variable with the same value, (another memory access we'll just have to wait for)
	const vector float sinThirdPiV           = (vector float) (0.866025, 0.866025, 0.866025, 0.866025);
	const vector float twiceSinThirdPiV      = (vector float) (1.73205, 1.73205, 1.73205, 1.73205);
	const vector float twiceSinThirdPiRecipV = (vector float) (0.577350538379, 0.577350538379, 0.577350538379, 0.577350538379);
	#define tanThirdPiV			twiceSinThirdPiV		// Rather than another variable with the same value, (another memory access we'll just have to wait for)
	#define tanThirdPiRecipV	twiceSinThirdPiRecipV	// Rather than another variable with the same value, (another memory access we'll just have to wait for)
#endif

class Hexatesselator : public PlanarWave
	{
	public:
		Hexatesselator( PlanarWave* source )
			{
			mSource = source;
			mScale = 1.0 / pow( (rnd()*0.9)+0.1, 3.0 );
#if BUILD_ALTIVEC
			if (gUseAltivec) Init_AV();
#endif

			}
		~Hexatesselator()
			{
			delete mSource;
			}
//-----------------------------------------------------------------------------
		float Value( float x, float y ) const
			{
			x = x * mScale;
			y = y * mScale;
			// Tile the center of the source pattern as a hexagon. This is tiling on 
			// three axes, but we only have two coordinates, so we have to convert the
			// hexagon into a rectangle and tile that.
			// Wrap the coordinates within our tiling unit. This gives us values bounded
			// from -1 to 1 horizontally and -2 to 2 vertically. We can do this by shifting
			// into the 0..1 range and using the floor function, then shifting back.
			x = (x + sinThirdPi) / twiceSinThirdPi;
			x = x - floor( x );
			x = (x * twiceSinThirdPi) - sinThirdPi;
			y = (y + 2.0) / 3.0;
			y = y - floor( y );
			y = (y * 3.0) - 2.0;
			
			// There are four sectors in our tiling unit. Determine which one our point
			// lands in. Each sector has a different shift value which makes the origin
			// appear to line up in the same place on each row.
			float dx, dy;
			if( y - cosThirdPi > abs(x) / tanThirdPi )
				{
				dx = 0;
				dy = -2 + cosThirdPi;
				}
			else if( -y -cosThirdPi> abs(x) / tanThirdPi )
				{
				dx = 0;
				dy = 1.0 + cosThirdPi;
				}
			else if ( x < 0 )
				{
				dx = sinThirdPi;
				dy = 0;
				}
			else
				{
				dx = -sinThirdPi;
				dy = 0;
				}
			return mSource->Value( x + dx, y + dy );
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		void Init_AV(void)
			{
			mScaleV = vSplatf(mScale);
			}
		vector float Value_AV(vector float x, vector float y) const
			{
//			x = x * mScale;
			x = vec_madd(x, mScaleV, gZeroF);
//			y = y * mScale;
			y = vec_madd(y, mScaleV, gZeroF);


//			x = (x + sinThirdPi) / twiceSinThirdPi;
			x = vec_madd(vec_add(x, sinThirdPiV), twiceSinThirdPiRecipV, gZeroF);
//			x = x - floor( x );
			x = vec_sub(x, vec_floor(x));
//			x = (x * twiceSinThirdPi) - sinThirdPi;
			x = vec_madd(x, twiceSinThirdPiV, vec_sub(gZeroF, sinThirdPiV));
//			y = (y + 2.0) / 3.0;
			y = vec_madd(vec_add(y, gTwoF), gOneThird, gZeroF);
//			y = y - floor( y );
			y = vec_sub(y, vec_floor(y));
//			y = (y * 3.0) - 2.0;
			y = vec_madd(y, gThreeF, gMinusTwoF);

			vector float		dx, dy, absXDivTanThirdPi;
			vector bool int		sel1, sel2, sel3;
//			if( y - cosThirdPi > abs(x) / tanThirdPi ) {
//				dx = 0;
//				dy = -2 + cosThirdPi;
//			} else if( -y -cosThirdPi> abs(x) / tanThirdPi ) {
//				dx = 0;
//				dy = 1.0 + cosThirdPi;
//			} else if ( x < 0 ) {
//				dx = sinThirdPi;
//				dy = 0;
//			} else {
//				dx = -sinThirdPi;
//				dy = 0;
//			}
			absXDivTanThirdPi = vec_madd(vec_abs(x), tanThirdPiRecipV, gZeroF);				// abs(x) / tanThirdPi
			sel1 = vec_cmpgt(vec_sub(y, cosThirdPiV), absXDivTanThirdPi);					// y - cosThirdPi > abs(x) / tanThirdPi
			sel2 = vec_cmpgt(vec_sub(gZeroF, vec_add(y, cosThirdPiV)), absXDivTanThirdPi);	// -y -cosThirdPi> abs(x) / tanThirdPi 
			sel3 = vec_cmplt(x, gZeroF);
			dx = vec_sel(vec_sub(gZeroF, sinThirdPiV), sinThirdPiV, sel3);
			dx = vec_sel(dx, gZeroF, sel2);
			dx = vec_sel(dx, gZeroF, sel1);
			dy = vec_sel(gZeroF, vec_add(gOneF, cosThirdPiV), sel2);
			dy = vec_sel(dy, vec_add(gMinusTwoF, cosThirdPiV), sel1);
//			return mSource->Value( x + dx, y + dy );
			return mSource->Value(vec_add(x, dx), vec_add(y, dy));
			}
#endif
//-----------------------------------------------------------------------------
	protected:
		float mScale;
		PlanarWave* mSource;
#if BUILD_ALTIVEC
		vector float mScaleV;
#endif
	};

#pragma mark class Rotawarp
class Rotawarp : public PlanarWave
	{
	public:
		Rotawarp( PlanarWave* source, LinearWave* warp )
			{
			mSource = source;
			mWarp = warp;
			mAmplitude = rnd() * 2.0;
			if( mAmplitude > 1.0 )
				{
				mAmplitude = 1.0 / pow(mAmplitude - 1.0, 1.0);
				}
#if BUILD_ALTIVEC
			if (gUseAltivec) Init_AV();
#endif
			}
		~Rotawarp()
			{
			delete mSource;
			delete mWarp;
			}
//-----------------------------------------------------------------------------
		float Value( float x, float y ) const
			{
			// Convert this cartesian point into polar
			// coordinates. Get a value from our warping
			// function proportional to the distance from the
			// origin. Rotate the point by that much. Return
			// the value from our source function.
			float hyp, angle;
			angle = atan2( y, x );
			hyp = sqrt( x*x + y*y );
			angle = angle + mWarp->Value( hyp ) * mAmplitude;
			return mSource->Value( hyp * cos( angle ), hyp * sin( angle ) );
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		void Init_AV(void)
			{
			mAmplitudeV = vSplatf(mAmplitude);
			}
		vector float Value_AV(vector float x, vector float y) const
			{
			vector float hyp, angle;
//			angle = atan2( y, x );
			angle = vATan2f(y, x);
//			hyp = sqrt( x*x + y*y );
			hyp = vSqrtfX(vec_madd(x, x, vec_madd(y, y, gZeroF)));
//			angle = angle + mWarp->Value( hyp ) * mAmplitude;
			angle = vec_madd(mWarp->Value(hyp), mAmplitudeV, angle);
//			return mSource->Value( hyp * cos( angle ), hyp * sin( angle ) );
			return mSource->Value(vec_madd(hyp, vCosf(angle), gZeroF), vec_madd(hyp, vSinf(angle), gZeroF));
			}
#endif
//-----------------------------------------------------------------------------
	protected:
		float mAmplitude;
		PlanarWave* mSource;
		LinearWave* mWarp;
#if BUILD_ALTIVEC
		vector float mAmplitudeV;
#endif
	};

#pragma mark class Mixmaster
class Mixmaster : public PlanarWave
	{
	public:
		Mixmaster( PlanarWave* source )
			{
			mSource = source;
			// Rotate through an arbitrary angle.
			mAngle = rnd() * twopi;
			// Shift the origin somewhere else within the
			// working area.
			mXOff = rnd() * 2.0 - 1.0;
			mYOff = rnd() * 2.0 - 1.0;
			if( rnd() >= 0.5 )
				{
				mXFactor = rnd() + 0.1;
				mYFactor = 1.0 / mXFactor;
				}
			else
				{
				mYFactor = rnd() + 0.1;
				mXFactor = 1.0 / mYFactor;
				}
#if BUILD_ALTIVEC
			if (gUseAltivec) Init_AV();
#endif
			}
		~Mixmaster()
			{
			delete mSource;
			}
//-----------------------------------------------------------------------------
		float Value( float x, float y ) const
			{
			// Translate the origin.
			x = x + mXOff;
			y = y + mYOff;
			// Rotate these coordinates around the origin.
			float angle;
			float hypotenuse;
			angle = atan2( y, x ) + mAngle;
			hypotenuse = sqrt( x*x + y*y );
			x = cos( angle ) * hypotenuse;
			y = sin( angle ) * hypotenuse;
			// Squish the axes.
			x = x * mXFactor;
			y = y * mYFactor;
			// Find out what the source layer's value is at our
			// modified point.
			return mSource->Value( x, y );
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		void Init_AV(void)
			{
			mAngleV   = vSplatf(mAngle);
			mXFactorV = vSplatf(mXFactor);
			mXOffV    = vSplatf(mXOff);
			mYFactorV = vSplatf(mYFactor);
			mYOffV    = vSplatf(mYOff);
			}
		vector float Value_AV(vector float x, vector float y) const
			{
//			x = x + mXOff;
			x = vec_add(x, mXOffV);
//			y = y + mYOff;
			y = vec_add(y, mYOffV);

			vector float angle;
			vector float hypotenuse;
//			angle = atan2( y, x ) + mAngle;
			angle = vec_add(vATan2f(y, x), mAngleV);
//			hypotenuse = sqrt( x*x + y*y );
			hypotenuse = vSqrtfX(vec_madd(x, x, vec_madd(y, y, gZeroF)));
//			x = cos( angle ) * hypotenuse;
			x = vec_madd(vCosf(angle), hypotenuse, gZeroF);
//			y = sin( angle ) * hypotenuse;
			y = vec_madd(vSinf(angle), hypotenuse, gZeroF);

//			x = x * mXFactor;
			x = vec_madd(x, mXFactorV, gZeroF);
//			y = y * mYFactor;
			y = vec_madd(y, mYFactorV, gZeroF);

			return mSource->Value(x, y);
			}
#endif
//-----------------------------------------------------------------------------
	protected:
		float mAngle;
		PlanarWave* mSource;
		float mXFactor;
		float mXOff;
		float mYFactor;
		float mYOff;
#if BUILD_ALTIVEC
		vector float mAngleV;
		vector float mXFactorV;
		vector float mXOffV;
		vector float mYFactorV;
		vector float mYOffV;
#endif
	};

#pragma mark class Gradientor
class Gradientor : public ImageLayer
	{
	public:
		Gradientor( PlanarWave* source, const StarfishPalette* colours )
			{
			mSource = source;
			// Pick two different colours from the palette. These will be
			// the endpoints of our gradient.
			int aindex, bindex;
			aindex = (int) (rnd() * colours->colourcount);
			mAVal = colours->colour[ aindex ];
			do
				{
				bindex = (int) (rnd() * colours->colourcount);
				}
			while( bindex == aindex );
			mBVal = colours->colour[ bindex ];
#if BUILD_ALTIVEC
			if (gUseAltivec) Init_AV();
#endif
			}
		~Gradientor()
			{
			delete mSource;
			}
//-----------------------------------------------------------------------------
		pixel Value( float x, float y ) const
			{
			// Get the value from our source wave.
			// Use it as the proportion between the two colours
			// acting as our gradient endpoints.
			float val;
			val = (mSource->Value( x, y ) + 1.0) / 2.0;
			if( val < 0.0 || val > 1.0 )
				{
				pixel out = {0xFF, 0, 0, 0};
				return out;
				}
			pixel out;
			out.red   = (unsigned char) ((mBVal.red - mAVal.red) * val + mAVal.red);
			out.green = (unsigned char) ((mBVal.green - mAVal.green) * val + mAVal.green);
			out.blue  = (unsigned char) ((mBVal.blue - mAVal.blue) * val + mAVal.blue);
			return out;
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		void Init_AV(void)
			{
			mARedV   = vec_ctf(vSplati(mAVal.red), 0);
			mAGreenV = vec_ctf(vSplati(mAVal.green), 0);
			mABlueV  = vec_ctf(vSplati(mAVal.blue), 0);
			mBRedV   = vec_ctf(vSplati(mBVal.red), 0);
			mBGreenV = vec_ctf(vSplati(mBVal.green), 0);
			mBBlueV  = vec_ctf(vSplati(mBVal.blue), 0);
			}
		void Value_AV(vector float x, vector float y, vector signed int &outRed, vector signed int &outGreen, vector signed int &outBlue) const
			{
			vector float val;
//			val = (mSource->Value( x, y ) + 1.0) / 2.0;
			val = vec_madd(vec_add(mSource->Value(x, y), gOneF), gOneHalf, gZeroF);

//			out.red = (mBVal.red - mAVal.red) * val + mAVal.red;
//			out.green = (mBVal.green - mAVal.green) * val + mAVal.green;
//			out.blue = (mBVal.blue - mAVal.blue) * val + mAVal.blue;
			outRed   = vec_cts(vec_madd(vec_sub(mBRedV,   mARedV),   val, mARedV),   0);
			outGreen = vec_cts(vec_madd(vec_sub(mBGreenV, mAGreenV), val, mAGreenV), 0);
			outBlue  = vec_cts(vec_madd(vec_sub(mBBlueV,  mABlueV),  val, mABlueV),  0);

//			if( val < 0.0 || val > 1.0 ) {
//				out = {0xFF, 0, 0, 0};
//				return out; }
			vector bool int		sel = vec_or(vec_cmplt(val, gZeroF), vec_cmpgt(val, gOneF));
			outRed   = vec_sel(outRed,   gZero, sel);
			outGreen = vec_sel(outGreen, gZero, sel);
			outBlue  = vec_sel(outBlue,  gZero, sel);
//			return out;
			}
#endif
//-----------------------------------------------------------------------------
		protected:
			pixel mAVal;
			pixel mBVal;
			PlanarWave* mSource;
#if BUILD_ALTIVEC
			vector float		mARedV, mAGreenV, mABlueV;
			vector float		mBRedV, mBGreenV, mBBlueV;
#endif
	};

#pragma mark class Compositor
class Compositor : public ImageLayer
	{
	public:
		Compositor( ImageLayer* a, PlanarWave* mask, ImageLayer* b )
			{
			mSrcA = a;
			mMask = mask;
			mSrcB = b;
			}
		~Compositor()
			{
			delete mSrcA;
			delete mSrcB;
			delete mMask;
			}
//-----------------------------------------------------------------------------
		pixel Value( float x, float y ) const
			{
			pixel a = mSrcA->Value( x, y );
			pixel b = mSrcB->Value( x, y );
			float mask = mMask->Value( x, y );
			mask = (mask + 1.0) / 2.0;
			pixel out;
			out.red   = (unsigned char) ((b.red - a.red) * mask + a.red);
			out.green = (unsigned char) ((b.green - a.green) * mask + a.green);
			out.blue  = (unsigned char) ((b.blue - a.blue) * mask + a.blue);
			return out;
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		void Value_AV(vector float x, vector float y, vector signed int &outRed, vector signed int &outGreen, vector signed int &outBlue) const
			{
//			pixel a = mSrcA->Value(x, y);
//			pixel b = mSrcB->Value(x, y);
			vector signed int	aRed, aGreen, aBlue;
			vector signed int	bRed, bGreen, bBlue;
			mSrcA->Value(x, y, aRed, aGreen, aBlue);
			mSrcB->Value(x, y, bRed, bGreen, bBlue);

			vector float mask = mMask->Value(x, y);
//			mask = (mask + 1.0) / 2.0;
			mask = vec_madd(vec_add(mask, gOneF), gOneHalf, gZeroF);

//			pixel out;
//			out.red = (b.red - a.red) * mask + a.red;
//			out.green = (b.green - a.green) * mask + a.green;
//			out.blue = (b.blue - a.blue) * mask + a.blue;
			outRed   = vec_cts(vec_madd(vec_ctf(vec_sub(bRed,   aRed),   0), mask, vec_ctf(aRed,   0)), 0);
			outGreen = vec_cts(vec_madd(vec_ctf(vec_sub(bGreen, aGreen), 0), mask, vec_ctf(aGreen, 0)), 0);
			outBlue  = vec_cts(vec_madd(vec_ctf(vec_sub(bBlue,  aBlue),  0), mask, vec_ctf(aBlue,  0)), 0);
//			return out;
			}
#endif
//-----------------------------------------------------------------------------
	protected:
		ImageLayer* mSrcA;
		ImageLayer* mSrcB;
		PlanarWave* mMask;
	};

#pragma mark class AntialiasImage
class AntialiasImage : public ImageLayer
	{
	public:
		AntialiasImage( ImageLayer* source, float dx, float dy )
			{
			mSource = source;
			mDX = dx;
			mDY = dy;
#if BUILD_ALTIVEC
			if (gUseAltivec) Init_AV();
#endif
			}
		~AntialiasImage()
			{
			delete mSource;
			}
//-----------------------------------------------------------------------------
		pixel Value( float x, float y ) const
			{
			// sample four values from the source image.
			// divide by four. voila.
			int red, green, blue;
			// top left
			pixel oval = mSource->Value( x, y );
			red = oval.red;
			green = oval.green;
			blue = oval.blue;
			// top right
			oval = mSource->Value( x + mDX, y );
			red = red + oval.red;
			green = green + oval.green;
			blue = blue + oval.blue;
			// bottom right
			oval = mSource->Value( x + mDX, y + mDY );
			red = red + oval.red;
			green = green + oval.green;
			blue = blue + oval.blue;
			// bottom left
			oval = mSource->Value( x, y + mDY );
			red = red + oval.red;
			green = green + oval.green;
			blue = blue + oval.blue;
			// sum it all up and return it
			oval.red = red/4;
			oval.green = green/4;
			oval.blue = blue/4;
			return oval;
			}
//-----------------------------------------------------------------------------
#if BUILD_ALTIVEC
		void Init_AV(void)
			{
			mDXV = vSplatf(mDX);
			mDYV = vSplatf(mDY);
			}
		void Value_AV(vector float x, vector float y, vector signed int &outRed, vector signed int &outGreen, vector signed int &outBlue) const
			{
			vector signed int	red, green, blue;
			vector float		x2 = vec_add(x, mDXV);
			vector float		y2 = vec_add(y, mDYV);

//			pixel oval = mSource->Value( x, y );
//			red = oval.red;
//			green = oval.green;
//			blue = oval.blue;
			mSource->Value(x, y, outRed, outGreen, outBlue);
			red   = outRed;
			green = outGreen;
			blue  = outBlue;

//			oval = mSource->Value( x + mDX, y );
//			red = red + oval.red;
//			green = green + oval.green;
//			blue = blue + oval.blue;
			mSource->Value(x2, y, outRed, outGreen, outBlue);
			red   = vec_add(red,   outRed);
			green = vec_add(green, outGreen);
			blue  = vec_add(blue,  outBlue);

//			oval = mSource->Value( x + mDX, y + mDY );
//			red = red + oval.red;
//			green = green + oval.green;
//			blue = blue + oval.blue;
			mSource->Value(x2, y2, outRed, outGreen, outBlue);
			red   = vec_add(red,   outRed);
			green = vec_add(green, outGreen);
			blue  = vec_add(blue,  outBlue);

//			oval = mSource->Value( x, y + mDY );
//			red = red + oval.red;
//			green = green + oval.green;
//			blue = blue + oval.blue;
			mSource->Value(x, y2, outRed, outGreen, outBlue);
			red   = vec_add(red,   outRed);
			green = vec_add(green, outGreen);
			blue  = vec_add(blue,  outBlue);

//			oval.red = red/4;
//			oval.green = green/4;
//			oval.blue = blue/4;
			outRed   = vec_sra(red,   gTwo);
			outGreen = vec_sra(green, gTwo);
			outBlue  = vec_sra(blue,  gTwo);
//			return oval;

			}
#endif
//-----------------------------------------------------------------------------
	protected:
		float mDX;
		float mDY;
		ImageLayer* mSource;
#if BUILD_ALTIVEC
		vector float mDXV;
		vector float mDYV;
#endif
	};

#pragma mark -

static LinearWave* NewLinearWave( unsigned int complexity = 10 )
	{
	LinearWave* out;
	int selector;
	// Start with one of our root waves.
	selector = (int) floor( rnd() * 3.0 );
	switch( selector )
		{
		case 0: out = new Coswave; break;
		case 1: out = new Sawtooth; break;
		case 2: out = new Ess; break;
		default: assert(0);
		}
	// Encrust our simple wave with a random assortment of
	// modifier waves. Each of these accepts another wave as 
	// input and modify its output according to some random
	// parameters.
	while( complexity > 0 )
		{
		selector = (int) floor( rnd() * 8.0 );
		switch( selector )
		{
		case 0: 
			{
			// eat one complexity level.
			// this just helps keep things from getting
			// out of control.
			complexity--;
			} break;
		case 1: 
			{
			out = new InvertWave( out );
			complexity--;
			} break;
		case 2: 
			{
			out = new GammaLinear( out );
			complexity--;
			} break;
		case 3: 
			{
			if( complexity >= 2 ) 
				{
				out = new InsertWavePeaks( out );
				complexity -= 2;
				}
			} break;
		case 4: 
			{
			out = new Modulator( out, NewLinearWave( complexity ) );
			complexity = 0;
			} break;
		case 5: 
			{
			out = new MixLinear( out, NewLinearWave( complexity ) );
			complexity = 0;
			} break;
		case 6: 
			{
			out = new MinimaxLinear( out, NewLinearWave( complexity ) );
			complexity = 0;
			} break;
		case 7: 
			{
			out = new MultiplyLinear( out, NewLinearWave( complexity ) );
			complexity = 0;
			} break;
		}
		}
	return out;
	}

static PlanarWave* NewPlanarWave( unsigned int complexity = 20 )
	{
	PlanarWave* out = NULL;
	int selector;
	// We've been given a certain number of complexity points. Determine
	// how we are going to spend them. We divide them up between the source
	// wave (composed of one or more linear waves) and the modifier waves
	// (which stack on top of our source wave).
	int modifierComplexity = (int) (rnd() * complexity);
	int sourceComplexity = complexity - modifierComplexity;
	int subwaveComplexity = 0;
	// Pick a root planar wave algorithm. 
	selector = (int) floor( rnd() * 5.0 );
	switch( selector )
		{
		case 0: out = new Pebbledrop( NewLinearWave( sourceComplexity ) ); break;
		case 1: out = new Curtain( NewLinearWave( sourceComplexity ) ); break;
		case 2: out = new Zigzag( NewLinearWave( sourceComplexity / 2 ), NewLinearWave( sourceComplexity / 2 ) ); break;
		case 3: out = new Starfish( NewLinearWave( sourceComplexity / 2 ), NewLinearWave( sourceComplexity / 2) ); break;
		case 4: out = new Spinflake( NewLinearWave( sourceComplexity ) ); break;
		}
	// Half the time, flip the wave over. This prevents us from being biased
	// toward either positive or negative values.
	if( rnd() >= 0.5 )
		{
		out = new InvertPlane( out );
		}
	// Modify the wave we've just created. Keep modifying it until we run out
	// of complexity points.
	while( modifierComplexity > 0 )
		{
			selector = (int) floor( rnd() * 10.0 );
			switch( selector ) 
			{
			case 0:
				{
				// Burn one complexity point. This helps keep the image from getting
				// too crazy.
				modifierComplexity = modifierComplexity - 1;
				} break;
			case 1:
				{
				// Mix this wave with another one using a min/max algorithm.
				out = new MinimaxPlanar( out, NewPlanarWave( modifierComplexity ) );
				modifierComplexity = 0;
				} break;
			case 2:
				{
				// Mix this wave with another one using weighted averages.
				out = new MixPlanar( out, NewPlanarWave( modifierComplexity ) );
				modifierComplexity = 0;
				} break;
			case 3:
				{
				// Warp the plane's coordinates using a linear wave.
				// This is a simple implementation along the X-axis, so we must
				// add a mixmaster first.
				modifierComplexity = modifierComplexity / 2;
				out = new WarpPlane( new Mixmaster( out ), NewLinearWave( modifierComplexity ) );
				if( modifierComplexity > 0 )
					{
					modifierComplexity = modifierComplexity - 1;
					}
				} break;
			case 4:
				{
				// Reflect the image around itself. This does not rotate, so we must
				// add a mixmaster.
				modifierComplexity = modifierComplexity / 2;
				out = new Reflector( new Mixmaster( out ) );
				} break;
			case 5:
				{
				// Adjust the image's gamma.
				modifierComplexity = modifierComplexity - 1;
				out = new GammaPlanar( out );
				} break;
			case 6: {
				// Use one wave to limit another by multiplying them.
				out = new MultiplyPlanar( out, NewPlanarWave( modifierComplexity ) );
				modifierComplexity = 0;
				} break;
			case 7:
				{
				// Tile the image using a rectangle.
				out = new Quadratesselator( out );
				modifierComplexity = modifierComplexity / 2;
				} break;
			case 8:
				{
				// Tile the image using a hexagon.
				out = new Hexatesselator( out );
				modifierComplexity = modifierComplexity / 2;
				} break;
			case 9:
				{
				// Warp the image around a point.
				subwaveComplexity = (int) (modifierComplexity * rnd());
				out = new Rotawarp( new Mixmaster( out ), NewLinearWave( subwaveComplexity ) );
				modifierComplexity = modifierComplexity - subwaveComplexity;
				} break;
			}
		}
	// We always give away one mixmaster layer for free.
	// This rotates, translates, and axis-adjusts the
	// target layer: a standard package of transformations
	// so that the output doesn't look like it's sitting
	// on a cartesian grid in the middle of the display.
	out = new Mixmaster( out );
	return out;
	}

static ImageLayer* NewImageLayer( const StarfishPalette* colours, unsigned int complexity = 50 )
	{
	// We have two choices:
	// Create a gradient based on a planar wave.
	// Or, composite two other image layers.
	// The more complexity available, the more likely it is we will create a composite
	// layer instead of a single layer. This recurses, of course, so we can have
	// composition layered arbitrarily deep.
	if(pow( rnd(), 4.0 ) > 1.0 / complexity )
		{
		PlanarWave* mask = NewPlanarWave( complexity / 4 );
		complexity -= (complexity / 4);
		ImageLayer* a = NewImageLayer( colours, complexity / 2 );
		ImageLayer* b = NewImageLayer( colours, complexity / 2 );
		return new Compositor( a, mask, b );
		}
	else
		{
		return new Gradientor( NewPlanarWave( complexity ), colours );
		}
	}

#pragma mark -

#pragma mark struct StarfishGeneratorRec
struct StarfishGeneratorRec
	{
	StarfishGeneratorRec( int width, int height, const StarfishPalette* palette, bool wrapEdges );
	void Pixel( int x, int y, pixel* out );
#if BUILD_ALTIVEC
	void Init_AV(void);
	void Pixel(int x, int y, vector unsigned char *pixels);
#endif
	~StarfishGeneratorRec();

	int mWidth, mHeight;
	ImageLayer* mSource;
	bool mWrapEdges;
#if BUILD_ALTIVEC
	vector float	mWidthRecipV, mHeightRecipV;
#endif
	};

StarfishGeneratorRec::StarfishGeneratorRec( int width, int height, const StarfishPalette* palette, bool wrapEdges )
	{
	mWidth = width;
	mHeight = height;
	mWrapEdges = wrapEdges;
	int complexity = 75;
	if( mWrapEdges )
		{
		complexity /= 2;
		}
#if BUILD_ALTIVEC
			if (gUseAltivec) Init_AV();
#endif
	mSource = NewImageLayer( palette, complexity );
	mSource = new AntialiasImage( mSource, 0.5/width, 0.5/height );
	}


#if BUILD_ALTIVEC
void StarfishGeneratorRec::Init_AV(void)
	{
	mWidthRecipV  = vSplatf(1.0 / mWidth);		// Multiple by reciprocal instead of dividing--much faster for altivec
	mHeightRecipV = vSplatf(1.0 / mHeight);
	}
#endif


void StarfishGeneratorRec::Pixel( int x, int y, pixel* out )
	{
	/*
	Convert the pixel-based coordinates into the -1..1 range expected by our image
	layer. Pass in the new coordinates and return the resulting colour value.
	*/
	float fx, fy;
	fx = (x * 2.0) / mWidth - 1.0;
	fy = (y * 2.0) / mHeight - 1.0;
	if( mWrapEdges )
		{
		float xbackmask = (x*1.0) / (mWidth*1.0);
		float xmask = 1.0 - xbackmask;
		pixel topleft = mSource->Value( fx + 1.0, fy );
		pixel topright = mSource->Value( fx - 1.0, fy );
		pixel top;
		top.red   = (unsigned char) ((topleft.red * xmask) + (topright.red * xbackmask));
		top.green = (unsigned char) ((topleft.green * xmask) + (topright.green * xbackmask));
		top.blue  = (unsigned char) ((topleft.blue * xmask) + (topright.blue * xbackmask));
		pixel bottomleft = mSource->Value( fx + 1.0, fy - 2.0 );
		pixel bottomright = mSource->Value( fx - 1.0, fy - 2.0 );
		pixel bottom;
		bottom.red   = (unsigned char) ((bottomleft.red * xmask) + (bottomright.red * xbackmask));
		bottom.green = (unsigned char) ((bottomleft.green * xmask) + (bottomright.green * xbackmask));
		bottom.blue  = (unsigned char) ((bottomleft.blue * xmask) + (bottomright.blue * xbackmask));
		float ybackmask = (y*1.0) / (mHeight*1.0);
		float ymask = 1.0 - ybackmask;
		out->red   = (unsigned char) ((top.red * ymask) + (bottom.red * ybackmask));
		out->green = (unsigned char) ((top.green * ymask) + (bottom.green * ybackmask));
		out->blue  = (unsigned char) ((top.blue * ymask) + (bottom.blue * ybackmask));
		}
	else
		{
		*out = mSource->Value( fx, fy );
		}
	}


#if BUILD_ALTIVEC
void StarfishGeneratorRec::Pixel(int x, int y, vector unsigned char *pixels)
{
	vector float		vy = vec_ctf(vSplati(y), 0);
	vector float		vx = vec_ctf(vec_add(vSplati(x), gZeroOneTwoThree), 0);
	vector float		fx, fy;
//	fx = (x * 2.0) / mWidth - 1.0;
	fx = vec_sub(vec_madd(vec_madd(vx, gTwoF, gZeroF), mWidthRecipV, gZeroF), gOneF);
//	fy = (y * 2.0) / mHeight - 1.0;
	fy = vec_sub(vec_madd(vec_madd(vy, gTwoF, gZeroF), mHeightRecipV, gZeroF), gOneF);

	vector signed int	red, green, blue;
	if(mWrapEdges) {
//		float xbackmask = (x*1.0) / (mWidth*1.0);
		vector float backmask = vec_madd(vx, mWidthRecipV, gZeroF);
//		float xmask = 1.0 - xbackmask;
		vector float mask = vec_sub(gOneF, backmask);

//		pixel topleft = mSource->Value( fx + 1.0, fy );
		vector signed int	oRed, oGreen, oBlue;
		mSource->Value(vec_add(fx, gOneF), fy, oRed, oGreen, oBlue);
//		pixel topright = mSource->Value( fx - 1.0, fy );
		vector signed int	oRed2, oGreen2, oBlue2;
		mSource->Value(vec_sub(fx, gOneF), fy, oRed2, oGreen2, oBlue2);

//		pixel top;
//		top.red = (topleft.red * xmask) + (topright.red * xbackmask);
//		top.green = (topleft.green * xmask) + (topright.green * xbackmask);
//		top.blue = (topleft.blue * xmask) + (topright.blue * xbackmask);
		red   = vec_cts(vec_madd(vec_ctf(oRed, 0),   mask, vec_madd(vec_ctf(oRed2, 0),   backmask, gZeroF)), 0);
		green = vec_cts(vec_madd(vec_ctf(oGreen, 0), mask, vec_madd(vec_ctf(oGreen2, 0), backmask, gZeroF)), 0);
		blue  = vec_cts(vec_madd(vec_ctf(oBlue, 0),  mask, vec_madd(vec_ctf(oBlue2, 0),  backmask, gZeroF)), 0);

//		pixel bottomleft = mSource->Value( fx + 1.0, fy - 2.0 );
		mSource->Value(vec_add(fx, gOneF), vec_sub(fy, gTwoF), oRed, oGreen, oBlue);
//		pixel bottomright = mSource->Value( fx - 1.0, fy - 2.0 );
		mSource->Value(vec_sub(fx, gOneF), vec_sub(fy, gTwoF), oRed2, oGreen2, oBlue2);
//		pixel bottom;
		vector signed int	red2, green2, blue2;
//		bottom.red = (bottomleft.red * xmask) + (bottomright.red * xbackmask);
//		bottom.green = (bottomleft.green * xmask) + (bottomright.green * xbackmask);
//		bottom.blue = (bottomleft.blue * xmask) + (bottomright.blue * xbackmask);
		red2   = vec_cts(vec_madd(vec_ctf(oRed, 0),   mask, vec_madd(vec_ctf(oRed2, 0),   backmask, gZeroF)), 0);
		green2 = vec_cts(vec_madd(vec_ctf(oGreen, 0), mask, vec_madd(vec_ctf(oGreen2, 0), backmask, gZeroF)), 0);
		blue2  = vec_cts(vec_madd(vec_ctf(oBlue, 0),  mask, vec_madd(vec_ctf(oBlue2, 0),  backmask, gZeroF)), 0);

//		float ybackmask = (y*1.0) / (mHeight*1.0);
		backmask = vec_madd(vy, mHeightRecipV, gZeroF);
//		float ymask = 1.0 - ybackmask;
		mask = vec_sub(gOneF, backmask);
//		out->red = (top.red * ymask) + (bottom.red * ybackmask);
//		out->green = (top.green * ymask) + (bottom.green * ybackmask);
//		out->blue = (top.blue * ymask) + (bottom.blue * ybackmask);
		red   = vec_cts(vec_madd(vec_ctf(red, 0),   mask, vec_madd(vec_ctf(red2, 0),   backmask, gZeroF)), 0);
		green = vec_cts(vec_madd(vec_ctf(green, 0), mask, vec_madd(vec_ctf(green2, 0), backmask, gZeroF)), 0);
		blue  = vec_cts(vec_madd(vec_ctf(blue, 0),  mask, vec_madd(vec_ctf(blue2, 0),  backmask, gZeroF)), 0);
	} else
		mSource->Value(fx, fy, red, green, blue);	//		*out = mSource->Value(fx, fy);

	// Convert the components into pixels
	vector unsigned char	outval;

	// For OS X, alpha is important and needs to be 255 otherwise our patterns get pretty funky
	outval = vec_perm((vector unsigned char) vSplati(255), (vector unsigned char) red, gExtractAlphaAndRed);

	// Pull the green pixels out into the output vector
	outval = vec_perm(outval, (vector unsigned char) green, gExtractGreen);

	// Pull the blue pixels out into the output vector
	*pixels = vec_perm(outval, (vector unsigned char) blue, gExtractBlue);
} // Pixel
#endif


StarfishGeneratorRec::~StarfishGeneratorRec()
	{
	delete mSource;
	}

#if BUILD_ALTIVEC
StarfishRef MakeStarfish( int width, int height, const StarfishPalette* palette, bool wrapEdges, bool useAltivec )
#else
StarfishRef MakeStarfish( int width, int height, const StarfishPalette* palette, bool wrapEdges )
#endif
	{
	StarfishPalette dummy;
#if BUILD_ALTIVEC
	gUseAltivec = useAltivec;
#endif
	if( !palette )
		{
		palette = &dummy;
		dummy.colourcount = 4;
		pixel black = {0,0,0,0};
		dummy.colour[0] = black;
		pixel white = {255,255,255,255};
		dummy.colour[1] = white;
		dummy.colour[2].red   = (unsigned char) (rnd() * 256.0);
		dummy.colour[2].green = (unsigned char) (rnd() * 256.0);
		dummy.colour[2].blue  = (unsigned char) (rnd() * 256.0);
		dummy.colour[3].red   = (unsigned char) (rnd() * 256.0);
		dummy.colour[3].green = (unsigned char) (rnd() * 256.0);
		dummy.colour[3].blue  = (unsigned char) (rnd() * 256.0);
		}
	return new StarfishGeneratorRec( width, height, palette, wrapEdges );
	}

void GetStarfishPixel( int x, int y, StarfishRef texture, pixel* out )
	{
	texture->Pixel( x, y, out );
	}


#if BUILD_ALTIVEC
void GetStarfishPixel_AV(int x, int y, StarfishRef texture, vector unsigned char *pixels)
{
	texture->Pixel(x, y, pixels);
} // GetStarfishPixel_AV
#endif


void DumpStarfish( StarfishRef it )
	{
	delete it;
	}
