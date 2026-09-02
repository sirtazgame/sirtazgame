#import "ScriptManager.h"
#import "ScriptRunner.h"

@implementation ScriptManager

+ (instancetype)shared {
    static ScriptManager *inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [[ScriptManager alloc] init]; });
    return inst;
}

- (NSURL *)scriptsDirectory {
    NSURL *support = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
                                                            inDomain:NSUserDomainMask
                                                   appropriateForURL:nil
                                                              create:YES
                                                               error:nil];
    NSURL *dir = [[support URLByAppendingPathComponent:@"CleanEdit"]
                  URLByAppendingPathComponent:@"scripts"];
    return dir;
}

- (NSURL *)extensionsDirectory {
    NSURL *support = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
                                                            inDomain:NSUserDomainMask
                                                   appropriateForURL:nil
                                                              create:YES
                                                               error:nil];
    return [[support URLByAppendingPathComponent:@"CleanEdit"] URLByAppendingPathComponent:@"extensions"];
}

- (void)ensureScriptsInstalled {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *dir = self.scriptsDirectory;
    [fm createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    [fm createDirectoryAtURL:self.extensionsDirectory withIntermediateDirectories:YES attributes:nil error:nil];

    NSString *bundled = [[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:@"scripts"];
    NSArray *files = [fm contentsOfDirectoryAtPath:bundled error:nil];
    for (NSString *file in files) {
        NSURL *dest = [dir URLByAppendingPathComponent:file];
        if (![fm fileExistsAtPath:dest.path]) {
            NSString *srcPath = [bundled stringByAppendingPathComponent:file];
            [fm copyItemAtPath:srcPath toPath:dest.path error:nil];
        }
    }
}

- (NSArray<NSURL *> *)availableScripts {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSURL *> *contents = [fm contentsOfDirectoryAtURL:self.scriptsDirectory
                                  includingPropertiesForKeys:nil
                                                     options:0
                                                       error:nil];
    NSMutableArray *result = [NSMutableArray array];
    for (NSURL *u in contents) {
        NSString *ext = u.pathExtension.lowercaseString;
        if ([u.lastPathComponent isEqualToString:@"cleanedit.py"]) continue;
        if ([ext isEqualToString:@"js"] || [ext isEqualToString:@"py"]) {
            [result addObject:u];
        }
    }
    [result sortUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
        return [a.lastPathComponent caseInsensitiveCompare:b.lastPathComponent];
    }];
    return result;
}

- (NSString *)promptMessageInSource:(NSString *)src {
    if (!src.length) return nil;
    NSError *err = nil;
    NSRegularExpression *re = [NSRegularExpression
        regularExpressionWithPattern:@"^\\s*(?://|#)\\s*@prompt:?\\s*(.+)$"
                              options:NSRegularExpressionAnchorsMatchLines error:&err];
    if (!re) return nil;
    NSTextCheckingResult *m = [re firstMatchInString:src options:0 range:NSMakeRange(0, src.length)];
    if (!m) return nil;
    NSString *msg = [src substringWithRange:[m rangeAtIndex:1]];
    return [msg stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

- (NSString *)askArgumentWithMessage:(NSString *)message forScript:(NSString *)name {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = name;
    alert.informativeText = message.length ? message : @"Enter a value";
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 260, 24)];
    alert.accessoryView = input;
    [alert addButtonWithTitle:@"Run"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert.window setInitialFirstResponder:input];
    if ([alert runModal] != NSAlertFirstButtonReturn) return nil;  // cancelled
    return input.stringValue;
}

- (void)runScriptAtURL:(NSURL *)url host:(id<EditorHost>)host {
    NSString *ext = url.pathExtension.lowercaseString;
    NSError *readErr = nil;
    NSString *src = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&readErr];
    if (!src) {
        [host appendConsole:[NSString stringWithFormat:@"Could not read %@: %@",
                             url.lastPathComponent, readErr.localizedDescription ?: @"unknown error"]
                       type:@"error"];
        return;
    }

    NSString *arg = @"";
    NSString *promptMsg = [self promptMessageInSource:src];
    if (promptMsg) {
        NSString *value = [self askArgumentWithMessage:promptMsg forScript:url.lastPathComponent];
        if (value == nil) return;  // user cancelled -> don't run
        arg = value;
    }

    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"HH:mm:ss";
    [host appendConsole:[NSString stringWithFormat:@"%@  %@", url.lastPathComponent, [df stringFromDate:[NSDate date]]]
                   type:@"section"];

    if ([ext isEqualToString:@"js"]) {
        [JSScriptRunner runScriptAtPath:url.path argument:arg host:host];
    } else if ([ext isEqualToString:@"py"]) {
        [PythonScriptRunner runScriptAtPath:url.path
                                 scriptsDir:self.scriptsDirectory.path
                                   argument:arg
                                       host:host];
    } else {
        [host appendConsole:@"Unsupported script type (use .js or .py)." type:@"error"];
    }
}

- (void)runStartupExtensionsWithHost:(id<EditorHost>)host {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSURL *> *contents = [fm contentsOfDirectoryAtURL:self.extensionsDirectory
                                  includingPropertiesForKeys:nil options:0 error:nil];
    NSArray *sorted = [contents sortedArrayUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
        return [a.lastPathComponent caseInsensitiveCompare:b.lastPathComponent];
    }];
    for (NSURL *u in sorted) {
        NSString *ext = u.pathExtension.lowercaseString;
        if ([ext isEqualToString:@"js"]) {
            [host appendConsole:[NSString stringWithFormat:@"extension: %@", u.lastPathComponent] type:@"section"];
            [JSScriptRunner runScriptAtPath:u.path argument:@"" host:host];
        } else if ([ext isEqualToString:@"py"]) {
            [host appendConsole:[NSString stringWithFormat:@"extension: %@", u.lastPathComponent] type:@"section"];
            [PythonScriptRunner runScriptAtPath:u.path scriptsDir:self.scriptsDirectory.path argument:@"" host:host];
        }
    }
}


- (NSURL *)createNewScriptWithName:(NSString *)name {
    NSURL *url = [self.scriptsDirectory URLByAppendingPathComponent:name];
    NSString *ext = url.pathExtension.lowercaseString;
    NSString *contents;
    if ([ext isEqualToString:@"py"]) {
        contents = @"import cleanedit\n\n# Your script here.\ncleanedit.log(\"Hello from a new Python script!\")\n";
    } else {
        contents = @"// Your script here.\neditor.log(\"Hello from a new JavaScript script!\");\n";
    }
    [contents writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:nil];
    return url;
}

@end
