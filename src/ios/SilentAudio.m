/*
  Copyright 2013-2017 appPlant GmbH

  Licensed to the Apache Software Foundation (ASF) under one
  or more contributor license agreements.  See the NOTICE file
  distributed with this work for additional information
  regarding copyright ownership.  The ASF licenses this file
  to you under the Apache License, Version 2.0 (the
  "License"); you may not use this file except in compliance
  with the License.  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing,
  software distributed under the License is distributed on an
  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
  KIND, either express or implied.  See the License for the
  specific language governing permissions and limitations
  under the License.
*/

#import "APPMethodMagicSA.h"
#import "SilentAudio.h"
#import <Cordova/CDVAvailability.h>
#include "notify.h"

@implementation SilentAudio

#pragma mark -
#pragma mark Constants

#pragma mark -
#pragma mark Life Cycle

/**
 * Called by runtime once the Class has been loaded.
 * Exchange method implementations to hook into their execution.
 */
+ (void) load
{
    [self swizzleWKWebViewEngine];
}

/**
 * Initialize the plugin.
 */
- (void) pluginInitialize
{
    volume = 0;
    [self configureAudioSession];
    [self configureAudioPlayer];
    [self observeLifeCycle];
}

/**
 * Register the listener for pause and resume events.
 */
- (void) observeLifeCycle
{
    NSNotificationCenter* listener = [NSNotificationCenter
                                      defaultCenter];

        [listener addObserver:self
                     selector:@selector(handleAudioSessionInterruption:)
                         name:AVAudioSessionInterruptionNotification
                       object:nil];
    
        [listener addObserver:self
                     selector:@selector(handleCTAudioPlay:)
                         name:@"CTIAudioPlay"
                       object:nil];
    
        [listener addObserver:self
                     selector:@selector(handleCTAudioFinished:)
                         name:@"CTIAudioFinished"
                       object:nil];
}

#pragma mark -
#pragma mark Interface

/**
 * Play silent audio
 */
- (void) play:(CDVInvokedUrlCommand*)command
{
    long duration = 30000;
    
    @try {
        duration = [[command argumentAtIndex:0] longLongValue];
    } @catch (NSException *exception) {}
    
    @try {
        volume = [[command argumentAtIndex:1] floatValue];
        volume = volume / 100;
    } @catch (NSException *exception) {}
    
    enabled = YES;
    
    audioPlayer.volume = volume;
    [self playAudio];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (duration / 1000) * NSEC_PER_SEC), dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        [self stopAudio];
    });
    
    [self execCallback:command];
}

#pragma mark -
#pragma mark Core

/**
 * Keep the app awake.
 */
- (void) playAudio
{
    if (!enabled)
        return;
    
    [self configureAudioSession];

    [audioPlayer play];
}

/**
 * Let the app going to sleep. 
 */
- (void) stopAudio
{
    enabled = NO;
    [audioPlayer stop];
}

/**
 * Configure the audio player.
 */
- (void) configureAudioPlayer
{
    NSString* path = [[NSBundle mainBundle]
                      pathForResource:@"appbeepSA" ofType:@"m4a"];

    NSURL* url = [NSURL fileURLWithPath:path];


    audioPlayer = [[AVAudioPlayer alloc]
                   initWithContentsOfURL:url error:NULL];

    audioPlayer.volume = volume;
    audioPlayer.numberOfLoops = -1;
};

/**
 * Configure the audio session.
 */
- (void) configureAudioSession
{
    AVAudioSession* session = [AVAudioSession
                               sharedInstance];

    // Don't activate the audio session yet
    [session setActive:NO error:NULL];

    // Play music even in background and dont stop playing music
    // even another app starts playing sound
    [session setCategory:AVAudioSessionCategoryPlayback
             withOptions:AVAudioSessionCategoryOptionMixWithOthers
                   error:NULL];

    // Active the audio session
    [session setActive:YES error:NULL];
};

#pragma mark -
#pragma mark Helper

/**
 * Simply invokes the callback without any parameter.
 */
- (void) execCallback:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult *result = [CDVPluginResult
                               resultWithStatus:CDVCommandStatus_OK];

    [self.commandDelegate sendPluginResult:result
                                callbackId:command.callbackId];
}

/**
 * Restart playing sound when interrupted by phone calls.
 */
- (void) handleAudioSessionInterruption:(NSNotification*)notification
{
    if (!enabled)
        return;
    
    [self playAudio];
}

/**
 * Stop background audio correctly if the app itself is about to play audio.
 */
- (void) handleCTAudioPlay:(NSNotification*)notification
{
    if (!enabled)
        return;
    
    [audioPlayer stop];
    [[AVAudioSession sharedInstance] setActive:NO error:nil];
}

/**
 * App has stopped playing audio so start background audio.
 */
- (void) handleCTAudioFinished:(NSNotification*)notification
{
    if (!enabled)
        return;
    
    [self configureAudioPlayer];
    [self configureAudioSession];
    [audioPlayer play];
}

/**
 * Find out if the app runs inside the webkit powered webview.
 */
+ (BOOL) isRunningWebKit
{
    return IsAtLeastiOSVersion(@"8.0") && NSClassFromString(@"CDVWKWebViewEngine");
}

#pragma mark -
#pragma mark Swizzling

/**
 * Method to swizzle.
 */
+ (NSString*) wkProperty
{
    NSString* str = @"YWx3YXlzUnVuc0F0Rm9yZWdyb3VuZFByaW9yaXR5";
    NSData* data  = [[NSData alloc] initWithBase64EncodedString:str options:0];

    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

/**
 * Swizzle some implementations of CDVWKWebViewEngine.
 */
+ (void) swizzleWKWebViewEngine
{
    if (![self isRunningWebKit])
        return;

    Class wkWebViewEngineCls = NSClassFromString(@"CDVWKWebViewEngine");
    SEL selector = NSSelectorFromString(@"createConfigurationFromSettings:");

    SwizzleSelectorWithBlock_Begin(wkWebViewEngineCls, selector)
    ^(CDVPlugin *self, NSDictionary *settings) {
        id obj = ((id (*)(id, SEL, NSDictionary*))_imp)(self, _cmd, settings);

        [obj setValue:[NSNumber numberWithBool:YES]
               forKey:[SilentAudio wkProperty]];

        return obj;
    }
    SwizzleSelectorWithBlock_End;
}

@end
