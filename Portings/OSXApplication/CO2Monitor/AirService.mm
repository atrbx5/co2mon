//
//  CO2Service.m
//  CO2Monitor
//
//  Created by pervushyn.a on 3/11/17.
//  Copyright © 2017 pervushyn.a. All rights reserved.
//

#import "AirService.h"

#define _BSD_SOURCE
#define _XOPEN_SOURCE 700

#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include "hidapi.h"

#ifndef CO2MON_H_INCLUDED_
#define CO2MON_H_INCLUDED_
#endif

typedef hid_device *co2mon_device;

typedef unsigned char co2mon_data_t[8];


int
co2mon_init()
{
    int r = hid_init();
    if (r < 0)
    {
        fprintf(stderr, "hid_init: error\n");
    }
    return r;
}

void
co2mon_exit()
{
    int r = hid_exit();
    if (r < 0)
    {
        fprintf(stderr, "hid_exit: error\n");
    }
}

hid_device *
co2mon_open_device()
{
    hid_device *dev = hid_open(0x04d9, 0xa052, NULL);
    if (!dev)
    {
        fprintf(stderr, "hid_open: error\n");
    }
    return dev;
}

void
co2mon_close_device(hid_device *dev)
{
    hid_close(dev);
}

int
co2mon_device_path(hid_device *dev, char *str, size_t maxlen)
{
    str[0] = '\0';
    return 1;
}

int
co2mon_send_magic_table(hid_device *dev, co2mon_data_t magic_table)
{
    int r = hid_send_feature_report(dev, magic_table, sizeof(co2mon_data_t));
    if (r < 0 || r != sizeof(co2mon_data_t))
    {
        fprintf(stderr, "hid_send_feature_report: error\n");
        return 0;
    }
    return 1;
}

static void
swap_char(unsigned char *a, unsigned char *b)
{
    unsigned char tmp = *a;
    *a = *b;
    *b = tmp;
}

static void
decode_buf(co2mon_data_t result, co2mon_data_t buf, co2mon_data_t magic_table)
{
    swap_char(&buf[0], &buf[2]);
    swap_char(&buf[1], &buf[4]);
    swap_char(&buf[3], &buf[7]);
    swap_char(&buf[5], &buf[6]);
    
    for (int i = 0; i < 8; ++i)
    {
        buf[i] ^= magic_table[i];
    }
    
    unsigned char tmp = (buf[7] << 5);
    result[7] = (buf[6] << 5) | (buf[7] >> 3);
    result[6] = (buf[5] << 5) | (buf[6] >> 3);
    result[5] = (buf[4] << 5) | (buf[5] >> 3);
    result[4] = (buf[3] << 5) | (buf[4] >> 3);
    result[3] = (buf[2] << 5) | (buf[3] >> 3);
    result[2] = (buf[1] << 5) | (buf[2] >> 3);
    result[1] = (buf[0] << 5) | (buf[1] >> 3);
    result[0] = tmp | (buf[0] >> 3);
    
    unsigned char magic_word[8] = {'H','t','e','m','p','9','9','e'};
    for (int i = 0; i < 8; ++i)
    {
        result[i] -= (magic_word[i] << 4) | (magic_word[i] >> 4);
    }
}

int
co2mon_read_data(hid_device *dev, co2mon_data_t magic_table, co2mon_data_t result)
{
    co2mon_data_t data = { 0 };
    int actual_length = hid_read_timeout(dev, data, sizeof(co2mon_data_t), 5000 /* milliseconds */);
    if (actual_length < 0)
    {
        fprintf(stderr, "hid_read_timeout: error\n");
        return actual_length;
    }
    if (actual_length != sizeof(co2mon_data_t))
    {
        fprintf(stderr, "hid_read_timeout: transferred %d bytes, expected %lu bytes\n", actual_length, (unsigned long)sizeof(co2mon_data_t));
        return 0;
    }
    
    decode_buf(result, data, magic_table);
    return actual_length;
}

#define CODE_TAMB 0x42 /* Ambient Temperature */
#define CODE_CNTR 0x50 /* Relative Concentration of CO2 */

#define PATH_MAX 4096
#define VALUE_MAX 20

int daemonize = 0;
int print_unknown = 0;
char *datadir;

uint16_t co2mon_data[256];


static double
decode_temperature(uint16_t w)
{
    return (double)w * 0.0625 - 273.15;
}


@implementation AirService

- (instancetype)init {
    
    int r = co2mon_init();
    if (r < 0)
    {
        NSLog(@"r: %i", r);
    }
    
    return self;
    
}

static int error_shown = 0;

- (void)loop {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        co2mon_device dev = co2mon_open_device();
        if (dev == NULL)
        {
            if (!error_shown)
            {
                fprintf(stderr, "Unable to open CO2 device\n");
                error_shown = 1;
            }
            //sleep(1);
        } else {
            error_shown = 0;
            
            [self processDataFrom:dev];
        }
        
        co2mon_close_device(dev);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self loop];
        });
    });
}

- (void)processDataFrom:(co2mon_device) dev {

    co2mon_data_t magic_table = { 0 };
    co2mon_data_t result;
    
    if (!co2mon_send_magic_table(dev, magic_table))
    {
        fprintf(stderr, "Unable to send magic table to CO2 device\n");
        return;
    }
    
    while (1)
    {
        
        int r = co2mon_read_data(dev, magic_table, result);
        if (r <= 0)
        {
            fprintf(stderr, "Error while reading data from device\n");
            break;
        }
        
        if (result[4] != 0x0d)
        {
            fprintf(stderr, "Unexpected data from device (data[4] = %02hhx, want 0x0d)\n", result[4]);
            continue;
        }
        
        unsigned char r0, r1, r2, r3, checksum;
        r0 = result[0];
        r1 = result[1];
        r2 = result[2];
        r3 = result[3];
        checksum = r0 + r1 + r2;
        if (checksum != r3)
        {
            fprintf(stderr, "checksum error (%02hhx, await %02hhx)\n", checksum, r3);
            continue;
        }
        
        uint16_t w = (result[1] << 8) + result[2];
        switch (r0)
        {
            case CODE_TAMB:{
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate airServiceReadTemperature:decode_temperature(w)];
                });
            }
                break;
            case CODE_CNTR:{
                if ((unsigned)w > 3000) {
                    // Avoid reading spurious (uninitialized?) data
                    break;
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate airServiceReadCo2:w];
                });
                break;
            }
            default:
                if (print_unknown && !daemonize)
                {
                    printf("0x%02hhx\t%d\n", r0, (int)w);
                    fflush(stdout);
                }
                co2mon_data[r0] = w;
        }
    }
}


@end
