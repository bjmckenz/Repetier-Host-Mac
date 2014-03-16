/*
 Copyright 2011 repetier repetierdev@googlemail.com
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */


#import "PrinterConfiguration.h"
#import "StringUtil.h"
#import "ThreadedNotification.h"
#import "RHAppDelegate.h"
#import "RHManualControl.h"
#import "GCodeEditorController.h"
#import "RHOpenGLView.h"
#import "PrinterConnection.h"

@implementation PrinterConfiguration

@synthesize name;
@synthesize port;
@synthesize startCode;
@synthesize endCode;
@synthesize jobkillCode;
@synthesize jobpauseCode;
@synthesize script1Code;
@synthesize script2Code;
@synthesize script3Code;
@synthesize script4Code;
@synthesize script5Code;
@synthesize filterPrg;
@synthesize b;

-(id)init {
    if((self = [super init])) {
        [self setName:@"Default"];
        [self setPort:@"None"];
        baud = 57600;
        databits = 8;
        parity = kAMSerialParityNone;
        stopBits = kAMSerialStopBitsOne;
        width = 200;
        height = 100;
        depth = 200;
        printerType = 0;
        deltaDiameter = 250;
        deltaHeight = 200;
        bedLeft = bedFront = xMin = yMin = 0;
        xMax = width;
        yMax = depth;
        afterJobGoDispose = YES;
        afterJobDisableExtruder = YES;
        afterJobDisableHeatedBed = YES;
        afterJobDisableMotors = NO;
        pingPongMode = NO;
        receiveCacheSize = 63;
        autocheckTemp = YES;
        dontLogM105 = YES;
        autocheckInterval = 1;
        disposeZ = 0;
        disposeX = 135;
        disposeY = 0;
        travelFeedrate = 4800;
        travelZFeedrate = 100;
        defaultExtruderTemp = 200;
        defaultHeatedBedTemp = 55;
        protocol = 0;
        numberOfExtruder = 1;
        pingPongMode = NO;
        okAfterResend = YES;
        dumpAreaLeft = 125;
        dumpAreaFront = 0;
        dumpAreaWidth = 40;
        dumpAreaDepth = 22;
        enableFilterPrg = NO;
        importing = YES;
        homeX = homeY = homeZ = 0;
        [self setStartCode:@""];
        [self setEndCode:@""];
        [self setJobkillCode:@""];
        [self setJobpauseCode:@""];
        [self setScript1Code:@""];
        [self setScript2Code:@""];
        [self setScript3Code:@""];
        [self setScript4Code:@""];
        [self setScript5Code:@""];
        [self setFilterPrg:@""];
        [self setActiveSlicer:1];
        [self setSkeinforgeProfile:@""];
        [self setSlic3rFilament1:@""];
        [self setSlic3rFilament2:@""];
        [self setSlic3rFilament3:@""];
        [self setSlic3rPrint:@""];
        [self setSlic3rPrinter:@""];
        importing = NO;
    }
    return self;
}
-(void)dealloc {
    [name release];
    [port release];
    [super dealloc];
}
-(void)sanityCheck {
    if(xMax<xMin+width)
        xMax = xMin+width;
    if(yMax<yMin+depth)
        yMax = yMin+depth;
    if(bedLeft>xMax-width)
        bedLeft = xMax-width;
    if(bedLeft<xMin) bedLeft = xMin;
    if(bedFront>yMax-depth)
        bedFront = yMax-depth;
    if(bedFront<yMin) bedFront = yMin;
}
-(PrinterConfiguration*)initLoadFromRepository:(NSString*)confname {
    self=[self init];
    self.b = [@"printer." stringByAppendingString:confname];
    d = [NSUserDefaults standardUserDefaults];
    [self setupDefaultsRepository:confname]; // Make sure we have data to read
    [self setName:confname];
    [self setPort:[d objectForKey:[self.b stringByAppendingString:@".port"]]];
    baud = (int)[d integerForKey:[self.b stringByAppendingString:@".baud"]];
    parity = (int)[d integerForKey:[self.b stringByAppendingString:@".parity"]];
    stopBits = (int)[d integerForKey:[self.b stringByAppendingString:@".stopBits"]];
    databits = (int)[d integerForKey:[self.b stringByAppendingString:@".databits"]];
    protocol = (int)[d integerForKey:[self.b stringByAppendingString:@".protocol"]];
    autocheckInterval = (int)[d integerForKey:[self.b stringByAppendingString:@".autocheckInterval"]];
    defaultExtruderTemp = (int)[d integerForKey:[self.b stringByAppendingString:@".defaultExtruderTemp"]];
    defaultHeatedBedTemp = (int)[d integerForKey:[self.b stringByAppendingString:@".defaultHeatedBedTemp"]];
    receiveCacheSize = (int)[d integerForKey:[self.b stringByAppendingString:@".receiveCacheSize"]];
    afterJobGoDispose = [d boolForKey:[self.b stringByAppendingString:@".afterJobGoDispose"]];
    afterJobDisableExtruder = [d boolForKey:[self.b stringByAppendingString:@".afterJobDisableExtruder"]];
    afterJobDisableHeatedBed = [d boolForKey:[self.b stringByAppendingString:@".afterJobDisableHeatedBed"]];
    afterJobDisableMotors = [d boolForKey:[self.b stringByAppendingString:@".afterJobDisableMotors"]];
    dontLogM105 = [d boolForKey:[self.b stringByAppendingString:@".dontLogM105"]];
    autocheckTemp = [d boolForKey:[self.b stringByAppendingString:@".autocheckTemp"]];
    okAfterResend = [d boolForKey:[self.b stringByAppendingString:@".okAfterResend"]];
    pingPongMode = [d boolForKey:[self.b stringByAppendingString:@".pingPongMode"]];
    width = [d doubleForKey:[self.b stringByAppendingString:@".width"]];
    height = [d doubleForKey:[self.b stringByAppendingString:@".height"]];
    depth = [d doubleForKey:[self.b stringByAppendingString:@".depth"]];
    xMin = [d doubleForKey:[self.b stringByAppendingString:@".xMin"]];
    xMax = [d doubleForKey:[self.b stringByAppendingString:@".xMax"]];
    yMin = [d doubleForKey:[self.b stringByAppendingString:@".yMin"]];
    yMax = [d doubleForKey:[self.b stringByAppendingString:@".yMax"]];
    bedLeft = [d doubleForKey:[self.b stringByAppendingString:@".bedLeft"]];
    bedFront = [d doubleForKey:[self.b stringByAppendingString:@".bedFront"]];
    if([d objectForKey:[self.b stringByAppendingString:@".homeXMax"]]!=nil) {
        BOOL homeXMax = [d boolForKey:[self.b stringByAppendingString:@".homeXMax"]];
        if(homeXMax) homeX = 0; else homeX = 1;
        [d removeObjectForKey:[self.b stringByAppendingString:@".homeXMax"]];
        [d setInteger:homeX forKey:[self.b stringByAppendingString:@".homeX"]];
    } else {
        homeX = (int)[d integerForKey:[self.b stringByAppendingString:@".homeX"]];
    }
    if([d objectForKey:[self.b stringByAppendingString:@".homeYMax"]]!=nil) {
        BOOL homeYMax = [d boolForKey:[self.b stringByAppendingString:@".homeYMax"]];
        if(homeYMax) homeY = 0; else homeY = 1;
        [d removeObjectForKey:[self.b stringByAppendingString:@".homeYMax"]];
        [d setInteger:homeY forKey:[self.b stringByAppendingString:@".homeY"]];
    } else {
        homeY = (int)[d integerForKey:[self.b stringByAppendingString:@".homeY"]];
    }
    if([d objectForKey:[self.b stringByAppendingString:@".homeZMax"]]!=nil) {
        BOOL homeZMax = [d boolForKey:[self.b stringByAppendingString:@".homeZMax"]];
        if(homeZMax) homeZ = 0; else homeZ = 1;
        [d removeObjectForKey:[self.b stringByAppendingString:@".homeZMax"]];
        [d setInteger:homeZ forKey:[self.b stringByAppendingString:@".homeZ"]];
    } else {
        homeZ = (int)[d integerForKey:[self.b stringByAppendingString:@".homeZ"]];
    }
    travelFeedrate = [d doubleForKey:[self.b stringByAppendingString:@".travelFeedrate"]];
    travelZFeedrate = [d doubleForKey:[self.b stringByAppendingString:@".travelZFeedrate"]];
    disposeX = [d doubleForKey:[self.b stringByAppendingString:@".disposeX"]];
    disposeY = [d doubleForKey:[self.b stringByAppendingString:@".disposeY"]];
    disposeZ = [d doubleForKey:[self.b stringByAppendingString:@".disposeZ"]];
    [self setStartCode:[d stringForKey:[self.b stringByAppendingString:@".startCode"]]];
    [self setEndCode:[d stringForKey:[self.b stringByAppendingString:@".endCode"]]];
    [self setJobkillCode:[d stringForKey:[self.b stringByAppendingString:@".jobkillCode"]]];
    [self setJobpauseCode:[d stringForKey:[self.b stringByAppendingString:@".jobpauseCode"]]];
    [self setScript1Code:[d stringForKey:[self.b stringByAppendingString:@".script1Code"]]];
    [self setScript2Code:[d stringForKey:[self.b stringByAppendingString:@".script2Code"]]];
    [self setScript3Code:[d stringForKey:[self.b stringByAppendingString:@".script3Code"]]];
    [self setScript4Code:[d stringForKey:[self.b stringByAppendingString:@".script4Code"]]];
    [self setScript5Code:[d stringForKey:[self.b stringByAppendingString:@".script5Code"]]];
    [self setFilterPrg:[d stringForKey:[self.b stringByAppendingString:@".filterPrg"]]];
    enableFilterPrg = [d boolForKey:[self.b stringByAppendingString:@".enableFilterPrg"]];
    if([d objectForKey:[self.b stringByAppendingString:@".hasDumpArea"]]!=nil) {
        BOOL hasDumpArea = [d boolForKey:[self.b stringByAppendingString:@".hasDumpArea"]];
        if(hasDumpArea) printerType = 1;
        else printerType = 0;
        [d removeObjectForKey:[self.b stringByAppendingString:@".hasDumpArea"]];
        [d setInteger:printerType forKey:[self.b stringByAppendingString:@".printerType"]];
    } else printerType = (int)[d integerForKey:[self.b stringByAppendingString:@".printerType"]];
    dumpAreaLeft = [d doubleForKey:[self.b stringByAppendingString:@".dumpAreaLeft"]];
    dumpAreaFront = [d doubleForKey:[self.b stringByAppendingString:@".dumpAreaFront"]];
    dumpAreaWidth = [d doubleForKey:[self.b stringByAppendingString:@".dumpAreaWidth"]];
    dumpAreaDepth = [d doubleForKey:[self.b stringByAppendingString:@".dumpAreaDepth"]];
    deltaDiameter = [d doubleForKey:[self.b stringByAppendingString:@".deltaDiameter"]];
    deltaHeight = [d doubleForKey:[self.b stringByAppendingString:@".deltaHeight"]];
    addPrintingTime = [d doubleForKey:[self.b stringByAppendingString:@".addPrintingTime"]];
    numberOfExtruder = (int)[d integerForKey:[self.b stringByAppendingString:@".numberOfExtruder"]];

    importing = YES;
    [self setSkeinforgeProfile:[d stringForKey:[self.b stringByAppendingString:@".skeinforgeProfile"]]];
    [self setSlic3rPrint:[d stringForKey:[self.b stringByAppendingString:@".slic3rPrint"]]];
    [self setSlic3rPrinter:[d stringForKey:[self.b stringByAppendingString:@".slic3rPrinter"]]];
    [self setSlic3rFilament1:[d stringForKey:[self.b stringByAppendingString:@".slic3rFilament1"]]];
    [self setSlic3rFilament2:[d stringForKey:[self.b stringByAppendingString:@".slic3rFilament2"]]];
    [self setSlic3rFilament3:[d stringForKey:[self.b stringByAppendingString:@".slic3rFilament3"]]];
    activeSlicer = (int)[d integerForKey:[self.b stringByAppendingString:@".activeSlicer"]];
    importing = NO;
    [self sanityCheck];
    return self;
}
-(void)setupDefaultsRepository:(NSString*)confname {
    NSMutableDictionary *d2 = [NSMutableDictionary dictionary];
    self.b = [@"printer." stringByAppendingString:confname];
    [d2 setObject:port forKey:[self.b stringByAppendingString:@".port"]];
    [d2 setObject:[NSNumber numberWithInt:baud] forKey:[self.b stringByAppendingString:@".baud"]];
    [d2 setObject:[NSNumber numberWithInt:parity] forKey:[self.b stringByAppendingString:@".parity"]];
    [d2 setObject:[NSNumber numberWithInt:stopBits] forKey:[self.b stringByAppendingString:@".stopBits"]];
    [d2 setObject:[NSNumber numberWithInt:databits] forKey:[self.b stringByAppendingString:@".databits"]];
    [d2 setObject:[NSNumber numberWithInt:protocol] forKey:[self.b stringByAppendingString:@".protocol"]];
    [d2 setObject:[NSNumber numberWithInt:autocheckInterval] forKey:[self.b stringByAppendingString:@".autocheckInterval"]];
    [d2 setObject:[NSNumber numberWithInt:defaultExtruderTemp] forKey:[self.b stringByAppendingString:@".defaultExtruderTemp"]];
    [d2 setObject:[NSNumber numberWithInt:defaultHeatedBedTemp] forKey:[self.b stringByAppendingString:@".defaultHeatedBedTemp"]];
    [d2 setObject:[NSNumber numberWithInt:receiveCacheSize] forKey:[self.b stringByAppendingString:@".receiveCacheSize"]];
    [d2 setObject:[NSNumber numberWithBool:afterJobGoDispose] forKey:[self.b stringByAppendingString:@".afterJobGoDispose"]];
    [d2 setObject:[NSNumber numberWithBool:afterJobDisableExtruder] forKey:[self.b stringByAppendingString:@".afterJobDisableExtruder"]];
    [d2 setObject:[NSNumber numberWithBool:afterJobDisableHeatedBed] forKey:[self.b stringByAppendingString:@".afterJobDisableHeatedBed"]];
    [d2 setObject:[NSNumber numberWithBool:afterJobDisableMotors] forKey:[self.b stringByAppendingString:@".afterJobDisableMotors"]];
    [d2 setObject:[NSNumber numberWithBool:dontLogM105] forKey:[self.b stringByAppendingString:@".dontLogM105"]];
    [d2 setObject:[NSNumber numberWithBool:autocheckTemp] forKey:[self.b stringByAppendingString:@".autocheckTemp"]];
    [d2 setObject:[NSNumber numberWithBool:okAfterResend] forKey:[self.b stringByAppendingString:@".okAfterResend"]];
    [d2 setObject:[NSNumber numberWithBool:pingPongMode] forKey:[self.b stringByAppendingString:@".pingPongMode"]];
    [d2 setObject:[NSNumber numberWithDouble:width] forKey:[self.b stringByAppendingString:@".width"]];
    [d2 setObject:[NSNumber numberWithDouble:height] forKey:[self.b stringByAppendingString:@".height"]];
    [d2 setObject:[NSNumber numberWithDouble:depth] forKey:[self.b stringByAppendingString:@".depth"]];
    [d2 setObject:[NSNumber numberWithDouble:xMin] forKey:[self.b stringByAppendingString:@".xMin"]];
    [d2 setObject:[NSNumber numberWithDouble:xMax] forKey:[self.b stringByAppendingString:@".xMax"]];
    [d2 setObject:[NSNumber numberWithDouble:yMin] forKey:[self.b stringByAppendingString:@".yMin"]];
    [d2 setObject:[NSNumber numberWithDouble:yMax] forKey:[self.b stringByAppendingString:@".yMax"]];
    [d2 setObject:[NSNumber numberWithDouble:bedLeft] forKey:[self.b stringByAppendingString:@".bedLeft"]];
    [d2 setObject:[NSNumber numberWithDouble:bedFront] forKey:[self.b stringByAppendingString:@".bedFront"]];
    [d2 setObject:[NSNumber numberWithBool:homeX] forKey:[self.b stringByAppendingString:@".homeX"]];
    [d2 setObject:[NSNumber numberWithBool:homeY] forKey:[self.b stringByAppendingString:@".homeY"]];
    [d2 setObject:[NSNumber numberWithBool:homeZ] forKey:[self.b stringByAppendingString:@".homeZ"]];
    [d2 setObject:[NSNumber numberWithDouble:travelFeedrate] forKey:[self.b stringByAppendingString:@".travelFeedrate"]];
    [d2 setObject:[NSNumber numberWithDouble:travelZFeedrate] forKey:[self.b stringByAppendingString:@".travelZFeedrate"]];
    [d2 setObject:[NSNumber numberWithDouble:disposeX] forKey:[self.b stringByAppendingString:@".disposeX"]];
    [d2 setObject:[NSNumber numberWithDouble:disposeY] forKey:[self.b stringByAppendingString:@".disposeY"]];
    [d2 setObject:[NSNumber numberWithDouble:disposeZ] forKey:[self.b stringByAppendingString:@".disposeZ"]];
    [d2 setObject:@"" forKey:[self.b stringByAppendingString:@".startCode"]];
    [d2 setObject:@"" forKey:[self.b stringByAppendingString:@".endCode"]];
    [d2 setObject:@"" forKey:[self.b stringByAppendingString:@".jobkillCode"]];
    [d2 setObject:@"" forKey:[self.b stringByAppendingString:@".jobpauseCode"]];
    [d2 setObject:@"" forKey:[self.b stringByAppendingString:@".script1Code"]];
    [d2 setObject:@"" forKey:[self.b stringByAppendingString:@".script2Code"]];
    [d2 setObject:@"" forKey:[self.b stringByAppendingString:@".script3Code"]];
    [d2 setObject:@"" forKey:[self.b stringByAppendingString:@".script4Code"]];
    [d2 setObject:@"" forKey:[self.b stringByAppendingString:@".script5Code"]];

    [d2 setObject:@"" forKey:[self.b stringByAppendingString:@".filterPrg"]];
    [d2 setObject:[NSNumber numberWithBool:enableFilterPrg] forKey:[self.b stringByAppendingString:@".enableFilterPrg"]];
    
    // Some defaults for the gui
    [d2 setObject:[NSNumber numberWithDouble:100] forKey:@"fanSpeed"];
    [d2 setObject:[NSNumber numberWithBool:NO] forKey:@"debugEcho"];
    [d2 setObject:[NSNumber numberWithBool:YES] forKey:@"debugInfo"];
    [d2 setObject:[NSNumber numberWithBool:YES] forKey:@"debugErrors"];
    [d2 setObject:[NSNumber numberWithBool:NO] forKey:@"debugDryRun"];
    [d2 setObject:[NSNumber numberWithDouble:10] forKey:@"extruder.extrudeLength"];
    [d2 setObject:[NSNumber numberWithDouble:50] forKey:@"extruder.extrudeSpeed"];
    //[d setObject:[NSNumber numberWithBool:NO] forKey:[self.b stringByAppendingString:@".hasDumpArea"]];
    [d2 setObject:[NSNumber numberWithInt:0] forKey:[self.b stringByAppendingString:@".printerType"]];
    [d2 setObject:[NSNumber numberWithDouble:125] forKey:[self.b stringByAppendingString:@".dumpAreaLeft"]];
    [d2 setObject:[NSNumber numberWithDouble:0] forKey:[self.b stringByAppendingString:@".dumpAreaFront"]];
    [d2 setObject:[NSNumber numberWithDouble:40] forKey:[self.b stringByAppendingString:@".dumpAreaWidth"]];
    [d2 setObject:[NSNumber numberWithDouble:22] forKey:[self.b stringByAppendingString:@".dumpAreaDepth"]];
    [d2 setObject:[NSNumber numberWithDouble:250] forKey:[self.b stringByAppendingString:@".deltaDiameter"]];
    [d2 setObject:[NSNumber numberWithDouble:200] forKey:[self.b stringByAppendingString:@".deltaHeight"]];
    [d2 setObject:[NSNumber numberWithDouble:8] forKey:[self.b stringByAppendingString:@".addPrintingTime"]];
    [d2 setObject:[NSNumber numberWithInt:1] forKey:[self.b stringByAppendingString:@".numberOfExtruder"]];
    [d2 setObject:[NSNumber numberWithInt:1] forKey:[self.b stringByAppendingString:@".activeSlicer"]];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:d2];
    //[d release];
}
-(void)saveToRepository{
    [self sanityCheck];
    d = [NSUserDefaults standardUserDefaults];
    self.b = [@"printer." stringByAppendingString:name];
    [d setObject:port forKey:[self.b stringByAppendingString:@".port"]];
    [d setInteger:baud forKey:[self.b stringByAppendingString:@".baud"]];
    [d setInteger:parity forKey:[self.b stringByAppendingString:@".parity"]];
    [d setInteger:stopBits forKey:[self.b stringByAppendingString:@".stopBits"]];
    [d setInteger:databits forKey:[self.b stringByAppendingString:@".databits"]];
    [d setInteger:protocol forKey:[self.b stringByAppendingString:@".protocol"]];
    [d setInteger:autocheckInterval forKey:[self.b stringByAppendingString:@".autocheckInterval"]];
    [d setInteger:defaultExtruderTemp forKey:[self.b stringByAppendingString:@".defaultExtruderTemp"]];
    [d setInteger:defaultHeatedBedTemp forKey:[self.b stringByAppendingString:@".defaultHeatedBedTemp"]];
    [d setInteger:receiveCacheSize forKey:[self.b stringByAppendingString:@".receiveCacheSize"]];
    [d setBool:afterJobGoDispose forKey:[self.b stringByAppendingString:@".afterJobGoDispose"]];
    [d setBool:afterJobDisableExtruder forKey:[self.b stringByAppendingString:@".afterJobDisableExtruder"]];
    [d setBool:afterJobDisableHeatedBed forKey:[self.b stringByAppendingString:@".afterJobDisableHeatedBed"]];
    [d setBool:afterJobDisableMotors forKey:[self.b stringByAppendingString:@".afterJobDisableMotors"]];
    [d setBool:autocheckTemp forKey:[self.b stringByAppendingString:@".autocheckTemp"]];
    [d setBool:okAfterResend forKey:[self.b stringByAppendingString:@".okAfterResend"]];
    [d setBool:pingPongMode forKey:[self.b stringByAppendingString:@".pingPongMode"]];
    [d setBool:dontLogM105 forKey:[self.b stringByAppendingString:@".dontLogM105"]];
    [d setDouble:width forKey:[self.b stringByAppendingString:@".width"]];
    [d setDouble:height forKey:[self.b stringByAppendingString:@".height"]];
    [d setDouble:depth forKey:[self.b stringByAppendingString:@".depth"]];
    [d setDouble:xMin forKey:[self.b stringByAppendingString:@".xMin"]];
    [d setDouble:xMax forKey:[self.b stringByAppendingString:@".xMax"]];
    [d setDouble:yMin forKey:[self.b stringByAppendingString:@".yMin"]];
    [d setDouble:yMax forKey:[self.b stringByAppendingString:@".yMax"]];
    [d setDouble:bedLeft forKey:[self.b stringByAppendingString:@".bedLeft"]];
    [d setDouble:bedFront forKey:[self.b stringByAppendingString:@".bedFront"]];
    [d setDouble:deltaDiameter forKey:[self.b stringByAppendingString:@".deltaDiameter"]];
    [d setDouble:deltaHeight forKey:[self.b stringByAppendingString:@".deltaHeight"]];
    [d setInteger:homeX forKey:[self.b stringByAppendingString:@".homeX"]];
    [d setInteger:homeY forKey:[self.b stringByAppendingString:@".homeY"]];
    [d setInteger:homeZ forKey:[self.b stringByAppendingString:@".homeZ"]];
    [d setDouble:travelFeedrate forKey:[self.b stringByAppendingString:@".travelFeedrate"]];
    [d setDouble:travelZFeedrate forKey:[self.b stringByAppendingString:@".travelZFeedrate"]];
    [d setDouble:disposeX forKey:[self.b stringByAppendingString:@".disposeX"]];
    [d setDouble:disposeY forKey:[self.b stringByAppendingString:@".disposeY"]];
    [d setDouble:disposeZ forKey:[self.b stringByAppendingString:@".disposeZ"]];
    [d setObject:startCode forKey:[self.b stringByAppendingString:@".startCode"]];
    [d setObject:endCode forKey:[self.b stringByAppendingString:@".endCode"]];
    [d setObject:jobkillCode forKey:[self.b stringByAppendingString:@".jobkillCode"]];
    [d setObject:jobpauseCode forKey:[self.b stringByAppendingString:@".jobpauseCode"]];
    [d setObject:script1Code forKey:[self.b stringByAppendingString:@".script1Code"]];
    [d setObject:script2Code forKey:[self.b stringByAppendingString:@".script2Code"]];
    [d setObject:script3Code forKey:[self.b stringByAppendingString:@".script3Code"]];
    [d setObject:script4Code forKey:[self.b stringByAppendingString:@".script4Code"]];
    [d setObject:script5Code forKey:[self.b stringByAppendingString:@".script5Code"]];
    [d setObject:filterPrg forKey:[self.b stringByAppendingString:@".filterPrg"]];
    [d setBool:enableFilterPrg forKey:[self.b stringByAppendingString:@".enableFilterPrg"]];
    //    [d setBool:hasDumpArea forKey:[self.b stringByAppendingString:@".hasDumpArea"]];
    [d setDouble:dumpAreaLeft forKey:[self.b stringByAppendingString:@".dumpAreaLeft"]];
    [d setDouble:dumpAreaFront forKey:[self.b stringByAppendingString:@".dumpAreaFront"]];
    [d setDouble:dumpAreaWidth forKey:[self.b stringByAppendingString:@".dumpAreaWidth"]];
    [d setDouble:dumpAreaDepth forKey:[self.b stringByAppendingString:@".dumpAreaDepth"]];
    [d setDouble:addPrintingTime forKey:[self.b stringByAppendingString:@".addPrintingTime"]];
    [d setInteger:numberOfExtruder forKey:[self.b stringByAppendingString:@".numberOfExtruder"]];
    [d setInteger:printerType forKey:[self.b stringByAppendingString:@".printerType"]];
    [d setObject:slic3rPrint forKey:[self.b stringByAppendingString:@".slic3rPrint"]];
    [d setObject:slic3rPrinter forKey:[self.b stringByAppendingString:@".slic3rPrinter"]];
    [d setObject:slic3rFilament1 forKey:[self.b stringByAppendingString:@".slic3rFilament1"]];
    [d setObject:slic3rFilament2 forKey:[self.b stringByAppendingString:@".slic3rFilament2"]];
    [d setObject:slic3rFilament3 forKey:[self.b stringByAppendingString:@".slic3rFilament3"]];
    [d setInteger:activeSlicer  forKey:[self.b stringByAppendingString:@".activeSlicer"]];

    if(app!=nil)
        [app->manualControl updateExtruderCount];
}
+(void)initPrinter {
    printerConfigurations = [NSMutableArray new];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:@"" forKey:@"currentPrinter"];
    [dict setObject:@"" forKey:@"printerList"];
    [d registerDefaults:dict];
    NSString *current = [d objectForKey:@"currentPrinter"];
    NSString *sPrinterList = [d objectForKey:@"printerList"];
    NSMutableArray *plist = [StringUtil explode:sPrinterList sep:@";"];
    if([plist count]==0) { // Make default printer
        currentPrinterConfiguration = [[PrinterConfiguration alloc] init];
        [currentPrinterConfiguration saveToRepository];
        [d setObject:[currentPrinterConfiguration name] forKey:@"currentPrinter"];
        [d setObject:[currentPrinterConfiguration name] forKey:@"printerList"];
    } else {
        for(NSString* s in plist) {
            PrinterConfiguration *pconf = [[PrinterConfiguration alloc] initLoadFromRepository:s];
            [printerConfigurations addObject:pconf];
            [pconf release];
        }
        currentPrinterConfiguration = [PrinterConfiguration findPrinter:current];
        [currentPrinterConfiguration retain];
    }    
}
+(PrinterConfiguration*) findPrinter:(NSString *)name {
    for (PrinterConfiguration* conf in printerConfigurations) {
		if([[conf name] isEqualToString:name])
            return conf;
	}  
    return nil;
}
+(void)fillFormsWithCurrent {
    if(!connection->connected) 
        [connection setConfig:currentPrinterConfiguration];
    [app->gcodeView setContent:1 text:currentPrinterConfiguration->startCode];
    [app->gcodeView setContent:2 text:currentPrinterConfiguration->endCode];
    [app->gcodeView setContent:3 text:currentPrinterConfiguration->jobkillCode];
    [app->gcodeView setContent:4 text:currentPrinterConfiguration->jobpauseCode];
    [app->gcodeView setContent:5 text:currentPrinterConfiguration->script1Code];
    [app->gcodeView setContent:6 text:currentPrinterConfiguration->script2Code];
    [app->gcodeView setContent:7 text:currentPrinterConfiguration->script3Code];
    [app->gcodeView setContent:8 text:currentPrinterConfiguration->script4Code];
    [app->gcodeView setContent:9 text:currentPrinterConfiguration->script5Code];
    [app->manualControl->extruderTempText setIntValue:currentPrinterConfiguration->defaultExtruderTemp];
    [app->manualControl->heatedBedTempText setIntValue:currentPrinterConfiguration->defaultHeatedBedTemp];
    [app->openGLView redraw];
}
+(PrinterConfiguration*)selectPrinter:(NSString *)name {
    currentPrinterConfiguration = [self findPrinter:name];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:name forKey:@"currentPrinter"];
    return currentPrinterConfiguration;
}
+(BOOL)createPrinter:(NSString *)name {
    PrinterConfiguration *c = [self findPrinter:name];
    if(c!=nil) return NO;
    c = [[PrinterConfiguration alloc] initLoadFromRepository:currentPrinterConfiguration.name];
    [c setName:name];
    [printerConfigurations addObject:c];
    [c release];
    // Update printer list
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:printerConfigurations.count];
    for(PrinterConfiguration *conf in printerConfigurations)
        [arr addObject:conf->name];
    NSString *list = [StringUtil implode:arr sep:@";"];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:list forKey:@"printerList"];
    [ThreadedNotification notifyNow:@"RHPrinterConfigCreated" object:name];
    [self selectPrinter:name];
    return YES;
}
+(BOOL)deletePrinter:(NSString *)name {
    if(printerConfigurations.count<2) return NO;
    PrinterConfiguration *dconf = [self findPrinter:name];
    if(dconf==nil) return NO;
    [printerConfigurations removeObject:dconf];
    if(currentPrinterConfiguration==dconf)
        [self selectPrinter:[[printerConfigurations objectAtIndex:0] name]];
    // Update printer list
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:printerConfigurations.count];
    for(PrinterConfiguration *c in printerConfigurations)
        [arr addObject:c->name];
    NSString *list = [StringUtil implode:arr sep:@";"];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:list forKey:@"printerList"];   
    [ThreadedNotification notifyNow:@"RHPrinterConfigRemoved" object:name];
    return YES;
}
-(double)xHomePosition {
    if(homeX == 0) return xMin;
    if(homeX == 1) return xMax;
    return 0;
}
-(double)yHomePosition {
    if(homeY == 0) return yMin;
    if(homeY == 1) return yMax;
    return 0;
}
-(double)zHomePosition {
    if(homeZ == 0) return 0;
    if(homeZ == 1) return (printerType<2 ? height : deltaHeight);
    return 0;
}
-(BOOL)PointInsideX:(float)x Y:(float)y Z:(float) z
{
    if (printerType < 2)
    {
        if (z < -0.001 || z > height) return false;
        if (x < bedLeft || x > bedLeft + width) return false;
        if (y < bedFront || y > bedFront + depth) return false;
    }
    else
    {
        if (z < -0.001 || z > deltaHeight) return false;
        float dist = (float)sqrt(x * x + y * y);
        return dist <= 0.5*deltaDiameter;
    }
    return true;
}

-(NSString*)skeinforgeProfile {
    return [[skeinforgeProfile retain] autorelease];
}
-(void)setSkeinforgeProfile:(NSString*)value {
    [skeinforgeProfile autorelease];
    skeinforgeProfile = [value retain];
    if(importing) return;
    [d setObject:skeinforgeProfile forKey:[self.b stringByAppendingString:@".skeinforgeProfile"]];
}
-(NSString*)slic3rPrint {
    return [[slic3rPrint retain] autorelease];
}
-(void)setSlic3rPrint:(NSString*)value {
    [slic3rPrint autorelease];
    slic3rPrint = [value retain];
    if(importing) return;
    [d setObject:slic3rPrint forKey:[self.b stringByAppendingString:@".slic3rPrint"]];
}
-(NSString*)slic3rPrinter {
    return [[slic3rPrinter retain] autorelease];
}
-(void)setSlic3rPrinter:(NSString*)value {
    [slic3rPrinter autorelease];
    slic3rPrinter = [value retain];
    if(importing) return;
    [d setObject:slic3rPrinter forKey:[self.b stringByAppendingString:@".slic3rPrinter"]];
}
-(NSString*)slic3rFilament1 {
    return [[slic3rFilament1 retain] autorelease];
}
-(void)setSlic3rFilament1:(NSString*)value {
    [slic3rFilament1 autorelease];
    slic3rFilament1 = [value retain];
    if(importing) return;
    [d setObject:slic3rFilament1 forKey:[self.b stringByAppendingString:@".slic3rFilament1"]];
}
-(NSString*)slic3rFilament2 {
    return [[slic3rFilament2 retain] autorelease];
}
-(void)setSlic3rFilament2:(NSString*)value {
    [slic3rFilament2 autorelease];
    slic3rFilament2 = [value retain];
    if(importing) return;
    [d setObject:slic3rFilament2 forKey:[self.b stringByAppendingString:@".slic3rFilament2"]];
}
-(NSString*)slic3rFilament3 {
    return [[slic3rFilament3 retain] autorelease];
}
-(void)setSlic3rFilament3:(NSString*)value {
    [slic3rFilament3 autorelease];
    slic3rFilament3 = [value retain];
    if(importing) return;
    [d setObject:slic3rFilament3 forKey:[self.b stringByAppendingString:@".slic3rFilament3"]];
}
-(int)activeSlicer {
    return activeSlicer;
}
-(void)setActiveSlicer:(int)value {
    activeSlicer = value;
    if(importing) return;
    [d setInteger:activeSlicer forKey:[self.b stringByAppendingString:@".activeSlicer"]];
}
@end

PrinterConfiguration *currentPrinterConfiguration = nil;
NSMutableArray* printerConfigurations = nil;
