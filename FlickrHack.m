#import <UIKit/UIKit.h>

#import "FlickrHackApplication.h"

int main(int argc, char **argv)
{
    NSXMLElement* xml = [NSClassFromString(@"NSXMLElement") alloc];

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    return UIApplicationMain(argc, argv, [FlickrHackApplication class]);
}
