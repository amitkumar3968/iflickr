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
#import "PhotoLibrary.h"
#import "FlickrHackApplication.h"

#include "md5.h"
#include <math.h>
#include <stdio.h>
#include <string.h>

#define PREF_FILE @"/Applications/FlickrHack.app/userprefs.xml"

NSString* POSTDataSeparator = @"---------------------------8f999edae883c6039b244c0d341f45f8";

int GSEventDeviceOrientation(GSEvent *ev);

static CGColorSpaceRef color_space = 0;

static NSRecursiveLock* lock = 0;

@implementation FlickrHackApplication

-(void)cameraController:(id)sender tookPicture:(UIImage*)picture withPreview:(UIImage*)preview jpegData:(NSData*)jpeg imageProperties:(struct __CFDictionary *)fp16
{
	NSAutoreleasePool* pool = [NSAutoreleasePool new];
	{
		printf("Took a picture callback\n");
		
		if (preview && [preview imageRef])
		{
			printf("Token from prefs : %s\n", [token UTF8String]);
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
			//[self flickrUploadPic:jpeg];
		}
		
	}
	[pool release];
}



-(void)takePicture:(id)sender
{
	NSAutoreleasePool* pool = [NSAutoreleasePool new];
	{
		printf("Took a picture\n");
		[imageview _playShutterSound];
		[ camController capturePhoto];
	}
	[pool release];
}

- (void)cameraControllerReadyStateChanged:(id)fp8
{
	//	[self setText:@"ready state changed"];
}

- (id) createButton:(NSString *)name
{
	UIPushButton *button =
	[[UIPushButton alloc] initWithFrame: CGRectMake(130.0f, 420.0f, 100.0f, 60.0f)];
	NSString *onFile = [NSString
                stringWithFormat:@"/Applications/NES.app/a.png"];
	UIImage* on = [[UIImage alloc] initWithContentsOfFile: onFile];
	[button setImage:on forState:1];
	NSString *offFile = [NSString
                stringWithFormat:@"/Applications/FlickrHack.app/flickr.gif"];
	UIImage* off = [[UIImage alloc] initWithContentsOfFile: offFile];
	[button setImage:off forState:0];
	[button setEnabled:YES];
	[button setDrawContentsCentered:YES];
	[button setAutosizesToFit:NO];
	[button setNeedsDisplay];
	[button addTarget:self action:@selector(takePicture:) forEvents:255];
	return button;
}

- (void) applicationDidFinishLaunching: (id) unused
{
	printf("Application finished lauching\n");	
	// hide status bar
	[self setStatusBarMode:2 duration:0];
	
	UIWindow *window;
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
	
	printf("Token from prefs : %s\n", [token UTF8String]);
	
	[window setContentView: mainView]; 
	
	printf("Added main view  \n");
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
				printf("Token from prefs : %s\n", [token UTF8String]);
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
			
			
		}
		[_pref reloadData];
	}
}

- (void)savePreferences {
    printf("savePreferences: _currentView %d, minitoken = %s in memorey (%s)\n", _currentView, [[[miniToken textField] text] UTF8String], [minitoken UTF8String]);
	
	if([[miniToken textField] text])
	{
		NSString* s = [[miniToken textField] text];
		if([s isEqualToString:minitoken])
		{
			NSLog(@"%@ == %@\n", s, minitoken);
			return;
		}
		[self getFullToken:[[miniToken textField] text]];
		
		//Build settings dictionary
		
		NSDictionary* settingsDict = [[NSDictionary alloc] initWithObjectsAndKeys:
			token, @"token",
			[[miniToken textField] text], @"minitoken",
			userid, @"userid",
			nil];
		
		//Seralize settings dictionary
		NSString* error;
		NSData* rawPList = [NSPropertyListSerialization dataFromPropertyList: settingsDict		
																	  format: NSPropertyListXMLFormat_v1_0
															errorDescription: &error];
		
		//Write settings plist file
		[rawPList writeToFile: PREF_FILE atomically: YES];
		[settingsDict autorelease];
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
    [ versionText setText:@"0.0.1"];
    [ versionText setBackgroundColor:
		CGColorCreate(colorSpace, transparentComponents)];
    [ pref addSubview:versionText ];
    [ pref reloadData ];
    return pref;
}

- (void)setNavBar {
    int screenOrientation = [UIHardware deviceOrientation: YES];
	
	printf("Screen orientation = %d", screenOrientation);
    if (screenOrientation == 3)
        return;
	printf("_currentView = %d\n", _currentView);
	
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
	if (group == 0) return 3;
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
				miniToken = [[UIPreferencesTextTableCell alloc]  initWithFrame:CGRectMake(170.0f, 100.0f, 120.0f, 20.0f)];
				[ miniToken setTitle:@"Minitoken" ];
				if(!minitoken)
				{
					[[miniToken textField] setText:@"Enter minitoken, click on Auth"];
				}
					else 
					{
						[[miniToken textField] setText:minitoken];
					}
					//[cell addSubview:miniToken];
					return [miniToken autorelease];
				break;
			case (1):
                [ cell setTitle:[NSString stringWithFormat:@"User : %@", userid]];
                break;
            case (2):
                [ cell setTitle:@"View Your Pictures" ];
                break;
				
		}
    }
    return [cell autorelease];
}

- (UINavigationBar *)createNavBar {
    float offset = 48.0;
    UINavigationBar *navBar = [[UINavigationBar alloc] initWithFrame:
        CGRectMake(0.0f,-10.0f, 320.0f, 48.0f)
		];
	
    [navBar setDelegate: self];
    [navBar enableAnimation];
	[navBar autorelease];
	
    return navBar;
}


- (void)navigationBar:(UINavigationBar *)navbar buttonClicked:(int)button {
    int screenOrientation = [UIHardware deviceOrientation: YES];
	printf("Button (%d) _currentView (%d)\n", button, _currentView);
	
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
					
                    break;
				case CUR_PREFERENCES:
				{
					NSLog(@"Opening flickr url\n");
					NSURL *url;
					url = [[NSURL alloc] initWithString:@"http://www.flickr.com/auth-72157601777151481"];
					[self openURL:url];		
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
		// Allert sheet displayed at centre of screen.
		//[status setText:@"Could not authenticate minitoken"];
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
	}
	[newparam autorelease];
	return token;
}

-(int)flickrUploadPic:(NSData*) jpeg 
{
	NSAutoreleasePool* pool = [NSAutoreleasePool new];
	{
		NSMutableString *url=[NSMutableString stringWithString:@"http://api.flickr.com/services/upload"];
		NSMutableDictionary *params=[[NSMutableDictionary alloc] init];
		
		NSURL *theURL = [NSURL URLWithString:url];
		
		NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:theURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:1000.0f];
		[theRequest setHTTPMethod:@"POST"];
		
		NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",POSTDataSeparator];
		[theRequest addValue:contentType forHTTPHeaderField: @"Content-Type"];
		
		NSData* uploadData = prepareUploadData(jpeg, @"test.jpg", params, token);
		NSString* uploadDataStr =  [[NSString alloc] initWithData:uploadData encoding:NSASCIIStringEncoding];
		NSLog(@"Body is (%@)", uploadDataStr );
		[theRequest setHTTPBody:uploadData];
		
		NSURLResponse *theResponse = NULL;
		NSError *theError = NULL;
		NSData *theResponseData = [NSURLConnection sendSynchronousRequest:theRequest returningResponse:&theResponse error:&theError];
		NSString *theResponseString = [[NSString alloc] initWithData:theResponseData encoding:NSASCIIStringEncoding] ;
		NSLog(@"response  is (%@)", theResponseString);
		id errmsg = nil;
		
		NSXMLDocument *xmlDoc = [[NSClassFromString(@"NSXMLDocument") alloc] initWithXMLString:theResponseString options:NSXMLDocumentXMLKind error:&errmsg];
		NSXMLNode *stat =[[xmlDoc rootElement] attributeForName:@"stat"];
		
		if (![[stat stringValue] isEqualToString:@"ok"]) 
		{ 
			//[alertSheet setBodyText:[NSString stringWithFormat:@"Failed to send pic. Check authentications. Code(%@)", [stat stringValue]]];
			//[alertSheet popupAlertAnimated:YES];
			[status setText:[NSString stringWithFormat:@"Failed to send pic. Check authentications."]];
			[lock lock];
			uploadQSize--;
			[lock unlock];
			return 0;
			
		}	
		[lock lock];
		uploadQSize--;
		if(uploadQSize <= 0)
		{
			NSLog(@"Stoping animation\n");
			[status removeFromSuperview];
			[progress stopAnimation];
		}
		if(uploadQSize > 0)
		{
			[status setText:[NSString stringWithFormat:@"Sending %d pics", uploadQSize]];
		}
		[lock unlock];
		
	}
	[pool release];
	return 1;
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
	[retValue autorelease];
	return(retValue);	
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
	
	return urlParam;
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
	//[urlParam appendString:@"api_sig="];
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


NSData* prepareUploadData(NSData* data, NSString* filename ,NSDictionary* info, NSString* auth)
{
	// TO-DO: Quote processing of filename
	NSLog(@"Inside  prepareUploadData\n");
	NSMutableData *cooked=internalPreparePOSTData(info ,auth ,YES ,NO);
	
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

NSMutableData* internalPreparePOSTData(NSDictionary* parameters, NSString*  auth ,BOOL sign ,BOOL endmark)
{
	NSLog(@"Inside  internalPreparePOSTData\n");
	NSMutableData *data=[NSMutableData data];
	//NSMutableDictionary *newparam=[NSMutableDictionary dictionaryWithDictionary:parameters];
	NSMutableDictionary *newparam=[[NSMutableDictionary alloc] init];
	
	[newparam setObject:@API_KEY forKey:@"api_key"];
	
	if (auth) [newparam setObject:auth forKey:@"auth_token"];
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
	[newparam autorelease];
	return data;
}
