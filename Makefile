CC=/Developer/SDKs/iPhone/bin/arm-apple-darwin-cc
LD=$(CC)
LDFLAGS=-ObjC -framework CoreFoundation -framework Foundation -framework UIKit -framework LayerKit -framework PhotoLibrary -framework PhotoLibrary -framework CoreGraphics -framework Camera -framework GraphicsServices -framework OfficeImport
LDFLAGS_FRAMEWORKSDIR=-F/Developer/SDKs/iphone/heavenly/System/Library/ 

all:	FlickrHack	package

FlickrHack:	FlickrHack.o FlickrHackApplication.o md5.o

	$(LD) $(LDFLAGS) -o $@ $^

%.o:	%.m %.h %.c
		$(CC) -I/Users/pradeepta/objflickr_new/iphone/objectiveflickr/build/ObjectiveFlickr.build/Release/ObjectiveFlickr.build/ObjectiveFlickr.hmap -c $(CFLAGS) $(CPPFLAGS) $< -o $@ 

clean:
	rm -fr *.o FlickrHack FlickrHack.app
	
package: FlickrHack
	rm -fr FlickrHack.app
	mkdir -p FlickrHack.app
	cp FlickrHack FlickrHack.app/FlickrHack
	cp Info.plist FlickrHack.app/Info.plist
	cp icon.png FlickrHack.app/icon.png
	cp flickr.gif FlickrHack.app/flickr.gif


