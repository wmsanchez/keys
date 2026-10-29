//
//  AppDelegate.m
//  VSCOKeys
//
//  Created by Sean Gubelman on 6/25/12.
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

#import "AppDelegate.h"
#import "KeyControl.h"
#import "MainWindowController.h"
#import <dispatch/dispatch.h>
#include <ExceptionHandling/ExceptionHandling.h>
#include <stdatomic.h>
#import <CoreServices/CoreServices.h>
#include <libkern/OSAtomic.h>
#include <signal.h>
#include <string.h>
#include <unistd.h>
#include <execinfo.h>
#include <dlfcn.h>
#include <sys/sysctl.h>
#include <mach/mach.h>
#include <mach/thread_info.h>

@implementation AppDelegate

@synthesize window = _window;

@synthesize keyControl;
@synthesize mainController;
@synthesize quitTimer;

NSString *traceFilePath = NULL;
static _Atomic int32_t UncaughtExceptionHandlingInProgress = 0;
static char crashReportBuffer[16384];

static NSLock *DualLogLock(void)
{
    static NSLock *lock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lock = [[NSLock alloc] init];
    });
    return lock;
}

static void AppendCrashInfo(const char *format, ...)
{
    va_list args;
    va_start(args, format);
    size_t len = strlen(crashReportBuffer);
    vsnprintf(crashReportBuffer + len, sizeof(crashReportBuffer) - len, format, args);
    va_end(args);
}

static void CaptureSystemInfo(void)
{
    AppendCrashInfo("=== System Information ===\n");

    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSOperatingSystemVersion version = [processInfo operatingSystemVersion];
    AppendCrashInfo("macOS Version: %ld.%ld.%ld\n",
                    (long)version.majorVersion, (long)version.minorVersion, (long)version.patchVersion);

    char hostName[256];
    if (gethostname(hostName, sizeof(hostName)) == 0) {
        AppendCrashInfo("Hostname: %s\n", hostName);
    }

    AppendCrashInfo("Process ID: %d\n", getpid());
    AppendCrashInfo("Parent PID: %d\n", getppid());

    NSString *bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *buildVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    AppendCrashInfo("App Version: %s (Build %s)\n",
                    [bundleVersion UTF8String] ?: "unknown",
                    [buildVersion UTF8String] ?: "unknown");

    int mib[2];
    size_t len;
    char model[256];

    mib[0] = CTL_HW;
    mib[1] = HW_MODEL;
    len = sizeof(model);
    if (sysctl(mib, 2, model, &len, NULL, 0) == 0) {
        AppendCrashInfo("Hardware Model: %s\n", model);
    }

    int64_t memsize;
    len = sizeof(memsize);
    mib[1] = HW_MEMSIZE;
    if (sysctl(mib, 2, &memsize, &len, NULL, 0) == 0) {
        AppendCrashInfo("Memory: %.2f GB\n", memsize / (1024.0 * 1024.0 * 1024.0));
    }

    int ncpu;
    len = sizeof(ncpu);
    mib[1] = HW_NCPU;
    if (sysctl(mib, 2, &ncpu, &len, NULL, 0) == 0) {
        AppendCrashInfo("CPU Count: %d\n", ncpu);
    }

    AppendCrashInfo("\n");
}

static void CaptureStackTrace(void)
{
    AppendCrashInfo("=== Stack Trace ===\n");

    void *callstack[128];
    int frames = backtrace(callstack, 128);
    if (frames > 0) {
        char **symbols = backtrace_symbols(callstack, frames);
        if (symbols) {
            for (int i = 0; i < frames; i++) {
                Dl_info info;
                if (dladdr(callstack[i], &info) && info.dli_sname) {
                    AppendCrashInfo("%d %s (%s+0x%lx)\n", i,
                                    symbols[i],
                                    info.dli_sname,
                                    (unsigned long)((char *)callstack[i] - (char *)info.dli_saddr));
                } else {
                    AppendCrashInfo("%d %s\n", i, symbols[i]);
                }
            }
            free(symbols);
        }
    } else {
        AppendCrashInfo("Unable to capture stack trace\n");
    }
    AppendCrashInfo("\n");
}

static void CaptureThreadInfo(void)
{
    AppendCrashInfo("=== Thread Information ===\n");

    task_t task = mach_task_self();
    thread_act_array_t thread_list;
    mach_msg_type_number_t thread_count;

    if (task_threads(task, &thread_list, &thread_count) == KERN_SUCCESS) {
        AppendCrashInfo("Active Threads: %d\n", thread_count);

        for (mach_msg_type_number_t i = 0; i < thread_count; i++) {
            thread_basic_info_data_t basic_info;
            mach_msg_type_number_t count = THREAD_BASIC_INFO_COUNT;

            if (thread_info(thread_list[i], THREAD_BASIC_INFO,
                           (thread_info_t)&basic_info, &count) == KERN_SUCCESS) {
                AppendCrashInfo("Thread %d: cpu_usage=%.1f%%, sleep_time=%d\n",
                                i, basic_info.cpu_usage / 10.0, basic_info.sleep_time);
            }
        }

        vm_deallocate(task, (vm_address_t)thread_list, thread_count * sizeof(thread_act_t));
    } else {
        AppendCrashInfo("Unable to get thread list\n");
    }
    AppendCrashInfo("\n");
}

// NSAlert/NSWindow must be created and presented on the main thread. Exceptions can be
// delivered on background threads (CGEventTap thread, status bar thread, run loops, etc.).
// Hop with dispatch_sync (never dispatch_async + _exit) so the alert actually runs.
static void PresentUncaughtExceptionAlert(NSException *exception, NSString *filePath, NSString *tracePath)
{
    NSString *alertString = @"%@\n\nThe crash has been logged to disk at:\n%@\n\nThe run log has been stored at:\n%@\n\nPlease send an email to support@visualsupply.co with the above files attached.";

    void (^presentAlert)(void) = ^{
        @try
        {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"An Unhandled Exception Occurred";
            alert.informativeText = [NSString stringWithFormat:alertString, exception, filePath, tracePath];
            [alert addButtonWithTitle:@"Ok"];
            [alert runModal];
        }
        @catch (NSException *alertException)
        {
            NSLog(@"VSCOKeys: failed to present crash alert: %@", alertException);
        }
    };

    if ([NSThread isMainThread])
    {
        presentAlert();
    }
    else
    {
        dispatch_sync(dispatch_get_main_queue(), presentAlert);
    }
}

void uncaughtExceptionHandler(NSException *exception)
{
    int32_t expected = 0;
    if (!atomic_compare_exchange_strong_explicit(&UncaughtExceptionHandlingInProgress, &expected, 1, memory_order_relaxed, memory_order_relaxed))
    {
        return;
    }

    NSString *filePath = nil;

    @try
    {
        memset(crashReportBuffer, 0, sizeof(crashReportBuffer));

        AppendCrashInfo("=== Uncaught Exception ===\n");
        AppendCrashInfo("Time: %s\n", [[NSDate date] description].UTF8String);
        AppendCrashInfo("Exception Name: %s\n", [exception name].UTF8String);
        AppendCrashInfo("Exception Reason: %s\n", [exception reason].UTF8String);
        AppendCrashInfo("\n");

        CaptureSystemInfo();
        CaptureThreadInfo();
        CaptureStackTrace();

        DualLog(@"CRASH: %@", exception);

        NSArray *callstack = [NSThread callStackSymbols];
        AppendCrashInfo("=== NSThread Call Stack ===\n");
        for (NSString *frame in callstack) {
            AppendCrashInfo("%s\n", [frame UTF8String]);
        }
        AppendCrashInfo("\n");

        NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);

        if (dirs && dirs.count >= 1)
        {
            NSFileManager *fileMan = [NSFileManager defaultManager];
            NSString *logDir = [((NSString *)[dirs objectAtIndex:0]) stringByAppendingPathComponent:@"VSCOKeysLogs"];

            if (![fileMan fileExistsAtPath:logDir])
            {
                [fileMan createDirectoryAtPath:logDir withIntermediateDirectories:YES attributes:nil error:nil];
            }

            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"yyyy-M-d-HH-mm-ss"];

            NSString *filestamp = [dateFormatter stringFromDate:[NSDate date]];

            filePath = [logDir stringByAppendingPathComponent:[NSString stringWithFormat:@"VSCOKeysErrorLog_%@.log",filestamp]];

            NSString *fileContents = [NSString stringWithUTF8String:crashReportBuffer];

            NSError *error = nil;
            [fileContents writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&error];

            if (error)
            {
                DualLog(@"Error writing error log. %@", error);
            }
        }

        PresentUncaughtExceptionAlert(exception, filePath, traceFilePath);
    }
    @catch (NSException *handlerException)
    {
        NSLog(@"VSCOKeys: nested exception in uncaught handler: %@", handlerException);
    }

    _exit(1);
}

static void FatalSignalHandler(int signo, siginfo_t *info, void *context)
{
    static const char *signal_names[] = {
        "SIGHUP", "SIGINT", "SIGQUIT", "SIGILL", "SIGTRAP",
        "SIGABRT", "SIGEMT", "SIGFPE", "SIGKILL", "SIGBUS",
        "SIGSEGV", "SIGSYS", "SIGPIPE", "SIGALRM", "SIGTERM",
        "SIGURG", "SIGSTOP", "SIGTSTP", "SIGCONT", "SIGCHLD",
        "SIGTTIN", "SIGTTOU", "SIGIO", "SIGXCPU", "SIGXFSZ",
        "SIGVTALRM", "SIGPROF", "SIGWINCH", "SIGINFO", "SIGUSR1",
        "SIGUSR2"
    };

    const char *signame = (signo >= 1 && signo <= 31) ? signal_names[signo - 1] : "UNKNOWN";

    memset(crashReportBuffer, 0, sizeof(crashReportBuffer));
    AppendCrashInfo("=== Fatal Signal ===\n");
    AppendCrashInfo("Signal: %s (%d)\n", signame, signo);
    AppendCrashInfo("Time: %s\n", [[NSDate date] description].UTF8String);

    if (info) {
        AppendCrashInfo("Fault Address: %p\n", info->si_addr);
        AppendCrashInfo("Signal Code: %d\n", info->si_code);
    }

    AppendCrashInfo("\n");

    CaptureSystemInfo();

    AppendCrashInfo("=== Register State ===\n");
    ucontext_t *uc = (ucontext_t *)context;
    if (uc) {
#if defined(__x86_64__)
        AppendCrashInfo("RIP: 0x%llx\n", uc->uc_mcontext->__ss.__rip);
        AppendCrashInfo("RSP: 0x%llx\n", uc->uc_mcontext->__ss.__rsp);
        AppendCrashInfo("RBP: 0x%llx\n", uc->uc_mcontext->__ss.__rbp);
        AppendCrashInfo("RAX: 0x%llx\n", uc->uc_mcontext->__ss.__rax);
        AppendCrashInfo("RBX: 0x%llx\n", uc->uc_mcontext->__ss.__rbx);
        AppendCrashInfo("RCX: 0x%llx\n", uc->uc_mcontext->__ss.__rcx);
        AppendCrashInfo("RDX: 0x%llx\n", uc->uc_mcontext->__ss.__rdx);
#elif defined(__arm64__)
        AppendCrashInfo("PC: 0x%llx\n", uc->uc_mcontext->__ss.__pc);
        AppendCrashInfo("SP: 0x%llx\n", uc->uc_mcontext->__ss.__sp);
        AppendCrashInfo("FP: 0x%llx\n", uc->uc_mcontext->__ss.__fp);
        AppendCrashInfo("LR: 0x%llx\n", uc->uc_mcontext->__ss.__lr);
#endif
    }
    AppendCrashInfo("\n");

    CaptureStackTrace();

    AppendCrashInfo("=== Stack Trace (Signal Handler) ===\n");
    void *callstack[128];
    int frames = backtrace(callstack, 128);
    if (frames > 0) {
        char **symbols = backtrace_symbols(callstack, frames);
        if (symbols) {
            for (int i = 0; i < frames; i++) {
                AppendCrashInfo("%d %s\n", i, symbols[i]);
            }
            free(symbols);
        }
    }
    AppendCrashInfo("\n");

    static const char message[] = "VSCOKeys: fatal signal - writing crash report\n";
    write(STDERR_FILENO, message, sizeof(message) - 1);

    NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (dirs && dirs.count >= 1) {
        NSString *logDir = [((NSString *)[dirs objectAtIndex:0]) stringByAppendingPathComponent:@"VSCOKeysLogs"];
        NSString *filePath = [logDir stringByAppendingPathComponent:[NSString stringWithFormat:@"VSCOKeysCrash_%ld.log", (long)[[NSDate date] timeIntervalSince1970]]];

        NSString *fileContents = [NSString stringWithUTF8String:crashReportBuffer];
        [fileContents writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];

        write(STDERR_FILENO, filePath.UTF8String, filePath.length);
        write(STDERR_FILENO, "\n", 1);
    }

    _exit(128 + (signo & 0x7f));
}

static void InstallFatalSignalHandlers(void)
{
    struct sigaction action;
    memset(&action, 0, sizeof(action));
    action.sa_sigaction = FatalSignalHandler;
    action.sa_flags = SA_SIGINFO | SA_RESETHAND;
    sigemptyset(&action.sa_mask);

    sigaction(SIGABRT, &action, NULL);
    sigaction(SIGILL, &action, NULL);
    sigaction(SIGSEGV, &action, NULL);
    sigaction(SIGFPE, &action, NULL);
    sigaction(SIGBUS, &action, NULL);
    sigaction(SIGPIPE, &action, NULL);
}

- (BOOL)exceptionHandler:(NSExceptionHandler *)sender shouldHandleException:(NSException *)exception mask:(unsigned long)aMask
{
    DualLog(@"NSExceptionHandler (%lu): %@", aMask, exception);
    return NO;
}

void SetUpLogging(void)
{
    NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);

    if (dirs && dirs.count >= 1)
    {
        NSFileManager *fileMan = [NSFileManager defaultManager];
        NSString *logDir = [((NSString *)[dirs objectAtIndex:0]) stringByAppendingPathComponent:@"VSCOKeysLogs"];

        if (![fileMan fileExistsAtPath:logDir])
        {
            [fileMan createDirectoryAtPath:logDir withIntermediateDirectories:YES attributes:nil error:nil];
        }
        else
        {
            // clean up existing logs
            NSArray *files = [fileMan contentsOfDirectoryAtPath:logDir error:NULL];

            NSSortDescriptor* sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:nil ascending:NO selector:@selector(localizedCompare:)];
            files = [files sortedArrayUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];

            int count = 0;
            for (NSString *file in files)
            {
                if ([file rangeOfString:@"RunTrace"].location != NSNotFound)
                {
                    count++;

                    if (count > RUNTRACE_MAX_FILE_COUNT)
                    {
                        [fileMan removeItemAtPath:[logDir stringByAppendingPathComponent:file] error:NULL];
                    }
                }
            }
        }

        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-M-d-HH-mm-ss"];

        NSString *filestamp = [dateFormatter stringFromDate:[NSDate date]];

        traceFilePath = [logDir stringByAppendingPathComponent:[NSString stringWithFormat:@"VSCOKeysRunTrace_%@.log",filestamp]];

        [[NSFileManager defaultManager] createFileAtPath:traceFilePath contents:NULL attributes:NULL];
    }
}

void DualLog(NSString* format, ...)
{
    va_list argList;
    va_start(argList, format);
    NSString* formattedMessage = [[NSString alloc] initWithFormat: format arguments: argList];
    va_end(argList);

    NSLock *lock = DualLogLock();
    [lock lock];
    @try
    {
        NSLog(@"%@", formattedMessage);

        if (traceFilePath != NULL)
        {
            formattedMessage = [formattedMessage stringByAppendingString:@"\n"];
            NSFileHandle *myHandle = [NSFileHandle fileHandleForWritingAtPath:traceFilePath];
            [myHandle seekToEndOfFile];
            [myHandle writeData:[formattedMessage dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }
    @finally
    {
        [lock unlock];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSExceptionHandler *handler = [NSExceptionHandler defaultExceptionHandler];
    [handler setExceptionHandlingMask:NSLogUncaughtExceptionMask | NSHandleUncaughtExceptionMask];
    [handler setDelegate:self];

    NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
    InstallFatalSignalHandlers();

    SetUpLogging();

    [self checkOSVersion];

    self.keyControl = [[KeyControl alloc] init];
    self.mainController.keyControl = self.keyControl;
    self.keyControl.mainController = self.mainController;
    self.keyControl.window = self.window;  // required for showWindow

    [self.mainController setupEditorController];  // wire in-app editor

    [self checkTrusted];

    [NSThread detachNewThreadSelector:@selector(startUpEventLoop) toTarget:self.keyControl withObject:nil];
    [NSThread detachNewThreadSelector:@selector(startUpAXLoop) toTarget:self.keyControl withObject:nil];
    [NSThread detachNewThreadSelector:@selector(statusBarUpdateLoop) toTarget:self.keyControl withObject:nil];
    self.quitTimer = [NSTimer scheduledTimerWithTimeInterval:APP_RUNNING_UPDATE_RATE target:self selector:@selector(lrRunningCheckLoop) userInfo:NULL repeats:YES];

    [self.keyControl makeLRActive];
}

- (void)lrRunningCheckLoop
{
    @autoreleasepool
    {
        if (![self.keyControl isLRRunning])
        {
            DualLog(@"Application was terminated because LR was not running.");
            [self.keyControl quitApplication];
        }
    }
}

- (void)checkOSVersion
{
    NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
    NSInteger major = version.majorVersion;
    NSInteger minor = version.minorVersion;
    NSInteger bugfix = version.patchVersion;

    NSString *systemVersion = [NSString stringWithFormat:@"%ld.%ld.%ld",
                               (long)major, (long)minor, (long)bugfix];
    NSString *minSystemVersion = [NSString stringWithFormat:@"%d.%d.%d",
                               OS_VERSION_MIN_MAJOR, OS_VERSION_MIN_MINOR, OS_VERSION_MIN_BUGFIX];

    if (major < OS_VERSION_MIN_MAJOR ||
        (major == OS_VERSION_MIN_MAJOR && minor < OS_VERSION_MIN_MINOR) ||
        (major == OS_VERSION_MIN_MAJOR && minor == OS_VERSION_MIN_MINOR && bugfix < OS_VERSION_MIN_BUGFIX))
    {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Operating System Not Supported";
        alert.informativeText = [NSString stringWithFormat:@"%@ is not a supported operating system version. Minimum required version is %@", systemVersion, minSystemVersion];
        [alert addButtonWithTitle:@"Ok"];

        [alert runModal];

        exit(0);
    }
}

// Authorize Accessibility Client
- (void)checkTrusted
{
    if (!AXIsProcessTrusted())
    {
        // request permission to change settingz
        DualLog(@"process is not trusted");

        DualLog(@"Prompting for authentication.");

        AuthorizationRef auth;

        OSStatus junk = AuthorizationCreate(NULL, NULL, kAuthorizationFlagDefaults, &auth);
        assert(junk == noErr);

        [self restartToInitializePrivileges:auth];

        AuthorizationFree(auth, kAuthorizationFlagDestroyRights);
    }
}

- (void)restartToInitializePrivileges:(AuthorizationRef)auth
{
    FILE *communicationsPipe = NULL;

    char appPathArg[MAXPATHLEN];
    [[[NSBundle mainBundle] bundlePath] getCString:appPathArg maxLength:MAXPATHLEN encoding:[NSString defaultCStringEncoding]];

    char appExePathArg[MAXPATHLEN];
    [[[NSBundle mainBundle] executablePath] getCString:appExePathArg maxLength:MAXPATHLEN encoding:[NSString defaultCStringEncoding]];

    char pidString[MAXPATHLEN];
    [[NSString stringWithFormat:@"%d", [[NSProcessInfo processInfo] processIdentifier]] getCString:pidString maxLength:MAXPATHLEN encoding:[NSString defaultCStringEncoding]];


    char *args[] = { appPathArg, appExePathArg, pidString, NULL };
    char toolPathString[MAXPATHLEN];

    NSString* path = [[NSBundle mainBundle] pathForResource:@"VSCOKeysActivator" ofType:nil];

    [path getCString:toolPathString maxLength:MAXPATHLEN encoding:[NSString defaultCStringEncoding]];

    #pragma GCC diagnostic ignored "-Wdeprecated"
    OSStatus status = AuthorizationExecuteWithPrivileges (auth,
                                                          toolPathString, kAuthorizationFlagDefaults, args,
                                                          &communicationsPipe);
    #pragma GCC diagnostic pop

    if (status != noErr)
    {
        // auth failed
        DualLog(@"Authentication failed: %d", status);
    }

    [[NSApplication sharedApplication] terminate:nil];
}


#pragma mark File Handling Methods

- (IBAction)openFileManually:(id)sender;
{
    NSOpenPanel *openPanel  = [NSOpenPanel openPanel];
    NSArray *fileTypes = [NSArray arrayWithObjects:@"xml",nil];
    NSInteger result  = [openPanel runModalForDirectory:NSHomeDirectory() file:nil types:fileTypes ];
    if(result == NSOKButton){
        [self processFile:[openPanel filename]];
    }
}

- (BOOL)processFile:(NSString *)file
{
    [self.keyControl importKeyFile:file];

    return YES;
}

#pragma mark File Handling Delegate Methods

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
    return [self processFile:filename];
}


@end
