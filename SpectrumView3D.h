//
//  SpectrumView3D.h
//  Oscilloscope
//
//  Created by koji on 11/02/08.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CoreAudioInputProcessor.h"
#include <vector>
#include <deque>
#include <complex>

typedef std::complex<double> Dcomplex;
typedef std::vector<Dcomplex>  Spectrum;

@interface SpectrumView3D : NSView {
	id _processor;	//or sound buffer
	std::deque<Spectrum> _spectrums;
	
	float _rotateX;
	float _rotateY;
	float _rotateZ;
	
	Boolean _enabled;
	
}

- (void)setProcessor:(CoreAudioInputProcessor *)processor;

@property(assign)float rotateX;
@property(assign)float rotateY;
@property(assign)float rotateZ;
@property(assign)Boolean enabled;

@end

