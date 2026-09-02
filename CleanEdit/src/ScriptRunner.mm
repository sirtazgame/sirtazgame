#import "ScriptRunner.h"
#import "EditorBridge.h"
#import <JavaScriptCore/JavaScriptCore.h>

#pragma mark - JavaScript

@implementation JSScriptRunner

+ (void)runScriptAtPath:(NSString *)path host:(id<EditorHost>)host {
    NSError *err = nil;
    NSString *src = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
    if (!src) {
        [host appendConsole:[NSString stringWithFormat:@"Could not read script: %@", err.localizedDescription]
                       type:@"error"];
        return;
    }

    JSContext *ctx = [[JSContext alloc] init];
    EditorBridge *bridge = [[EditorBridge alloc] initWithHost:host];
    ctx[@"editor"] = bridge;

    // console.log support
    JSValue *console = [JSValue valueWithNewObjectInContext:ctx];
    console[@"log"] = ^(NSString *msg) {
        [host appendConsole:msg ?: @"" type:@"output"];
    };
    ctx[@"console"] = console;

    ctx.exceptionHandler = ^(JSContext *c, JSValue *e) {
        [host appendConsole:[NSString stringWithFormat:@"JS Error: %@", e] type:@"error"];
    };

    [host appendConsole:[NSString stringWithFormat:@"\u25B6 Running %@", path.lastPathComponent] type:@"info"];
    [ctx evaluateScript:src];
    [host appendConsole:@"\u2713 Finished" type:@"success"];
}

@end

#pragma mark - Python

static NSMutableArray *gRunningTasks;  // keep NSTask instances alive

@implementation PythonScriptRunner

+ (void)initialize {
    if (self == [PythonScriptRunner class]) {
        gRunningTasks = [NSMutableArray array];
    }
}

+ (void)runScriptAtPath:(NSString *)path
              scriptsDir:(NSString *)scriptsDir
                    host:(id<EditorHost>)host {
    NSString *tmp = NSTemporaryDirectory();
    NSString *inputPath = [tmp stringByAppendingPathComponent:@"cleanedit_input.txt"];
    NSString *selPath = [tmp stringByAppendingPathComponent:@"cleanedit_selection.txt"];
    [([host editorText] ?: @"") writeToFile:inputPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [([host editorSelection] ?: @"") writeToFile:selPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/env";
    task.arguments = @[@"python3", path];

    NSMutableDictionary *env = [[[NSProcessInfo processInfo] environment] mutableCopy];
    env[@"CLEANEDIT_INPUT"] = inputPath;
    env[@"CLEANEDIT_SELECTION"] = selPath;
    env[@"CLEANEDIT_FILE"] = [host currentFilePath] ?: @"";
    NSString *existing = env[@"PYTHONPATH"];
    env[@"PYTHONPATH"] = existing.length
        ? [NSString stringWithFormat:@"%@:%@", scriptsDir, existing]
        : scriptsDir;
    env[@"PYTHONUNBUFFERED"] = @"1";
    task.environment = env;

    NSPipe *outPipe = [NSPipe pipe];
    NSPipe *errPipe = [NSPipe pipe];
    task.standardOutput = outPipe;
    task.standardError = errPipe;

    EditorBridge *bridge = [[EditorBridge alloc] initWithHost:host];
    NSMutableString *outBuffer = [NSMutableString string];
    NSMutableString *errBuffer = [NSMutableString string];
    NSString *marker = @"##CE##";

    [host appendConsole:[NSString stringWithFormat:@"\u25B6 Running %@", path.lastPathComponent] type:@"info"];

    outPipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle *fh) {
        NSData *data = fh.availableData;
        if (data.length == 0) return;
        NSString *chunk = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
        dispatch_async(dispatch_get_main_queue(), ^{
            [outBuffer appendString:chunk];
            NSRange nl;
            while ((nl = [outBuffer rangeOfString:@"\n"]).location != NSNotFound) {
                NSString *line = [outBuffer substringToIndex:nl.location];
                [outBuffer deleteCharactersInRange:NSMakeRange(0, nl.location + 1)];
                if ([line hasPrefix:marker]) {
                    NSString *json = [line substringFromIndex:marker.length];
                    NSData *jd = [json dataUsingEncoding:NSUTF8StringEncoding];
                    NSDictionary *cmd = [NSJSONSerialization JSONObjectWithData:jd options:0 error:nil];
                    if ([cmd isKindOfClass:[NSDictionary class]]) {
                        [bridge applyCommand:cmd];
                    }
                } else {
                    [host appendConsole:line type:@"output"];
                }
            }
        });
    };

    errPipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle *fh) {
        NSData *data = fh.availableData;
        if (data.length == 0) return;
        NSString *chunk = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
        dispatch_async(dispatch_get_main_queue(), ^{
            [errBuffer appendString:chunk];
            NSRange nl;
            while ((nl = [errBuffer rangeOfString:@"\n"]).location != NSNotFound) {
                NSString *line = [errBuffer substringToIndex:nl.location];
                [errBuffer deleteCharactersInRange:NSMakeRange(0, nl.location + 1)];
                [host appendConsole:line type:@"error"];
            }
        });
    };

    task.terminationHandler = ^(NSTask *t) {
        outPipe.fileHandleForReading.readabilityHandler = nil;
        errPipe.fileHandleForReading.readabilityHandler = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (errBuffer.length) { [host appendConsole:errBuffer type:@"error"]; }
            [host appendConsole:@"\u2713 Finished" type:@"success"];
            [gRunningTasks removeObject:t];
        });
    };

    @try {
        [gRunningTasks addObject:task];
        [task launch];
    } @catch (NSException *ex) {
        [gRunningTasks removeObject:task];
        [host appendConsole:[NSString stringWithFormat:@"Failed to run python3: %@. Is Python 3 installed?", ex.reason]
                       type:@"error"];
    }
}

@end
