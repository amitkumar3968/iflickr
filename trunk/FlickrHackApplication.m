/*
 
 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; version 2
 of the License.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 
 */


#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <GraphicsServices/GraphicsServices.h>
#import <UIKit/UITransformAnimation.h>
#import <UIKit/UIAnimator.h>
#import <PhotoLibrary/DCFFileGroup.h>
#import <PhotoLibrary/DCFDirectory.h>
#import "PhotoLibrary.h"
#import "FlickrHackApplication.h"

#include "md5.h"
#include <math.h>
#include <stdio.h>
#include <string.h>
#include <dlfcn.h>



#include "jpeg/jinclude.h"
#include "jpeg/jpeglib.h"


#define PREF_FILE @"/var/root/Library/Preferences/com.googlecode.iflickr.plist"
#define DCIM_PATH  @"/private/var/root/Media/DCIM/100APPLE/"

NSString* POSTDataSeparator = @"---------------------------8f999edae883c6039b244c0d341f45f8";

int GSEventDeviceOrientation(GSEvent *ev);
CGImageRef CreateCGImageFromData(NSData* data);

static CGColorSpaceRef color_space = 0;

static NSRecursiveLock* lock = 0;

/*
	Magic global variables for CoreTelephony.
*/
struct CellInfo cellinfo;
int i;
int tl;

/* End magic globals. */

void make_JPEG (char * data, long* length,
				int quality, JSAMPLE* image_buffer_bad, 
				int image_width, int image_height);

int callback(void *connection, CFStringRef string, CFDictionaryRef dictionary, void *data);
void sourcecallback ( CFMachPortRef port, void *msg, CFIndex size, void *info);
void mycallback (void);

@implementation FlickrHackApplication

- (void) applicationSuspend:(struct __GSEvent *) event {
	[self setApplicationBadge:[NSString stringWithFormat:@"%d", uploadQSize]];
		if( uploadQSize <= 0)
		[self terminateWithSuccess];
}

- (void) applicationResume:(struct __GSEvent *) event {
	//[self setApplicationBadge:@"resumed"];
}

- (BOOL) applicationIsReadyToSuspend {
	return NO;
}

- (BOOL) suspendRemainInMemory {
	return YES;
}

- (void) applicationWillTerminate {
	[self removeApplicationBadge];
	window = [[UIWindow alloc] initWithContentRect: [UIHardware fullScreenApplicationContentRect] ];
	[window release];

}

- (void) didReceiveMemoryWarning {
	
}

- (void) didReceiveUrgentMemoryWarning {
	
}

- (void)deviceOrientationChanged:(struct __GSEvent *)fp8
{
	/*
	int currentRotation = [UIHardware deviceOrientation:YES];
	NSString* str = [NSString stringWithFormat:@"%d", currentRotation];
				[alertSheet setBodyText:str];
	[alertSheet popupAlertAnimated:YES];
	*/
}

-(void)cameraController:(id)sender tookPicture:(UIImage*)picture withPreview:(UIImage*)preview jpegData:(NSData*)jpeg imageProperties:(NSDictionary *)exif
{
	//NSAutoreleasePool* pool = [NSAutoreleasePool new];
	{
		NSLog(@"Took a picture callback\n");		
		if (preview && [preview imageRef])
		{
			NSLog(@"Token from prefs : %s\n", [token UTF8String]);
			[lock lock];
			uploadQSize++;
			[lock unlock];
			
			if(![_navBar containsView:status])
			{
				[_navBar addSubview:status];
			}
			[status setText:[NSString stringWithFormat:@"Sending %d pics", uploadQSize]];
			[progress startAnimation];
			[NSThread detachNewThreadSelector:@selector(flickrUploadPic:) toTarget:self withObject:jpeg];
			
			if(mStorePic && !isCCM)
			{				
				NSString* fileName = [self getNextFileNumberFromPhotoLibrary];
				
				[self compressImage:(void*)CGImageCreateCopy([preview imageRef]) withFilename:fileName ];
				
				NSString *imageFileName = [NSString stringWithFormat:@"/var/root/Media/DCIM/100APPLE/%@.JPG", fileName];
				
				[(NSData*)jpeg writeToFile:imageFileName atomically:TRUE];
			}
		}		
	}
	//[pool release];
}

-(NSString*)getNextFileNumberFromPhotoLibrary
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if ([fileManager fileExistsAtPath:DCIM_PATH] == NO) {
		NSLog(@"No directory eists\n");
		return nil;
	}
	
	NSString *file;
	NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath: DCIM_PATH];
	NSMutableArray *sortedArray = [[NSMutableArray alloc] init];
	
	while (file = [dirEnum nextObject]) {
		char *fn = [file cStringUsingEncoding: NSASCIIStringEncoding];
		if (!strcasecmp(fn + (strlen(fn)-4), ".JPG"))
		{
			NSLog(@"Got a file %@\n", file);
			[sortedArray addObject:file];
		}
	}
	[sortedArray sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	
	int last = [[[[[[sortedArray  objectAtIndex:([sortedArray count] -1)] componentsSeparatedByString:@"_"] objectAtIndex:1]componentsSeparatedByString:@"."] objectAtIndex:0] intValue];
	NSLog(@"Last one is %d\n", last);
	
	[sortedArray release];
	
	NSString* next = [NSString  stringWithFormat:@"IMG_%04d", last+1];
	NSLog(@"Next one %@\n", next);
	return next;
				
}

static void CRDrawSubImage (CGContextRef context, CGImageRef image, CGRect src, CGRect dst)
{
    int w = CGImageGetWidth(image);
    int h = CGImageGetHeight(image);
    CGRect drawRect = CGRectMake (0, 0, w, h);
	
    if (!CGRectEqualToRect (src, dst)) 
    {
        float sx = CGRectGetWidth(dst) / CGRectGetWidth(src);
        float sy = CGRectGetHeight(dst) / CGRectGetHeight(src);
        float dx = CGRectGetMinX(dst) - (CGRectGetMinX(src) * sx);
        float dy = CGRectGetMinY(dst) - (CGRectGetMinY(src) * sy);
        drawRect = CGRectMake (dx, dy, w*sx, h*sy);
    }
	
    CGContextSaveGState (context);// 3
		CGContextClipToRect (context, dst);// 4
			CGContextDrawImage (context, drawRect, image);// 5
				CGContextRestoreGState (context);
}

-(void)compressImage:(CGImageRef)jpeg withFilename:(NSString*)filename
{
	//NSAutoreleasePool* pool = [NSAutoreleasePool new];
	
	[lock lock];
	
	CGImageRef image;
    CGDataProviderRef provider;
    CFStringRef path;
	
	CGRect myImageArea = CGRectMake (0.0,0.0, IMAGE_WIDTH,IMAGE_HEIGHT);
	static char* data = 0;
	if (!data)
		data = (char*)malloc(IMAGE_HEIGHT * IMAGE_WIDTH * 4);
	
	static CGContextRef context = 0;
	
	if (!context)
		context = CGBitmapContextCreate(
										data,
										IMAGE_WIDTH,
										IMAGE_HEIGHT,
										8,
										IMAGE_WIDTH * 4,
										color_space,
										kCGImageAlphaPremultipliedFirst);
	
	CGContextSaveGState(context);
	
	
	CGContextDrawImage(context,	myImageArea,  jpeg);
	
	CGContextRestoreGState(context);
	
	static unsigned char* JPEGdata = 0;
	if (!JPEGdata)
		JPEGdata = (unsigned char*)malloc(0x100000);
	
	long jpegLength = 0;
	make_JPEG ((char*)JPEGdata, &jpegLength,
			   33 /*quality*/, (JSAMPLE*) data, 
			   IMAGE_WIDTH, IMAGE_HEIGHT);
	
	CGImageRelease (jpeg);
	
	//[self setText:[NSString stringWithFormat:@"length: %d", jpegLength]]; 
	
	CFDataRef temp = CFDataCreateWithBytesNoCopy (0, JPEGdata, jpegLength, kCFAllocatorNull);
	
	if(temp) {
		NSLog(@"Created a jpeg and made dataref\n");
	}
	NSString *thumbNailFileName = [NSString
					stringWithFormat:@"/var/root/Media/DCIM/100APPLE/%@.THM", filename];
				
	[(NSData*)temp writeToFile:thumbNailFileName atomically:TRUE];
	
	if(temp)
		CFRelease(temp);
	
	
	[lock unlock];
	
	//[pool release];
}


-(void)takePicture:(id)sender
{
	/*
	int currentRotation = [UIHardware deviceOrientation:YES];
	NSString* str = [NSString stringWithFormat:@"%d", currentRotation];
	[alertSheet setBodyText:str];
	[alertSheet popupAlertAnimated:YES];
	return;
	*/			
				//NSAutoreleasePool* pool = [NSAutoreleasePool new];
				{
					NSLog(@"Took a picture\n");
					NSLog(@"isCCM = %d\n", isCCM);
					
					[imageview _playShutterSound];
					[ camController capturePhoto];
				}
				//[pool release];
}

-(void)startTakePicture:(id)sender
{
	isCCM = TRUE;
	[imageview _playShutterSound];

}

-(void)stopTakePicture:(id)sender
{
	isCCM = FALSE;
	[imageview _playShutterSound];

}
- (BOOL) shouldShoot
{
	return isCCM;
}

-(void)takeContinuousPicPicture:(id)sender
{
	if([self shouldShoot])
	{
		NSLog(@"Took a ccm picture\n");
		[ camController capturePhoto];
	}
}

- (void)cameraControllerReadyStateChanged:(id)fp8
{
	//	[self setText:@"ready state changed"];
}

- (id) createButton:(NSString *)name
{
	UIPushButton *button =
	[[UIPushButton alloc] initWithFrame: CGRectMake(130.0f, 410.0f, 100.0f, 60.0f)];
	NSString *onFile = [NSString
                stringWithFormat:@"/Applications/iFlickr.app/play.gif"];
	UIImage* on = [[UIImage alloc] initWithContentsOfFile: onFile];
	[button setImage:on forState:1];
	NSString *offFile = [NSString
                stringWithFormat:@"/Applications/iFlickr.app/play.gif"];
	UIImage* off = [[UIImage alloc] initWithContentsOfFile: offFile];
	[button setImage:off forState:0];
	[button setEnabled:YES];
	[button setDrawContentsCentered:YES];
	[button setAutosizesToFit:NO];
	[button setNeedsDisplay];
	[button addTarget:self action:@selector(takePicture:) forEvents:255];
	[on release];
	[off release];
	return button;
}

- (id) createStopButton:(NSString *)name
{
	UIPushButton *button =
	[[UIPushButton alloc] initWithFrame: CGRectMake(270.0f, 420.0f, 100.0f, 60.0f)];
	NSString *onFile = [NSString
                stringWithFormat:@"/Applications/iFlickr.app/stop.gif"];
	UIImage* on = [[UIImage alloc] initWithContentsOfFile: onFile];
	[button setImage:on forState:1];
	NSString *offFile = [NSString
                stringWithFormat:@"/Applications/iFlickr.app/stop.gif"];
	UIImage* off = [[UIImage alloc] initWithContentsOfFile: offFile];
	[button setImage:off forState:0];
	[button setEnabled:YES];
	[button setDrawContentsCentered:YES];
	[button setAutosizesToFit:NO];
	[button setNeedsDisplay];
	[button addTarget:self action:@selector(stopTakePicture:) forEvents:255];
	[on release];
	[off release];
	return button;
}

- (id) createPlayButton:(NSString *)name
{
	UIPushButton *button =
	[[UIPushButton alloc] initWithFrame: CGRectMake(50.0f, 410.0f, 100.0f, 60.0f)];
	NSString *onFile = [NSString
                stringWithFormat:@"/Applications/iFlickr.app/play.gif"];
	UIImage* on = [[UIImage alloc] initWithContentsOfFile: onFile];
	[button setImage:on forState:1];
	NSString *offFile = [NSString
                stringWithFormat:@"/Applications/iFlickr.app/play.gif"];
	UIImage* off = [[UIImage alloc] initWithContentsOfFile: offFile];
	[button setImage:off forState:0];
	[button setEnabled:YES];
	[button setDrawContentsCentered:YES];
	[button setAutosizesToFit:NO];
	[button setNeedsDisplay];
	[button addTarget:self action:@selector(startTakePicture:) forEvents:255];
	[on release];
	[off release];
	return button;
}

- (void) applicationDidFinishLaunching: (id) unused
{
	NSLog(@"Application finished lauching\n");	
	
	[self initlocation];
	
	// hide status bar
	[self setStatusBarMode:2 duration:0];
	
	if (!lock)
		lock = [NSRecursiveLock new];
		
	mDeviceRotation = 0;
	mCurrentRotation = -90;
	uploadQSize = 0;
	
	color_space = CGColorSpaceCreateDeviceRGB();
	
	window = [[UIWindow alloc] initWithContentRect: [UIHardware
		fullScreenApplicationContentRect]];
	
	imageview = [[CameraView alloc] initWithFrame: CGRectMake(0.0f, -20.0f,
															  320.f, 320.f)];	
	camController = [CameraController sharedInstance] ;
	[camController startPreview];
	[[CameraController sharedInstance] setDelegate:self];
	
	picButton = [self createButton:@"SNAP"];
	[picButton setEnabled:FALSE];
	
	stopButton = [self createStopButton:@"STOP"];
	playButton = [self createPlayButton:@"PLAY"];

	
	alertSheet = [[UIAlertSheet alloc]initWithFrame: 
		CGRectMake(0, 240, 320, 240) ];
	[alertSheet setDelegate:self];
	[alertSheet addButtonWithTitle:@"OK" ];
	
	_pref    = [ self createPrefPane ];
	_navBar = [ self createNavBar ];
	_currentView = CUR_BROWSER;
	[ self setNavBar ];
	
	[window orderFront: self];
	[window makeKey: self];
	[window _setHidden: NO];
	
	struct CGRect rect = [UIHardware fullScreenApplicationContentRect];
	
	rect.origin.x = rect.origin.y = 0.0f;
	
	mainView = [[UIView alloc] initWithFrame: rect];
	
	progress = [[UIProgressIndicator alloc] initWithFrame: CGRectMake(160,220, 20,20)];
	[progress setStyle:0];
	[progress retain];
	
	status = [[UITextLabel alloc] initWithFrame: CGRectMake(0,20, 200,20)];
	[status setEnabled:TRUE];
	[status setText:@""];
	
	[mainView addSubview: imageview];
	[mainView addSubview: picButton];
	[mainView addSubview: _navBar];
	[_navBar addSubview:progress];

	[self loadPreferences];

    _saveCell = [[UIPreferencesTableCell alloc] init];
	saveLocally = [[UISwitchControl alloc] initWithFrame: CGRectMake(320 - 114.0f, 9.0f, 296.0f - 200.0f, 32.0f)];
	[saveLocally setValue:mStorePic];
	[ _saveCell setTitle:@"Save on iPhone " ];
	[_saveCell addSubview:saveLocally];


    _privacyCell = [[UIPreferencesTableCell alloc] init];
	isPrivate = [[UISwitchControl alloc] initWithFrame: CGRectMake(320 - 114.0f, 9.0f, 296.0f - 200.0f, 32.0f)];
	[isPrivate setValue:mIsPrivate];
	[ _privacyCell setTitle:@"Private " ];
	[_privacyCell addSubview:isPrivate];
	
    _continuousCell = [[UIPreferencesTableCell alloc] init];
	continuousShoot = [[UISliderControl alloc] initWithFrame: CGRectMake(320 - 114.0f, 9.0f, 296.0f - 200.0f, 32.0f)];
	[continuousShoot setMinValue:2.0f];
	[continuousShoot setMaxValue:20.0f];
	
	[continuousShoot setValue:mShootContinuously];
	[ _continuousCell setTitle:@"Continuous shoot rate" ];
	[_continuousCell addSubview:continuousShoot];
	
	tagCell = [[UIPreferencesTextTableCell alloc]  init];
	[ tagCell setTitle:@"Tags" ];
	[[tagCell textField] setText:tags];

	miniToken = [[UIPreferencesTextTableCell alloc]  initWithFrame:CGRectMake(170.0f, 100.0f, 120.0f, 20.0f)];
	[ miniToken setTitle:@"Minitoken" ];

	isCCM = FALSE;

	[NSTimer scheduledTimerWithTimeInterval:mShootContinuously target:self selector:@selector(takeContinuousPicPicture:) userInfo:0 repeats:YES];
	
	NSLog(@"Token from prefs : %s\n", [token UTF8String]);
	
	[window setContentView: mainView]; 
	
}

- (void)loadPreferences {
	if ([[NSFileManager defaultManager] isReadableFileAtPath: PREF_FILE])
	{
		NSDictionary* settingsDict = [NSDictionary dictionaryWithContentsOfFile: PREF_FILE];
		NSEnumerator* enumerator = [settingsDict keyEnumerator];
		NSString* currKey;
		while (currKey = [enumerator nextObject])
		{					
			if ([currKey isEqualToString: @"token"])
			{
				token = [[NSString alloc] initWithString:[settingsDict valueForKey: currKey]];
				NSLog(@"Token from prefs : %s\n", [token UTF8String]);
				[picButton setEnabled:TRUE];
			}
			if ([currKey isEqualToString: @"minitoken"])
			{
				minitoken = [[NSString alloc] initWithString:[settingsDict valueForKey: currKey]];
			}
			if ([currKey isEqualToString: @"userid"])
			{
				userid = [[NSString alloc] initWithString:[settingsDict valueForKey: currKey]];
			}
			if ([currKey isEqualToString: @"continuousShoot"])
			{
				mShootContinuously = [[settingsDict valueForKey: currKey] floatValue];
			}
			if ([currKey isEqualToString: @"storelocally"])
			{
				mStorePic = [[settingsDict valueForKey: currKey] isEqualToString:@"0"] ? FALSE:TRUE;
			}
			if ([currKey isEqualToString: @"tags"])
			{
				tags = [[NSString alloc] initWithString:[settingsDict valueForKey: currKey]];
				NSLog(@"tags from prefs : %s\n", [tags UTF8String]);
			}
			if ([currKey isEqualToString: @"saveprivate"])
			{
				mIsPrivate = [[settingsDict valueForKey: currKey] isEqualToString:@"0"] ? FALSE:TRUE;
			}

			
			if(mShootContinuously > 2.0f)
			{
				[alertSheet setBodyText:[NSString stringWithFormat:@"Continuous mode is set! Will send pictures at rate of 1 per %2.0f secs", mShootContinuously]];
				[alertSheet popupAlertAnimated:YES];
				[stopButton setEnabled:TRUE];
				[mainView addSubview:stopButton];
				[playButton setEnabled:TRUE];
				[mainView addSubview:playButton];
				[picButton removeFromSuperview];

				isCCM = TRUE;
			}
			else 
			{
				[stopButton setEnabled:FALSE];				
				[ stopButton removeFromSuperview];	
				[playButton removeFromSuperview];	
				[mainView addSubview:picButton];
		
				isCCM = FALSE;				
			}
			
			
		}
		[_pref reloadData];
	}
}



- (void)savePreferences {
	
    //NSLog(@"savePreferences: _currentView %d, minitoken = %s in memorey (%s) \n", _currentView, [[[miniToken textField] text] UTF8String], [minitoken UTF8String]);
	
	if([[miniToken textField] text])
	{
		NSString* s = [[miniToken textField] text];
		
		if(![s isEqualToString:minitoken])
		{
			NSLog(@"%@ == %@\n", s, minitoken);
			//return;
			
			[self getFullToken:[[miniToken textField] text]];
			
		}
		
		NSLog(@"Store pics %f\n", [saveLocally value]);
		NSLog(@"Continuous mode pics %f\n", [continuousShoot value]);
		
		mShootContinuously = [continuousShoot value];
		mStorePic = ([saveLocally value] == 1 ? TRUE : FALSE);
		mIsPrivate = ([isPrivate value] == 1 ? TRUE : FALSE);

		
		NSString* shootContinuously = [NSString stringWithFormat:@"%f", mShootContinuously];
		NSString* storePics = (mStorePic == FALSE ? @"0" : @"1");
		NSString* savePrivate = (mIsPrivate == FALSE ? @"0" : @"1");
		
		//Build settings dictionary
		NSDictionary* settingsDict = [[NSDictionary alloc] initWithObjectsAndKeys:
			token, @"token",
			[[miniToken textField] text], @"minitoken",
			userid, @"userid",
			storePics, @"storelocally",
			shootContinuously, @"continuousShoot",
			[[tagCell textField] text], @"tags",
			savePrivate, @"saveprivate",
			nil];
	
		NSLog(@"saving dictionary %@\n", storePics);
		
		//Seralize settings dictionary
		NSString* error;
		NSData* rawPList = [NSPropertyListSerialization dataFromPropertyList: settingsDict		
																	  format: NSPropertyListXMLFormat_v1_0
															errorDescription: &error];
		
		//Write settings plist file
		[rawPList writeToFile: PREF_FILE atomically: YES];
		
			if(mShootContinuously > 2.0f)
			{
				[alertSheet setBodyText:[NSString stringWithFormat:@"Continuous mode is set! Will send pictures at rate of 1 per %2.0f secs", mShootContinuously]];
				[alertSheet popupAlertAnimated:YES];
				[stopButton setEnabled:TRUE];
				[mainView addSubview:stopButton];
				[playButton setEnabled:TRUE];
				[mainView addSubview:playButton];
				[picButton removeFromSuperview];

				isCCM = TRUE;
			}
			else 
			{
				[stopButton setEnabled:FALSE];				
				[ stopButton removeFromSuperview];	
				[playButton removeFromSuperview];
				[mainView addSubview:picButton];
				isCCM = FALSE;				
			}

		[settingsDict release];
	}
	return;
}

- (void)alertSheet:(UIAlertSheet*)sheet buttonClicked:(int)button
{
	if ( button == 1 )
		NSLog(@"Yes");
	else if ( button == 2 )
		NSLog(@"No");
	
	[sheet dismiss];
}

- (UIPreferencesTable *)createPrefPane {
    float offset = 0.0;
	
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    float whiteComponents[4] = {1, 1, 1, 1};
    float transparentComponents[4] = {0, 0, 0, 0};
	
    UIPreferencesTable *pref = [[UIPreferencesTable alloc] initWithFrame:
		CGRectMake(0, 28, 320, 480-100)];
    [ pref setDataSource: self ];
    [ pref setDelegate: self ];
	
    UITextLabel *versionText = [[UITextLabel alloc] initWithFrame:
		CGRectMake(15.0f, 300.0f, 100.0f, 20.0f)];
    [ versionText setText:@"0.0.5"];
    [ versionText setBackgroundColor:
		CGColorCreate(colorSpace, transparentComponents)];
    [ pref addSubview:versionText ];
    [ pref reloadData ];
    return pref;
}

- (void)setNavBar {

	NSLog(@"_currentView = %d\n", _currentView);
	
    switch (_currentView) {
        case (CUR_PREFERENCES):
            [_navBar showButtonsWithLeftTitle:@"Back"
								   rightTitle:@"Authorize" leftBack: YES
				];
            break;
			
        case (CUR_BROWSER):
			[_navBar showButtonsWithLeftTitle:nil
								   rightTitle:@"Preferences" leftBack: NO
                ];
            break;
			
    }
}

- (int)numberOfGroupsInPreferencesTable:(UIPreferencesTable *)aTable {
	return 1;
}

- (int)preferencesTable:(UIPreferencesTable *)aTable
    numberOfRowsInGroup:(int)group
{
	if (group == 0) return 6;
}

- (UIPreferencesTableCell *)preferencesTable:(UIPreferencesTable *)aTable
								cellForGroup:(int)group
{
	UIPreferencesTableCell * cell = [[UIPreferencesTableCell alloc] init];
	return [cell autorelease];
}

- (float)preferencesTable:(UIPreferencesTable *)aTable
			 heightForRow:(int)row
				  inGroup:(int)group
	   withProposedHeight:(float)proposed
{
    if (group == 0) {
        switch (row) {
            case 0 :
                return 30;
                break;
        }
    } 
    return proposed;
}

- (BOOL)preferencesTable:(UIPreferencesTable *)aTable
			isLabelGroup:(int)group
{
    return NO;
}

- (UIPreferencesTableCell *)preferencesTable:(UIPreferencesTable *)aTable
								  cellForRow:(int)row
									 inGroup:(int)group
{
    UIPreferencesTableCell * cell = [[UIPreferencesTableCell alloc] init];
    [ cell setEnabled: YES ];
    if (group == 0) {
        switch (row) {
            case (0):
				if(!minitoken)
				{
					[[miniToken textField] setText:@"Enter minitoken, click on Auth"];
				}
				else 
				{
					[[miniToken textField] setText:minitoken];
				}
				return miniToken ;
				break;
			case (1):
                [ cell setTitle:[NSString stringWithFormat:@"User : %@", userid]];
                break;
            case (2):
				return _saveCell;
                break;
            case (3):
				return _continuousCell;
                break;
			case (4):		
				if(!tags)
				{
					[[tagCell textField] setText:@""];
				}
				else 
				{
					[[tagCell textField] setText:tags];
				}
				return tagCell;
				break;
			case (5):
				return _privacyCell;
                break;
		}
    }
    return [cell autorelease];
}

- (void) handleSlider: (id) whatever
{
    NSLog(@"End Value: %d", [continuousShoot value]);
}

- (UINavigationBar *)createNavBar {
    float offset = 48.0;
    UINavigationBar *navBar = [[UINavigationBar alloc] initWithFrame:
        CGRectMake(0.0f,-20.0f, 320.0f, 48.0f)
		];
	
    [navBar setDelegate: self];
    [navBar enableAnimation];
	
    return navBar;
}


- (void)navigationBar:(UINavigationBar *)navbar buttonClicked:(int)button {
	NSLog(@"Button (%d) _currentView (%d)\n", button, _currentView);
	
    switch (button) {
		
        /* Left Navigation Button */
		
        case 1:
            switch (_currentView) {
				
                case CUR_PREFERENCES:
					
                    [ self savePreferences ];
                    _currentView = CUR_BROWSER;
					if([mainView containsView:imageview]) {
						break;
					}
					[_pref removeFromSuperview];
					[mainView addSubview: imageview];
					[mainView addSubview: _navBar];
					[picButton setEnabled:TRUE];
                    break;
					
                case CUR_BROWSER:
					_currentView = CUR_PREFERENCES;
                    break;
					
            }
            break;
			
			/* Right Navigation Button */
        case 0:
            switch (_currentView) {
				
                case CUR_BROWSER:
					if([mainView containsView:_pref]) {
						break;
					}
                    _currentView = CUR_PREFERENCES;

					[imageview removeFromSuperview];
					[mainView addSubview: _pref];
					[mainView addSubview: _navBar];
					[picButton setEnabled:FALSE];
					
                    break;
				case CUR_PREFERENCES:
				{
					NSLog(@"Opening flickr url\n");
					NSURL *url;
					url = [[NSURL alloc] initWithString:@"http://www.flickr.com/auth-72157601777151481"];
					[self openURL:url];	
					[url release];	
					break;
				}
					
            }
            break;
    }
	
    [ self setNavBar ];
}


- (void)getFlickrData:(NSXMLElement*) e
{
	NSArray *children = [e children];
	int i, count = [children count];
	
	NSXMLNode *stat =[e attributeForName:@"stat"];
	NSLog(@"return (%@)\n", [stat stringValue]);
	if (![[stat stringValue] isEqualToString:@"ok"]) 
	{
		return;		
	}
	
	NSXMLNode *auth = [children objectAtIndex:0];
	
	if(auth)
	{
		NSArray *children = [auth children];
		int i, count = [children count];
		for (i=0; i < count; i++) {
			NSXMLElement *child = [children objectAtIndex:i];
			if([[child name] isEqualToString:@"token"]) {
				NSLog(@"Token (%@)\n", [child stringValue]);
				token = [child stringValue];
			}
			if([[child name] isEqualToString:@"user"]) {
				NSArray *attribs = [child attributes];
				int j, ac = [attribs count];
				
				for (j=0; j < ac; j++) {
					NSXMLElement *a = [attribs objectAtIndex:j];
					NSLog(@"Attribs Name (%@) : Value (%@) \n", [a name], [a stringValue]);
					
					if([[a name] isEqualToString:@"username"])
					{
						userid = [a stringValue];
					}
					
				}
			}
			
		}
	}
	return;
	
}

-(int) rotatePicture:(NSString*) pictureid degrees:(NSString*) deg
{
	NSString* method=@"flickr.photos.transform.rotate";
	
	NSMutableDictionary *newparam=[[NSMutableDictionary alloc] init];
	[newparam setObject:method forKey:@"method"];
	[newparam setObject:@API_KEY forKey:@"api_key"];
	[newparam setObject:pictureid forKey:@"photo_id"];
	[newparam setObject:deg forKey:@"degrees"];
	[newparam setObject:token forKey:@"auth_token"];
	
	NSString* param = signatureForCall(newparam);
	NSLog(@"%@", param);
	
	NSString* rsp = flickrApiCall(param);		
	NSLog(@"Response is (%@)\n", rsp);
	if(rsp) 
	{
		int errcode = 0;
        id errmsg = nil;
        BOOL err = NO;
		
        NSXMLDocument *xmlDoc = [[NSClassFromString(@"NSXMLDocument") alloc] initWithXMLString:rsp options:NSXMLDocumentXMLKind error:&errmsg];
		NSXMLNode *stat =[[xmlDoc rootElement] attributeForName:@"stat"];
		NSLog(@"return (%@)\n", [stat stringValue]);
				
		if([[stat stringValue] isEqualToString:@"ok"])
		{
			return 1;
		}
		else
		{
			return 0;
		}
		
	}
	[newparam release];
	return 1;
}

-(NSString*) getFullToken:(NSString*) mtoken
{
	NSString* method=@"flickr.auth.getFullToken";
	
	NSMutableDictionary *newparam=[[NSMutableDictionary alloc] init];
	[newparam setObject:method forKey:@"method"];
	[newparam setObject:@API_KEY forKey:@"api_key"];
	[newparam setObject:mtoken forKey:@"mini_token"];
	
	NSString* param = signatureForCall(newparam);
	NSLog(@"%@", param);
	
	NSString* rsp = flickrApiCall(param);		
	NSLog(@"Response is (%@)\n", rsp);
	if(rsp) 
	{
		int errcode = 0;
        id errmsg = nil;
        BOOL err = NO;
		
        NSXMLDocument *xmlDoc = [[NSClassFromString(@"NSXMLDocument") alloc] initWithXMLString:rsp options:NSXMLDocumentXMLKind error:&errmsg];
		NSXMLNode *stat =[[xmlDoc rootElement] attributeForName:@"stat"];
		NSLog(@"return (%@)\n", [stat stringValue]);
		
		if([[stat stringValue] isEqualToString:@"ok"])
		{
			minitoken = mtoken;
		}
		else
		{
			[alertSheet setBodyText:[stat stringValue]];
			[alertSheet popupAlertAnimated:YES];
		}
		
		[self getFlickrData:[xmlDoc rootElement]];
		[xmlDoc release];
	}
	[newparam release];
	return token;
}

-(int)flickrUploadPic:(NSData*) jpeg 
{
	NSAutoreleasePool* pool = [NSAutoreleasePool new];
	{
		int currentRotation = [UIHardware deviceOrientation:YES];

		NSMutableString *url=[NSMutableString stringWithString:@"http://api.flickr.com/services/upload"];
		NSMutableDictionary *params=[[NSMutableDictionary alloc] init];
		
		NSURL *theURL = [NSURL URLWithString:url];
		
		NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:theURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:1000.0f];
		[theRequest setHTTPMethod:@"POST"];
		
		NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",POSTDataSeparator];
		[theRequest addValue:contentType forHTTPHeaderField: @"Content-Type"];
		
		NSData* uploadData = prepareUploadData(jpeg, @"iflickr.jpg", params, token, [[tagCell textField] text], location, mIsPrivate);
		NSString* uploadDataStr =  [[NSString alloc] initWithData:uploadData encoding:NSASCIIStringEncoding];
		NSLog(@"Body is (%@)", uploadDataStr );
		[theRequest setHTTPBody:uploadData];
		
		NSURLResponse *theResponse = NULL;
		NSError *theError = NULL;
		NSXMLNode *stat;
		NSXMLDocument *xmlDoc;
		NSData *theResponseData;
		NSString *theResponseString;
		
		/* Try 3 times to send he picture to flickr, useful when on EDGE. The connection seems to drop sometimes.*/
		int i = 0;
		for (i = 0; i < 3; i++ )
		{
			theResponseData = [NSURLConnection sendSynchronousRequest:theRequest returningResponse:&theResponse error:&theError];
			theResponseString = [[NSString alloc] initWithData:theResponseData encoding:NSASCIIStringEncoding] ;
			NSLog(@"response  is (%@)", theResponseString);
			id errmsg = nil;
			
			[uploadDataStr release];
			
			xmlDoc = [[NSClassFromString(@"NSXMLDocument") alloc] initWithXMLString:theResponseString options:NSXMLDocumentXMLKind error:&errmsg];
			stat =[[xmlDoc rootElement] attributeForName:@"stat"];
			
			/*
			 <rsp stat="ok">
			 <photoid>1377891858</photoid>
			 </rsp>
			 */
			
			if ([[stat stringValue] isEqualToString:@"ok"]) 
			{ 
				break;
			}
		}
		/* All retries exhausted...	*/
		if (![[stat stringValue] isEqualToString:@"ok"]) 
		{ 
			[status setText:[NSString stringWithFormat:@"Failed to send pic. Check authentications."]];
			[lock lock];
			uploadQSize--;
			[lock unlock];
			return 0;
			
		}
		
		/* 
			Rotate the pic, use flickr api to do so, so that lossless rotation is acheived.
		*/
		
		NSString* pictureid = [ [ [ [xmlDoc rootElement]  children] objectAtIndex:0] stringValue];
		NSLog(@"Uploaded picture with id %@\n", pictureid);
		NSLog(@"Current rotation = %d\n", currentRotation);
		switch(currentRotation) 
		{
			case 1: 
				[self rotatePicture:pictureid degrees:@"90"];
				break;
			case 4:
				[self rotatePicture:pictureid degrees:@"180"];
				break;
			case 2:
				[self rotatePicture:pictureid degrees:@"270"];
				break;
		}
		
		[lock lock];
		uploadQSize--;
		[self setApplicationBadge:[NSString stringWithFormat:@"%d", uploadQSize]];
		if(uploadQSize <= 0)
		{
			NSLog(@"Stoping animation\n");
			[status removeFromSuperview];
			[progress stopAnimation];
			[self removeApplicationBadge];
			if([self isSuspended])
			{
				[self terminateWithSuccess];
			}

		}
		if(uploadQSize > 0)
		{
			[status setText:[NSString stringWithFormat:@"Sending %d pics", uploadQSize]];
		}
		[lock unlock];
		[theResponseString release];
		[params release];
	}
	[pool release];
	return 1;
}

typedef struct {
	struct jpeg_destination_mgr pub;
	JOCTET *buf;
	size_t bufsize;
	size_t jpegsize;
} mem_destination_mgr;

typedef mem_destination_mgr *mem_dest_ptr;


METHODDEF(void) init_destination(j_compress_ptr cinfo)
{
	mem_dest_ptr dest = (mem_dest_ptr) cinfo->dest;
	
	dest->pub.next_output_byte = dest->buf;
	dest->pub.free_in_buffer = dest->bufsize;
	dest->jpegsize = 0;
}

METHODDEF(boolean) empty_output_buffer(j_compress_ptr cinfo)
{
	mem_dest_ptr dest = (mem_dest_ptr) cinfo->dest;
	
	dest->pub.next_output_byte = dest->buf;
	dest->pub.free_in_buffer = dest->bufsize;
	
	return FALSE;
}

METHODDEF(void) term_destination(j_compress_ptr cinfo)
{
	mem_dest_ptr dest = (mem_dest_ptr) cinfo->dest;
	dest->jpegsize = dest->bufsize - dest->pub.free_in_buffer;
}

static GLOBAL(int) jpeg_mem_size(j_compress_ptr cinfo)
{
	mem_dest_ptr dest = (mem_dest_ptr) cinfo->dest;
	return dest->jpegsize;
}


static GLOBAL(void) jpeg_mem_dest(j_compress_ptr cinfo, JOCTET* buf, size_t bufsize)
{
	mem_dest_ptr dest;
	
	if (cinfo->dest == NULL) {
		cinfo->dest = (struct jpeg_destination_mgr *)
		(*cinfo->mem->alloc_small)((j_common_ptr)cinfo, JPOOL_PERMANENT,
								   sizeof(mem_destination_mgr));
	}
	
	dest = (mem_dest_ptr) cinfo->dest;
	
	dest->pub.init_destination    = init_destination;
	dest->pub.empty_output_buffer = empty_output_buffer;
	dest->pub.term_destination    = term_destination;
	
	dest->buf      = buf;
	dest->bufsize  = bufsize;
	dest->jpegsize = 0;
}


void make_JPEG (char * data, long* length,
				int quality, JSAMPLE* image_buffer_bad, 
				int image_width, int image_height)
{
	
	long global_currentlength;
	
	struct jpeg_destination_mgr mgr;
	
	JSAMPLE* image_buffer_row,*orig_ibr;
	struct jpeg_compress_struct cinfo;
	
	struct jpeg_error_mgr jerr;
	long** get_length = 0;
	
	int row_stride,x;		/* physical row width in image buffer */
	cinfo.err = jpeg_std_error(&jerr);
	/* Now we can initialize the JPEG compression object. */
	jpeg_create_compress(&cinfo);
	
	jpeg_mem_dest(&cinfo, (unsigned char*)data, 0x100000);
	
	cinfo.image_width = image_width; 	/* image width and height, in pixels */
	cinfo.image_height = image_height;
	cinfo.input_components = 3;		/* # of color components per pixel */
	cinfo.in_color_space = JCS_RGB; 	/* colorspace of input image */
	jpeg_set_defaults(&cinfo);
	jpeg_set_quality(&cinfo, quality, TRUE /* limit to baseline-JPEG values */);
	
	jpeg_start_compress(&cinfo, TRUE);
	
	row_stride = image_width * 3;	/* JSAMPLEs per row in image_buffer */
	
	while (cinfo.next_scanline < cinfo.image_height) 
	{
		image_buffer_row = (unsigned char *)malloc(image_width*3*sizeof(unsigned char));
		if (image_buffer_row == 0) 
		{ 
			return;
		}
		orig_ibr = image_buffer_row;
		
		for (x=0 ; x < image_width ; x++)
		{ 
			
			image_buffer_bad++;			//skip high order byte.
			*orig_ibr = *image_buffer_bad;
			orig_ibr++; image_buffer_bad++;
			*orig_ibr = *image_buffer_bad;
			orig_ibr++; image_buffer_bad++;
			*orig_ibr = *image_buffer_bad;
			orig_ibr++; image_buffer_bad++;
			
		}
		
		(void) jpeg_write_scanlines(&cinfo, &image_buffer_row, 1);
		free(image_buffer_row);
		
	}
	
	jpeg_finish_compress(&cinfo);
	*length = jpeg_mem_size(&cinfo);
	
	jpeg_destroy_compress(&cinfo);
}

-(void)dealloc
{
	[token release];
	[minitoken release];
	[userid release];
	[tags release];
	
	[imageview release];
	[_pref release];		
	[_navBar release];
	[miniToken release];
	[tagCell release];
	[_transitionView release];
	[progress release];
	[mainView release];	
	[status release];
	[alertSheet release];
	[picButton release];
	[stopButton release];
	[playButton release];

	[saveLocally release];
	[isPrivate release];
	[_continuousCell release];
	[continuousShoot release];
	[_saveCell release];
	[_privacyCell release];
	
	[super dealloc];

}
 
-(void)initlocation
{
	
	[self cellConnect];
	[self getCellInfo:cellinfo];
	
	NSString *url=[NSString stringWithFormat:@"http://zonetag.research.yahooapis.com/services/rest/V1/cellLookup.php?apptoken=7107598df4d33d39bc70a6e8d5334e71&cellid=%d&lac=%d&mnc=%d&mcc=%d&compressed=1", cellinfo.cellid, cellinfo.location, cellinfo.network, cellinfo.servingmnc];
	
	NSLog(@"String is (%@)", url);
	
	NSURL *theURL = [NSURL URLWithString:url];
	
	NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:theURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:1000.0f];
	[theRequest setHTTPMethod:@"GET"];
	
	NSURLResponse *theResponse = NULL;
	NSError *theError = NULL;
	NSData *theResponseData = [NSURLConnection sendSynchronousRequest:theRequest returningResponse:&theResponse error:&theError];
	NSString *theResponseString = [[NSString alloc] initWithData:theResponseData encoding:NSASCIIStringEncoding] ;
	NSLog(@"response  is (%@)", theResponseString);	
	
			int errcode = 0;
        id errmsg = nil;
        BOOL err = NO;
		
		NSXMLDocument *xmlDoc = [[NSClassFromString(@"NSXMLDocument") alloc] initWithXMLString:theResponseString options:NSXMLDocumentXMLKind error:&errmsg];
		NSXMLNode *stat =[[xmlDoc rootElement] attributeForName:@"stat"];
		NSLog(@"return (%@)\n", [stat stringValue]);
		
		if([[stat stringValue] isEqualToString:@"ok"])
		{
			NSArray *children = [[xmlDoc rootElement] children];
			int i, count = [children count];
			NSXMLElement *child = [children objectAtIndex:0];
			NSLog(@"Name (%@) : Value (%@) \n", [child name], [child stringValue]);
			location = [[NSString alloc]initWithString:[child stringValue]];
		}
		else
		{
			[alertSheet setBodyText:@"Could not get GSM location"];
			[alertSheet popupAlertAnimated:YES];
		}
		
	//return [theResponseString autorelease];
	
}

-(void)getCellInfo:(struct CellInfo) cellinfo1;
{
	int cellcount;
		
	_CTServerConnectionCellMonitorGetCellCount(&tl,connection,&cellcount);
	NSLog(@"Cell count: %d (%d)\n",cellcount,tl);
	unsigned char *a=malloc(sizeof(struct CellInfo));
	for(i = 0; i<cellcount; i++)
	{
		_CTServerConnectionCellMonitorGetCellInfo(&tl,connection,i,a);
		
		memcpy(&cellinfo,a, sizeof(struct CellInfo)); 
		printf("Cell Site: %d, MCC: %d, ",i,cellinfo.servingmnc);
		printf("MNC: %d ",cellinfo.network);
		printf("Location: %d, Cell ID: %d, Station: %d, ",cellinfo.location, cellinfo.cellid, cellinfo.station);
		printf("Freq: %d, RxLevel: %d, ", cellinfo.freq, cellinfo.rxlevel);
		printf("C1: %d, C2: %d\n", cellinfo.c1, cellinfo.c2);
	}
	
	_CTServerConnectionCellMonitorGetCellInfo(&tl,connection,0,a);
				
	memcpy(&cellinfo,a, sizeof(struct CellInfo));
				
	if(a) free(a);
	
	return ;
}

-(void)cellConnect
{
        int tx;
        connection = _CTServerConnectionCreate(kCFAllocatorDefault, callback, NULL);

        CFMachPortContext  context = { 0, 0, NULL, NULL, NULL };

        ref=CFMachPortCreateWithPort(kCFAllocatorDefault, _CTServerConnectionGetPort(connection), sourcecallback, &context, NULL);

        _CTServerConnectionCellMonitorStart(&tx,connection);

       NSLog(@"Connected\n");

}
@end

NSString* getmd5(char* str)
{
	md5_state_t state;
	md5_byte_t digest[16];
	char hex_output[16*2 + 1];
	int di;
	
	md5_init(&state);
	md5_append(&state, (const md5_byte_t *)str, strlen(str));
	md5_finish(&state, digest);
	for (di = 0; di < 16; ++di)
		sprintf(hex_output + di * 2, "%02x", digest[di]);
	
	NSString *retValue = [[NSString alloc] initWithUTF8String:hex_output];
	
	return([retValue autorelease]);	
}

NSString* signatureForCall(NSDictionary* parameters) {
	
	NSMutableString *sigstr=[NSMutableString stringWithString:@SHARED_SECRET];
	NSArray *sortedkeys=[[parameters allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	NSMutableString *urlParam=[NSMutableString stringWithString:@""];
	
	unsigned i, c=[sortedkeys count];
	for (i=0; i<c; i++) {
		NSString *k=[sortedkeys objectAtIndex:i];
		NSString *v=[parameters objectForKey:k];
		[sigstr appendString:k];
		[sigstr appendString:v];
		[urlParam appendString:@"&"];
		[urlParam appendString:k];
		[urlParam appendString:@"="];
		[urlParam appendString:v];
	}
	
	NSString* md5 = getmd5([sigstr UTF8String]);
	[urlParam appendString:@"&api_sig="];
	[urlParam appendString:md5];
	
	return urlParam ;
}

NSString* md5sig(NSDictionary* parameters) {
	
	NSMutableString *sigstr=[NSMutableString stringWithString:@SHARED_SECRET];
	NSArray *sortedkeys=[[parameters allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	NSMutableString *urlParam=[NSMutableString stringWithString:@""];
	
	unsigned i, c=[sortedkeys count];
	for (i=0; i<c; i++) {
		NSString *k=[sortedkeys objectAtIndex:i];
		NSString *v=[parameters objectForKey:k];
		[sigstr appendString:k];
		[sigstr appendString:v];
	}
	
	NSString* md5 = getmd5([sigstr UTF8String]);
	[urlParam appendString:md5];	
	return urlParam;
}

NSString* flickrApiCall(NSString* params) {
	NSMutableString *url=[NSMutableString stringWithString:@"http://api.flickr.com/services/rest/?"];
	[url appendString:params];
	NSLog(@"String is (%@)", url);
	
	NSURL *theURL = [NSURL URLWithString:url];
	
	NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:theURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:1000.0f];
	[theRequest setHTTPMethod:@"GET"];
	
	NSURLResponse *theResponse = NULL;
	NSError *theError = NULL;
	NSData *theResponseData = [NSURLConnection sendSynchronousRequest:theRequest returningResponse:&theResponse error:&theError];
	NSString *theResponseString = [[NSString alloc] initWithData:theResponseData encoding:NSASCIIStringEncoding] ;
	NSLog(@"response  is (%@)", theResponseString);	
	return [theResponseString autorelease];
}


NSData* prepareUploadData(NSData* data, NSString* filename ,NSDictionary* info, NSString* auth, NSString* pictags, NSString* description, BOOL isPrivate)
{
	// TO-DO: Quote processing of filename
	NSLog(@"Inside  prepareUploadData\n");
	NSMutableData *cooked=internalPreparePOSTData(info ,auth ,YES ,NO, pictags,description,isPrivate);
	
	NSString *lastpart = [filename lastPathComponent];
	NSString *extension = [filename pathExtension];
	NSString *content_type = @"image/jpeg";
	
	if ([extension isEqualToString:@"png"]) {
		content_type = @"image/png";
	}
	else if ([extension isEqualToString:@"gif"]) {
		content_type = @"image/gif";
	}
	
	NSString *filename_str = [NSString stringWithFormat:
						  @"--%@\r\nContent-Disposition: form-data; name=\"photo\"; filename=\"%@\"\r\nContent-Type: %@\r\n\r\n",
		POSTDataSeparator, lastpart, content_type];
	
	[cooked appendData:[filename_str dataUsingEncoding:NSUTF8StringEncoding]];
	[cooked appendData:data];    
	NSLog(@"Cooked data\n");  
	NSString *endmark = [NSString stringWithFormat: @"\r\n--%@--", POSTDataSeparator];
	[cooked appendData:[endmark dataUsingEncoding:NSUTF8StringEncoding]];
	return cooked;
}

NSMutableData* internalPreparePOSTData(NSDictionary* parameters, NSString*  auth ,BOOL sign ,BOOL endmark, NSString* pictags, NSString* description, BOOL isPrivate)
{
	NSLog(@"Inside  internalPreparePOSTData\n");
	NSMutableData *data=[NSMutableData data];
	//NSMutableDictionary *newparam=[NSMutableDictionary dictionaryWithDictionary:parameters];
	NSMutableDictionary *newparam=[[NSMutableDictionary alloc] init];
	
	[newparam setObject:@API_KEY forKey:@"api_key"];
	
	if (auth) [newparam setObject:auth forKey:@"auth_token"];
	
	if (pictags) [newparam setObject:pictags forKey:@"tags"];
	
	if (description) [newparam setObject:description forKey:@"description"];
	
	if(isPrivate) [newparam setObject:@"0" forKey:@"is_public"];
	
	if (sign) {
		NSString *apisig=md5sig(newparam);
		[newparam setObject:apisig forKey:@"api_sig"];
		//[newparam setObject:@"test pic" forKey:@"photo"];
	}
	
	NSArray *keys=[newparam allKeys];
	unsigned i, c=[keys count];
	
	for (i=0; i<c; i++) {
		NSString *k=[keys objectAtIndex:i];
		NSString *v=[newparam objectForKey:k];
		
		NSString *addstr = [NSString stringWithFormat:
						@"--%@\r\nContent-Disposition: form-data; name=\"%@\"\r\n\r\n%@\r\n",
			POSTDataSeparator, k, v];
		[data appendData:[addstr dataUsingEncoding:NSUTF8StringEncoding]];
	}
	
	if (endmark) {
		NSString *ending = [NSString stringWithFormat: @"--%@--", POSTDataSeparator];
		[data appendData:[ending dataUsingEncoding:NSUTF8StringEncoding]];
	}
	[newparam release];
	return data;
}

int callback(void *connection, CFStringRef string, CFDictionaryRef dictionary, void *data) {
        NSLog(@"callback (but it never calls me back :( ))\n");
        CFShow(string);
        CFShow(dictionary);

        return 0;
}

void sourcecallback ( CFMachPortRef port, void *msg, CFIndex size, void *info)
{
        NSLog(@"Source called back\n");
        //getCellInfo();
}
void mycallback (void)
{
        NSLog(@"My called back\n");

}