//
//  main.m
//  VSCOKeysActivator
//
//  Created by Sean Gubelman on 6/29/12.
//
//  VSCO Keys for Adobe Lightroom
//  Copyright (C) 2015 Visual Supply Company
//  Licensed under GNU GPLv2 (or any later version).
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//

#import <CoreFoundation/CoreFoundation.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Cocoa/Cocoa.h>
#include <sys/types.h>
#include <signal.h>

#pragma mark Main method

int main(int argc, const char * argv[])
{
    if (argc != 4)
    {
        return 1;
    }

    // wait until app is shutdown to relaunch
	pid_t parentPID = atoi(argv[3]);
	while (kill(parentPID, 0) == 0)
		sleep(1);

    const char *appPathCString = argv[1];
    const char *appExePathCString = argv[2];
    NSString *appPath = [NSString stringWithCString:appPathCString encoding:NSUTF8StringEncoding];

    // Accessibility permissions must be granted manually in System Settings
    // The deprecated AXMakeProcessTrusted API no longer exists in modern macOS

    // relaunch app
    NSURL *appURL = [NSURL fileURLWithPath:[appPath stringByExpandingTildeInPath]];
    NSWorkspaceOpenConfiguration *config = [NSWorkspaceOpenConfiguration configuration];
    [[NSWorkspace sharedWorkspace] openApplicationAtURL:appURL configuration:config completionHandler:nil];
    BOOL success = YES;

    if (!success)
    {
        NSLog(@"Error: could not relaunch application at %@", appPath);
    }

    return (success) ? 0 : 1;
}

