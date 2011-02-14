//
//  SpectrumView.m
//  AiffPlayer
//
//  Created by koji on 11/01/31.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "SpectrumView3D.h"
#include <vector>
#include <complex>
#include <iostream>
#include <math.h>

#include "fft.h"
#include "util.h"

#include "math.h"


static const int FFT_SIZE = 256 * 2;
static const int SPECTRUM3D_COUNT = 30;

static float rad(float degree){
	return 2 * M_PI/ 360 * degree;
}

class Point3D{
	
private:
	float mX,mY,mZ;
	void update(float x,float y, float z){
		mX = x;
		mY = y;
		mZ = z;
	}
public:
	Point3D(float x,float y,float z){
		update(x,y,z);
	}
	
	Point3D &rotateX(float theta){
		//mX = mX;
		mY = mY * cos(theta) + mZ * sin(theta);
		mZ = -mY * sin(theta) + mZ * cos(theta);
		return *this;
	}
	Point3D &rotateY(float theta){
		mX = mX*cos(theta) - mZ*sin(theta);
		//mY = mY;
		mZ = mX*sin(theta) + mZ*cos(theta);
		return *this;
	}
	Point3D &rotateZ(float theta){
		mX = mX*cos(theta) - mY*sin(theta);
		mY = mX*sin(theta) + mY*cos(theta);
		//mZ = mZ;
		return *this;
	}
	
	float operator[] (int i){
		switch(i){
			case 0:
				return mX;
			case 1:
				return mY;
			case 2:
				return mZ;
			default:
				return 0.0f;
		}
	}
	
	float x(){
		return mX;
	}
	float y(){
		return mY;
	}
	float z(){
		return mZ;
	}
	
	Point3D copy(){
		return Point3D(mX,mY,mZ);
	}
	
	Point3D &shift(float x, float y, float z){
		mX += x;
		mY += y;
		mZ += z;
		return *this;
	}
	
	Point3D &scale(float x, float y, float z){
		mX *= x;
		mY *= y;
		mZ *= z;
		return *this;
	}
	
	NSPoint toCamera(float d1, float d2){
		float cameraX = mX * d1 / (d2 + mZ);
		float cameraY = mY * d1 / (d2 + mZ);
		return NSMakePoint(cameraX, cameraY);
	}
	
	NSPoint toNSPoint(){
		return NSMakePoint(mX, mY);
	}
	

};


//world corrdinate is basically [-100 100] for x,y, and z


@implementation SpectrumView3D

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		_processor = nil;
								 
    }
    return self;
}
- (void)setProcessor:(CoreAudioInputProcessor *)processor{
	_processor = processor;
	[self setNeedsDisplay:YES];
	
	//TODO: manage timer instance, timer should initialized. only if there are no timer
	[NSTimer scheduledTimerWithTimeInterval:1.0f/30
									 target:self
								   selector: @selector(ontimer:)
								   userInfo:nil
									repeats:true];
	
}

- (void)ontimer:(NSTimer *)timer {
	[self setNeedsDisplay:YES];
}

//camera -> screen
- (NSPoint) screenFromCamera:(NSPoint)point{
	NSSize camera_size;
	camera_size.width = 200;
	camera_size.height = 200;
	
	//shift
	float x = point.x + camera_size.width/2.0;
	float y = point.y + camera_size.height/2.0;
	
	NSRect bounds = [self bounds];
	
	//scale
	x = x * bounds.size.width/camera_size.width;
	y = y * bounds.size.height/camera_size.height;
	return NSMakePoint(x,y);
}

//world -> camera -> screen
- (NSPoint)pointXYFrom3DPoint:(Point3D)point3d{
	
	point3d.rotateY(rad(-40)).rotateX(rad(40));
	NSPoint pointXY = point3d.toCamera(600,1000);		//DO NOT CHANGE THIS!
	pointXY = [self screenFromCamera:pointXY];
	
	pointXY.x -= [self bounds].size.width/2.2;
	pointXY.y -= 20;
	return pointXY;
}

//TODO: handling nyquist refrection

-(void)drawSpectrum:(const Spectrum &)spectrum index:(int)index{
	NSBezierPath *path = [[NSBezierPath bezierPath] retain];

	int length = spectrum.size()/2;
	for (int i = 0 ; i < length ; i++){
		float amp = abs(spectrum[i])/spectrum.size();
		float db = 20 * std::log10(amp);
		if (db < -95){
			//to draw the base line
			db = -96;
		}
		
		float y = db + 96 + 40/*visible factor*/;
		float z = i;
		
		//scale to world coordinate:[-100,100]
		z = z * 100/length*2/*scale factor*/;
		y = y * 200/96 * 0.2/*scale factor*/;
		float x = float(index) * 200/(_spectrums.size()) * 1.3/*scale factor*/;
		
		Point3D point3d(x,y,z);
		point3d.shift(0,0,0);
		
		//now point3d is 3D point in world coordinate.
		
		NSPoint point = [self pointXYFrom3DPoint:point3d];		
		if (i == 0){
			[path moveToPoint:point];
		}else{
			[path lineToPoint:point];
		}
	}
	NSColor *color = [NSColor colorWithCalibratedRed:0.5
											green:0.5 
											blue:0.5
											  alpha:1.0];
	[color set];
	//[[NSGraphicsContext currentContext] setShouldAntialias:NO];
	//[path stroke];
	
	//TODO: add lines to complete path
	//last point to -96 decibel
	{
		float x,y,z;
		x = float(index) * 200/(_spectrums.size()) * 1.3;
		y = 40.0f;
		y = y * 200/96 * 0.2;
		z = float(length)*100/length*2;
		Point3D point3d(x,y,z);
		NSPoint zeroAtMaxFreq = [self pointXYFrom3DPoint:point3d];
		[path lineToPoint:zeroAtMaxFreq];
	}
	
	{
		float x,y,z;
		x = float(index) * 200/(_spectrums.size()) * 1.3;
		y = 40.0f;
		y = y * 200/96 * 0.2;
		z = 0.0f*100/length*2;
		Point3D point3d(x,y,z);
		NSPoint zeroAtMinFreq = [self pointXYFrom3DPoint:point3d];
		[path lineToPoint:zeroAtMinFreq];
	}
	
	
	
	[path closePath];
	[path fill];
	[[NSColor yellowColor] set];
	[path stroke];
	
	//fill example
	/*
	NSBezierPath *path2 = [NSBezierPath bezierPath];
	[path2 moveToPoint:NSMakePoint(10,10)];
	[path2 lineToPoint:NSMakePoint(110,10)];
	[path2 lineToPoint:NSMakePoint(110,110)];
	[path2 lineToPoint:NSMakePoint(10,110)];
	[path2 closePath]; //closePath automatically create path from end point to first point.
	[path2 fill];*/
	
}


- (void)drawLineFrom:(Point3D)from to:(Point3D)to{
	NSPoint from_xy = [self pointXYFrom3DPoint:from];
	NSPoint to_xy = [self pointXYFrom3DPoint:to];

	[NSBezierPath strokeLineFromPoint:from_xy toPoint:to_xy];
}


- (void)drawText:(NSString *)text atPoint:(Point3D)point3d{
	
	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
	[attributes setObject:[NSFont fontWithName:@"Monaco" size:14.0f]
				   forKey:NSFontAttributeName];
	[attributes setObject:[NSColor whiteColor]
				   forKey:NSForegroundColorAttributeName];
	
	NSAttributedString *at_text = [[NSAttributedString alloc] initWithString: text
	                                                        attributes: attributes];
    
    NSPoint point_xy = [self pointXYFrom3DPoint:point3d];
    [at_text drawAtPoint:point_xy];
	
}


- (void)drawRect:(NSRect)dirtyRect {

    [[NSColor blackColor] set];
	NSRectFill([self bounds]);
	
	if (_processor == nil) return;
	
	using namespace std;
	
	//draw spectrum(s).
	if (_spectrums.size() > SPECTRUM3D_COUNT){
		_spectrums.pop_front();
	}
	_spectrums.push_back(Spectrum(FFT_SIZE,0.0));
	
	{
		Spectrum &spectrum = _spectrums.back();
		vector<complex<double> > buffer = vector<complex<double> >(FFT_SIZE, 0.0);
		const vector<float> *left = [_processor left];
		
		if ((left == NULL) || (left->size() < FFT_SIZE)){
			NSLog(@"not enough samples to get FFT");
			return;
		}
		
		//get the fft of latest FFT_SIZE samples.
		@synchronized( _processor ){
			int offset = left->size() - FFT_SIZE;
			for (int i = 0 ; i < FFT_SIZE; i++){
				buffer[i] = (*left)[i + offset];
			}
		}
		fastForwardFFT(&buffer[0], FFT_SIZE, &(spectrum[0]));
	}
	
	for(int index = 0; index < _spectrums.size(); index++){
		[self drawSpectrum:_spectrums[index] index:index];
	}

	//draw axis
	[[NSColor yellowColor] set];
	[self drawLineFrom:Point3D(0,-100,0) to:Point3D(0,100,0)];
	[self drawLineFrom:Point3D(-200,0,0) to:Point3D(200,0,0)];
	[self drawLineFrom:Point3D(0,0,-250) to:Point3D(0,0,250)];
	
	//draw axis label
	[self drawText:@"time(x)" atPoint:Point3D(200,0,0)];
	[self drawText:@"dB(y)" atPoint:Point3D(0,100,0)];
	[self drawText:@"freq(z)" atPoint:Point3D(0,0,250)];
	
	
}

@end
