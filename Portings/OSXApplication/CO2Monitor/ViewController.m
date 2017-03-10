//
//  ViewController.m
//  CO2Monitor
//
//  Created by pervushyn.a on 3/11/17.
//  Copyright © 2017 pervushyn.a. All rights reserved.
//

#import "ViewController.h"
#import "AirService.h"
@import AFNetworking;

@interface ViewController ()<AirServiceDelegate>

@property (strong, nonatomic) AirService *airService;
@property (assign, nonatomic) float temp;
@property (assign, nonatomic) int co2;

@end


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.airService = [[AirService alloc] init];
    self.airService.delegate = self;
    [self.airService loop];
    
    [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(sendStat) userInfo:nil repeats:YES];
    
}

- (void) sendStat {
    
    if (self.temp != 0 && self.co2 != 0){
        
        NSString *path = @"http://some.host";
        NSDictionary *params = @{
                                 @"temperature": @(self.temp),
                                 @"co2": @(self.co2)
                                 };
        
        AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
        manager.responseSerializer = [AFHTTPResponseSerializer serializer];
        [manager POST:path parameters:params progress:nil success:^(NSURLSessionDataTask *task, id responseObject) {
            
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            NSLog(@"Error: %@", error);
        }];
    }
    
    self.temp = 0;
    self.co2 = 0;
}

#pragma mark - AirServiceDelegate


- (void)airServiceReadTemperature:(float)temp {
    self.temp = temp;
    self.tempLabel.stringValue = [NSString stringWithFormat:@"Temp: %0.2f °C", temp];
}

- (void)airServiceReadCo2:(float)co2 {
    self.co2 = co2;
    self.co2Label.stringValue = [NSString stringWithFormat:@"CO2: %0.0f ppm", co2];
}

@end
