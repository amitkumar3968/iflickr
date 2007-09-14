CC=/Developer/SDKs/iPhone/bin/arm-apple-darwin-cc
LD=$(CC)
LDFLAGS=-ObjC -framework CoreFoundation -framework Foundation -framework UIKit -framework LayerKit -framework PhotoLibrary -framework PhotoLibrary -framework CoreGraphics -framework Camera -framework GraphicsServices -framework OfficeImport
LDFLAGS_FRAMEWORKSDIR=-F/Developer/SDKs/iphone/heavenly/System/Library/ 

all:	iFlickr	package

iFlickr:	FlickrHack.o FlickrHackApplication.o md5.o  toolchain_patch.o

	$(LD) $(LDFLAGS) -o $@ $^

%.o:	%.m %.h %.c
		$(CC) -I/Users/pradeepta/objflickr_new/iphone/objectiveflickr/build/ObjectiveFlickr.build/Release/ObjectiveFlickr.build/ObjectiveFlickr.hmap -c $(CFLAGS) $(CPPFLAGS) $< -o $@ 

clean:
	rm -fr *.o iFlickr iFlickr.app
	
package: iFlickr
	rm -fr iFlickr.app
	mkdir -p iFlickr.app
	cp iFlickr iFlickr.app/iFlickr
	cp Info.plist iFlickr.app/Info.plist
	cp icon.png iFlickr.app/icon.png
	cp play.gif iFlickr.app/play.gif
	cp stop.gif iFlickr.app/stop.gif
	cp Default.png iFlickr.app/Default.png

