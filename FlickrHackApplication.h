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


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UIKit/UIApplication.h>
#import <UIKit/UIPushButton.h>
#import <UIKit/UITableCell.h>
#import <UIKit/UIImageAndTextTableCell.h>
#import <UIKit/UITextView.h>
#import <UIKit/UIAutocorrectImageView.h>
#import <UIKit/UITransitionView.h>
#import <UIKit/UIPreferencesTable.h>
#import <UIKit/UISegmentedControl.h>
#import <UIKit/UISwitchControl.h>
#import <UIKit/UIPreferencesTextTableCell.h>
#import <UIkit/UIProgressIndicator.h>
#import <UIkit/UITextLabel.h>

@class CameraController;
@class CameraView;

#define SHARED_SECRET "INSERT_YOUR_SHARED_SECRET"
#define API_KEY  "INSERT_YOUR_API_KEY"

// Utility Functions.

NSString* getFullToken(NSString* miniToken);
NSString* signatureForCall(NSDictionary* parameters) ;
NSString* md5sig(NSDictionary* parameters) ;
NSMutableData* internalPreparePOSTData(NSDictionary* parameters, NSString*  auth ,BOOL sign ,BOOL endmark);
NSData* prepareUploadData(NSData* data, NSString* filename ,NSDictionary* info, NSString* auth);
NSString* flickrApiCall(NSString* params);

@interface FlickrHackApplication : UIApplication 
{	
	int       _currentView;
	NSString   *token;
	NSString   *minitoken;
	NSString* userid;
	
	int uploadQSize;	
	BOOL mLandscape;
	int mCurrentRotation;
	int mDeviceRotation;
	
	CameraController* camController;
	CameraView* imageview;
	UIPreferencesTable *_pref;		
	UINavigationBar  *_navBar;
	UIPreferencesTextTableCell *miniToken;
	UITransitionView *_transitionView;
	UIProgressIndicator *progress;
	UIView *mainView;	
	UITextLabel* status;
	UIAlertSheet* alertSheet;
	UIPushButton* picButton;
}

-(void)takePicture:(id)sender;
-(UIPreferencesTable *)createPrefPane;
-(UINavigationBar *)createNavBar;
- (int)numberOfGroupsInPreferencesTable:(UIPreferencesTable *)aTable;
- (int)preferencesTable:(UIPreferencesTable *)aTable numberOfRowsInGroup:(int)group;
- (UIPreferencesTableCell *)preferencesTable:(UIPreferencesTable *)aTable cellForGroup:(int)group;
- (UIPreferencesTableCell *)preferencesTable:(UIPreferencesTable *)aTable cellForRow:(int)row inGroup:(int)group;
- (float)preferencesTable:(UIPreferencesTable *)aTable heightForRow:(int)row inGroup:(int)group withProposedHeight:(float)proposed;
- (BOOL)preferencesTable:(UIPreferencesTable *)aTable isLabelGroup:(int)group;
- (void)setNavBar;
- (void)savePreferences;
- (void)loadPreferences;
- (NSString*) getFullToken:(NSString*) miniToken;
- (void)getFlickrData:(NSXMLElement*) e;
- (int) flickrUploadPic : (NSData*) jpeg;

#define CUR_BROWSER     0x00
#define CUR_PREFERENCES 0x01


@end
