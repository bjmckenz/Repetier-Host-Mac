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

#import "SDCardManager.h"
#import "PrinterConnection.h"
#import "StringUtil.h"
#import "RHAppDelegate.h"
#import "GCodeEditorController.h"
#import "GCodeView.h"
#import "ThreadedNotification.h"
#import "ImageAndTextCell.h"

@implementation SDCardFile

-(id)initFile:(NSString*)fname size:(NSString*)sz {
    if((self=[super init])) {
        unichar lastChar = [fname characterAtIndex:fname.length-1];
        unichar firstChar = [fname characterAtIndex:0];
        if(firstChar=='/') fname = [fname substringFromIndex:1];
        fullname = [fname retain];
        isDirectory = lastChar=='/';
        NSArray *parts = [StringUtil explode:fname sep:@"/"];
        filename = [[parts objectAtIndex:parts.count-1] retain];
        filesize = [sz retain];
        if(isDirectory) {
            NSRange last = [[fullname substringToIndex:fullname.length-1] rangeOfString:@"/" options:NSBackwardsSearch];
            if(last.location!=NSNotFound) {
                /*if([filename compare:@".."]==NSOrderedSame) {
                    last = [[fullname substringToIndex:last.location-1] rangeOfString:@"/" options:NSBackwardsSearch];
                }*/
                if(last.location==NSNotFound)
                    dirname = @"";
                else
                    dirname = [[fullname substringToIndex:last.location+1] retain];
            } else
                dirname = [[NSString stringWithFormat:@""] retain];
        } else {
            NSRange last = [fullname rangeOfString:@"/" options:NSBackwardsSearch];
            if(last.location!=NSNotFound)
                dirname = [[fullname substringToIndex:last.location+1] retain];
            else
                dirname = [[NSString stringWithFormat:@""] retain];
        }
    }
    return self;
}
-(void)dealloc {
    [dirname release];
    [fullname release];
    [filename release];
    [filesize release];
    [super dealloc];
}
@end
@implementation SDCardManager

@synthesize folder;

- (id) init {
    if(self = [super initWithWindowNibName:@"SDCard" owner:self]) {
        //  NSLog(@"Window is %l",self.window);
        //[self.window setReleasedWhenClosed:NO];
    }
    return self;
}

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        files = [RHLinkedList new];
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    mainWindow = self.window;
    files = [RHLinkedList new];
    allFiles = [RHLinkedList new];
    folderImage = [[NSImage imageNamed:@"folder16"] retain];
    fileImage = [[NSImage imageNamed:@"file16"] retain];
    folder = @"";
    mounted = YES;
    printing = NO;
    printPaused = NO;
    uploading = NO;
    readFilenames = NO;
    updateFilenames = NO;
    startPrint = NO;
    canRemove = NO;
    printWait = 0;
    waitDelete = 0;
    progress = 0;
    timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self
                                           selector:@selector(timerTick:) userInfo:self repeats:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sdcardStatus:) name:@"RHSDCardStatus" object:nil]; 
    [[NSNotificationCenter defaultCenter] addObserver:self                                             selector:@selector(updateButtons) name:@"RHConnectionOpen" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self                                             selector:@selector(updateButtons) name:@"RHConnectionClosed" object:nil];
    openPanel = [[NSOpenPanel openPanel] retain];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setAllowsMultipleSelection:NO];
    [table setTarget:self];
    [table setDoubleAction:@selector(doubleClick:)];
    [self refreshFilenames];
    [self updateButtons];
}
-(void)dealloc {
    [folderImage release];
    [fileImage release];
    [timer invalidate];
    [files release];
    [allFiles release];
    [super dealloc];
}
- (void)windowDidBecomeMain:(NSNotification *)notification {
    canRemove = connection->isRepetier;
    [self updateButtons];
}
- (BOOL)windowShouldClose:(id)sender {
    [mainWindow orderOut:self];
    return NO;
}
-(void)connected:(NSNotification*)event {
    [self refreshFilenames];
    [self updateButtons];
}
-(void)fillFiles {
    [files clear];
    for(SDCardFile *f in allFiles) {
        if([f->dirname compare:folder]==NSOrderedSame)
            [files addLast:f];
    }
    [table reloadData];
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    return files->count;
}
- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)col row:(NSInteger)rowIndex {
    if(col==filenameColumn) {
        SDCardFile *f = [files objectAtIndex:(int)rowIndex];
        [cell setImage: (f->isDirectory ? folderImage : fileImage)];
        return;
    }
}
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)col row:(NSInteger)rowIndex {
    if(col==filenameColumn) {
       /*ImageAndTextCell *cell = [[ImageAndTextCell alloc] init];
        SDCardFile *f = [files objectAtIndex:(int)rowIndex];
        cell.image = (f->isDirectory ? folderImage : fileImage);
        cell.title = f->filename;
        return [cell autorelease];*/
        return ((SDCardFile*)[files objectAtIndex:(int)rowIndex])->filename;
    }
    return [NSString stringWithFormat:@"%@",((SDCardFile*)[files objectAtIndex:(int)rowIndex])->filesize];
}
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    return NO;
}
- (void)doubleClick:(id)object {
    NSInteger rowNumber = [table clickedRow];
    if(rowNumber<0 || rowNumber>=files->count) return;
    SDCardFile *file = [files objectAtIndex:(int)rowNumber];
    if(file->isDirectory) {
        if([file->filename compare:@".."]==NSOrderedSame) {
            NSRange last = [[file->dirname substringToIndex:file->dirname.length-1] rangeOfString:@"/" options:NSBackwardsSearch];
            if(last.location!=NSNotFound)
                self.folder = [file->dirname substringToIndex:last.location+1];
            else
                self.folder = @"";
        } else {
            self.folder = file->fullname;
        }
        [self fillFiles];
    }
}
- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode
        contextInfo:(void *)contextInfo {
    
    
}

-(void)showInfo:(NSString*)warn headline:(NSString*)head {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:head];
    [alert setInformativeText:warn];
    [alert setAlertStyle:NSInformationalAlertStyle];
    [alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}
-(void)showError:(NSString*)warn headline:(NSString*)head {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:head];
    [alert setInformativeText:warn];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}
-(void)showErrorUpload:(NSString*)warn headline:(NSString*)head {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:head];
    [alert setInformativeText:warn];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert beginSheetModalForWindow:uploadPanel modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

-(void)updateButtons
{
    if (!connection->connected)
    {
        [uploadButton setTag:NO];
        [removeButton setTag:NO];
        [unmountButton setTag:NO];
        [mountButton setTag:NO];
        [startPrintButton setTag:NO];
        [stopPrintButton setTag:NO];
        [newFolderButton setTag:NO];
        [table setEnabled:NO];
        [toolbar validateVisibleItems];
        return;
    }
    [table setEnabled:mounted];
    if(printing) {
        [stopPrintButton setLabel:@"Pause SD Print"];
    } else {
        [stopPrintButton setLabel:@"Stop SD Print"];
    }
    if (uploading || printing || [connection->job hasData])
    {
        [uploadButton setTag:NO];
        [removeButton setTag:NO];
        [unmountButton setTag:NO];
        [mountButton setTag:NO];
        [newFolderButton setTag:NO];
        [startPrintButton setTag:NO];
        [stopPrintButton setTag:mounted];
    }
    else
    {
        canRemove = connection->isRepetier;
        BOOL fc = [table selectedRow]>=0;
        BOOL isfolder = NO;
        if(fc) {
            SDCardFile *f = [files objectAtIndex:(int)table.selectedRow];
            isfolder = (f!=nil && f->isDirectory);
        }
        [uploadButton setTag:mounted];
        [removeButton setTag:fc && mounted && canRemove];
        [unmountButton setTag:YES];
        [mountButton setTag:YES];
        [newFolderButton setTag:mounted];
        [startPrintButton setTag:((!isfolder && fc) || printPaused) && mounted];
        [stopPrintButton setTag:printPaused && mounted];
    }
    [toolbar validateVisibleItems];
    
}
-(void)sdcardStatus:(NSNotification*)event {
    NSString *txt = event.object;
    if(txt!=nil)
       [printStatus setStringValue:txt];
    [progressBar setDoubleValue:progress];
    [self updateButtons];
}
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    [self updateButtons];
}
-(NSString*)reduceSpace:(NSString*)a
{
    NSMutableString *b = [NSMutableString stringWithCapacity:a.length];
    char lastc = 'X';
    for (int i=0;i<a.length;i++)
    {
        char c = [a characterAtIndex:i];
        if (c != lastc || c != ' ')
            [b appendString:[a substringWithRange:NSMakeRange(i,1)]];
        lastc = c;
    }
    return b;
}
-(void)createUpFor:(SDCardFile *)file {
    BOOL hasUp = NO;
    BOOL hasDir = NO; // For Marlin, which doesn't send single dirs
                      //if(file->dirname.length==0) return;
    for(SDCardFile *f in allFiles) {
        if(file->isDirectory) {
            if(f->isDirectory && [f->dirname compare:file->fullname]==NSOrderedSame && [f->filename compare:@".."]==NSOrderedSame)
                hasUp = YES;            
        } else {
            if(f->isDirectory && [f->dirname compare:file->dirname]==NSOrderedSame && [f->filename compare:@".."]==NSOrderedSame)
                hasUp = YES;
            
        }
        if([f->fullname compare:file->dirname]==NSOrderedSame)
            hasDir = YES;
    }
    if(!hasDir && file->dirname.length>0) {
        [allFiles addLast:[[[SDCardFile alloc] initFile:file->dirname size:@""] autorelease]];
    }
    if(!hasUp) {
        if(file->isDirectory)
            [allFiles addLast:[[[SDCardFile alloc] initFile:[NSString stringWithFormat:@"%@../",file->fullname] size:@""] autorelease]];
        else if(file->dirname.length>0)
            [allFiles addLast:[[[SDCardFile alloc] initFile:[NSString stringWithFormat:@"%@../",file->dirname] size:@""] autorelease]];
    }
}
-(void)analyze:(NSString*)res
{
    if (readFilenames)
    {
        if([res rangeOfString:@"End file list"].location==0) {
            readFilenames = NO;
            [self fillFiles];
            return;
        }
        NSString *s = [res stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        s = [[self reduceSpace:s] lowercaseString];
        NSArray *parts = [StringUtil explode:s sep:@" "];
        NSString *len = @"";
        if(parts.count>1) len = [parts objectAtIndex:1];
        SDCardFile *sdf = [[SDCardFile alloc] initFile:[parts objectAtIndex:0] size:len];
        [self createUpFor:sdf];
        [allFiles addLast:sdf];
        [sdf release];
        return;
    }
    if([res rangeOfString:@"Begin file list"].location==0) {
        readFilenames = YES;
        [files clear];
        [allFiles clear];
        return;
    }
    // Printing done?
    if ([res rangeOfString:@"Not SD printing"].location != NSNotFound || [res rangeOfString:@"Done printing file"].location!=NSNotFound)
    {
        printing = NO;
        progress = 100;
        [startPrintButton setLabel:@"Start SD Print"];
        [ThreadedNotification notifyASAP:@"RHSDCardStatus" object:@"Print finished"];
    }
    else if ([res rangeOfString:@"SD printing byte "].location != NSNotFound) // Print status update
    {
        NSRange p = [res rangeOfString:@"SD printing byte "];
        NSString *s = [res substringFromIndex:p.location+17];
        NSArray *s2 = [StringUtil explode:s sep:@"/"];
        if (s2.count == 2)
        {
            double a, b;
            a = [[s2 objectAtIndex:0] doubleValue];
            b = [[s2 objectAtIndex:1] doubleValue];
            [progressBar setDoubleValue:(100 * a / b)];
        }
    }
    else if ([res rangeOfString:@"SD init fail"].location != NSNotFound || [res rangeOfString:@"volume.init failed"].location != NSNotFound ||
             [res rangeOfString:@"openRoot failed"].location!=NSNotFound) // mount failed
    {
        mounted = NO;
    }
    else if ([res rangeOfString:@"error writing to file"].location != NSNotFound) // write error
    {
        [connection->job killJob];
    }
    else if ([res rangeOfString:@"Done saving file"].location != NSNotFound) // save finished
    {
        uploading = NO;
        progress = 100;
        updateFilenames = YES;
        [ThreadedNotification notifyASAP:@"RHSDCardStatus" object:@"Upload finished"];
    }
    else if ([res rangeOfString:@"File selected"].location != NSNotFound)
    {
        progress = 0;
        printing = YES;
        printPaused = NO;
        startPrint = YES;
        [ThreadedNotification notifyASAP:@"RHSDCardStatus" object:@"SD printing ..."];
    }
    else if (uploading && [res rangeOfString:@"open failed, File"].location!=NSNotFound)
    {
        [connection->job killJob];
        connection->analyzer->uploading = NO;
        [ThreadedNotification notifyASAP:@"RHSDCardStatus" object:@"Upload failed"];
    }
    else if ([res rangeOfString:@"File deleted"].location!=NSNotFound)
    {
        waitDelete = 0;
        updateFilenames = YES;
        [ThreadedNotification notifyASAP:@"RHSDCardStatus" object:@"File deleted"];
    }
    else if ([res rangeOfString:@"Deletion failed"].location!=NSNotFound)
    {
        waitDelete = 0;
        [ThreadedNotification notifyASAP:@"RHSDCardStatus" object:@"Delete failed"];
    }
}
-(void)timerTick:(NSTimer*)timer
{
    if (printing && printWait == 0)
    {
        printWait = 2;
        if(![connection hasInjectedMCommand:27])
            [connection injectManualCommand:@"M27"];
    }
    if (printWait <= 0) printWait = 2;
    if (uploading)
    {
        [progressBar setDoubleValue:connection->job.percentDone];
    }
    printWait--;
    if (updateFilenames) [self refreshFilenames];
    if (startPrint)
    {
        startPrint = false;
        [connection injectManualCommand:@"M24"];
    }
    if (waitDelete > 0)
    {
        if (--waitDelete == 0)
        {
            [self showInfo:@"Your firmware doesn't implement file delete or has an unknown implementation." headline:@"Error"];
        }
    }
    [self updateButtons];
}
-(void)refreshFilenames {
    updateFilenames = false;
    [connection injectManualCommand:@"M20"];
    
}
- (void)sdAddDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode
        contextInfo:(void *)contextInfo {
    
}
- (IBAction)uploadAction:(id)sender {
    if ([connection->job hasData])
    {
        [self updateButtons];
        return;
    }
    [NSApp beginSheet: uploadPanel
       modalForWindow: mainWindow
        modalDelegate: self
       didEndSelector: @selector(sdAddDidEnd:returnCode:contextInfo:)
          contextInfo: nil];
}
- (void)removeDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode
        contextInfo:(void *)contextInfo {
    if(returnCode==NSAlertFirstButtonReturn) {
        NSString *fname = ((SDCardFile*)[files objectAtIndex:(int)table.selectedRow])->filename;
        waitDelete = 6;
        [connection injectManualCommand:[NSString stringWithFormat:@"M30 %@%@%@",(folder.length>0?@"/":@""),folder,fname]];
    }
}
- (IBAction)removeAction:(id)sender {
    if (table.selectedRow<0) return;
    NSString *fname = ((SDCardFile*)[files objectAtIndex:(int)table.selectedRow])->filename;
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:@"Yes"];
    [alert addButtonWithTitle:@"No"];
    [alert setMessageText:[NSString stringWithFormat:@"Really delete %@",fname]];
    [alert setInformativeText:@"Security question"];
    [alert setAlertStyle:NSInformationalAlertStyle];
    [alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(removeDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction)startPrintAction:(id)sender {
    if (printPaused)
    {
        [printStatus setStringValue:@"SD printing ..."];
        printing = YES;
        printPaused = NO;
        [connection injectManualCommand:@"M24"];
        [self updateButtons];
        return;
    }
    int idx = (int)table.selectedRow;
    if(idx<0 || idx>=files->count) return;
    SDCardFile *v = [files objectAtIndex:idx];
    [connection injectManualCommand:[NSString stringWithFormat:@"M23 %@%@%@",(folder.length>0?@"/":@""),folder,v->filename]];
    [self updateButtons];
}

- (IBAction)stopPrintAction:(id)sender {
    if (printPaused)
    {
        printPaused = NO;
        [printStatus setStringValue:@"Print aborted"];
        [startPrintButton setLabel:@"Start SD Print"];
        return;
    }
    [connection injectManualCommand:@"M25"];
    printPaused = YES;
    printing = NO;
    [printStatus setStringValue:@"Print paused"];
    [startPrintButton setLabel:@"Continue SD Print"];
    [self updateButtons];
}

- (IBAction)mountAction:(id)sender {
    [connection injectManualCommand:@"M21"];
    mounted = YES;
    self.folder = @"";
    [self refreshFilenames];
    [self updateButtons];
}

- (IBAction)unmountAction:(id)sender {
    [connection injectManualCommand:@"M22"];
    mounted = NO;
    [files clear];
    [table reloadData];
    [self showInfo:@"You can remove the sd card." headline:@"Information"];
    [self updateButtons];
}
-(BOOL)validFilename:(NSString*)t
{
    BOOL ok = YES;
    //box.Text = box.Text.ToLower();
    if (t.length > 12 || t.length == 0) ok = NO;
    NSRange p = [t rangeOfString:@"."];
    if (p.location!=NSNotFound && p.location>8) ok = NO;
        
    int i;
    for (i = 0; i < t.length; i++)
    {
        if (i == p.location) continue;
        char c = [t characterAtIndex:i];
        BOOL cok = NO;
        if (c >= '0' && c <= '9') cok = YES;
        else if (c >= 'a' && c <= 'z') cok = YES;
        else if (c == '_' || c=='(' || c==')' || c=='-') cok = YES;
        if (!cok)
        {
            ok = NO;
            break;
        }
    }
    if(!ok)
        [self showErrorUpload:@"Target name is not a valid 8.3 filename. Only 0-9, a-z and _ are allowed." headline:@"Wrong target filename"];
    return ok;
}
- (IBAction)uplBrowseExternalFile:(id)sender {
    [openPanel setMessage:@"Select gcode file for upload"];
    [openPanel beginSheetModalForWindow:uploadPanel completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSArray* urls = [openPanel URLs];
            if(urls.count>0) {
                NSURL *url = [urls objectAtIndex:0];
                [uplExternalFilenameText setStringValue:url.path];
            }
        }        
    }];
}
- (BOOL)upload:(int)source {
    NSError *error = NULL;
    NSRegularExpression *regex = [NSRegularExpression
                                  regularExpressionWithPattern:@"[a-z0-9_()-]{1,8}([.][a-z0-9_()-]{1,3})?$"
                                  options:0
                                  error:&error];
    NSRange filenameLoc = [regex rangeOfFirstMatchInString:uplFilenameText.stringValue
                                                   options:0
                                                     range:NSMakeRange(0, [[uplFilenameText stringValue] length])];
    if (NSEqualRanges(filenameLoc, NSMakeRange(NSNotFound, 0)))
    {
        [self showErrorUpload:@"Target name is not a valid 8.3 filename. Only 0-9, a-z and _ are allowed." headline:@"Invalid target filename"];
        return NO;
    }
    RHPrintjob *job = connection->job;
    [printStatus setStringValue:@"Uploading file ..."];
    [progressBar setIndeterminate:NO];
    [progressBar setDoubleValue:0];
    [job beginJob];
    job->exclusive = YES;
    [job pushData:[NSString stringWithFormat:@"M28 %@%@%@",(folder.length>0?@"/":@""),folder,[uplFilenameText stringValue]]];
    if([uplIncludeStartEndCheckbox state])
        [job pushShortArray:app->gcodeView->prepend->textArray];
    if (source==0)
    {
        [job pushShortArray:app->gcodeView->gcode->textArray];
    }
    else
    {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *path = uplExternalFilenameText.stringValue;
        BOOL fileExists = [fm fileExistsAtPath:path] ;
        if (!fileExists) {
            job->exclusive = NO;
            [job beginJob];
            [job endJob ];
            [self showErrorUpload:@"File not found." headline:@"Error"];
            return NO;
        }
        NSError *err = nil;
        [job pushData:[NSString stringWithContentsOfFile:path encoding:NSISOLatin1StringEncoding error:&err]];
        if(err && err.code) {
            job->exclusive = NO;
            [job beginJob];
            [job endJob ];
            [self showErrorUpload:@"Error loading file." headline:@"Error"];
            return NO;
        }
    }
    if ([uplIncludeStartEndCheckbox state])
        [job pushShortArray:app->gcodeView->append->textArray];
    if ([uplIncludeJobEndCheckbox state])
    {
        if (currentPrinterConfiguration->afterJobDisableExtruder)
        {
            for(int i=0;i<currentPrinterConfiguration->numberOfExtruder;i++)
                [job pushData:[NSString stringWithFormat:@"M104 S0 T%d",i]];
        }
        if (currentPrinterConfiguration->afterJobDisableHeatedBed)
             [job pushData:@"M140 S0"];
        if (currentPrinterConfiguration->afterJobGoDispose)
        {
            [job pushData:@"G90"];
            [job pushData:[NSString stringWithFormat:@"G1 X%.2f Y%.2f F%.2F",currentPrinterConfiguration->disposeX,currentPrinterConfiguration->disposeY,currentPrinterConfiguration->travelFeedrate]];
        }
    }
    [job pushData:@"M29"];
    [job endJob];
    uploading = YES;
    return YES;
}
- (IBAction)uplUploadGCodeAction:(id)sender {
    if(![self upload:0]) return;
    [NSApp endSheet:uploadPanel];
    [uploadPanel orderOut:self];
}

- (IBAction)uplUploadExternalFileAction:(id)sender {
    if(![self upload:1]) return;
    [NSApp endSheet:uploadPanel];
    [uploadPanel orderOut:self];
}

- (IBAction)uplCancelAction:(id)sender {
    [NSApp endSheet:uploadPanel];
    [uploadPanel orderOut:self];
}

- (IBAction)createNewFolder:(id)sender {
    NSString *cname = [[newFolderName stringValue] lowercaseString];
    cname = [StringUtil replaceIn:cname all:@";" with:@"_"];
    cname = [StringUtil replaceIn:cname all:@"." with:@"_"];
    [NSApp endSheet:createFolderPanel];
    [createFolderPanel orderOut:self];
    if(cname.length==0)
        [self showError:@"No folder name entered." headline:@"New folder failed"];
    else if(![self validFilename:cname])
        [self showError:@"Folder name is not in 8.3 format." headline:@"New folder failed"];
    else {
        [connection injectManualCommand:[NSString stringWithFormat:@"M32 %@%@%@",(folder.length>0?@"/":@""),folder,cname]];
        [self refreshFilenames];
    }
}

- (IBAction)cancelNewFolder:(id)sender {
    [NSApp endSheet:createFolderPanel];
    [createFolderPanel orderOut:self];
}
- (IBAction)newFolderAction:(id)sender {
    [NSApp beginSheet: createFolderPanel
       modalForWindow: mainWindow
        modalDelegate: self
       didEndSelector: @selector(alertDidEnd:returnCode:contextInfo:)
          contextInfo: nil];}
@end
