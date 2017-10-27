//
//  CO2Service.h
//  CO2Monitor
//
//  Created by pervushyn.a on 3/11/17.
//  Copyright © 2017 pervushyn.a. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

@protocol AirServiceDelegate

- (void)airServiceReadTemperature:(float)temp;
- (void)airServiceReadCo2:(float)co2;

@end

@interface AirService : NSObject

@property (weak, nonatomic) id<AirServiceDelegate> delegate;

- (void)loop;

@end
