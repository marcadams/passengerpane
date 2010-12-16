#import "CLI.h"

@implementation CLI

static id sharedCLI = nil;

+ (id)sharedInstance{
  if (sharedCLI == nil) {
    sharedCLI = [[CLI alloc] init];
  }
  return sharedCLI;
}

@synthesize pathToCLI;

- (id)init {
  if ((self = [super init])) {
    authorizationRef = NULL;
  }
  return self;
}

- (NSArray *)listApplications {
  NSArray *applications;
  
  [self execute:[NSArray arrayWithObjects:@"list", @"-m", nil] elevated:NO];
  
  return applications;
}

- (NSDictionary *)execute:(NSArray *)arguments elevated:(BOOL)elevated {
  if (elevated) {
    return [NSDictionary dictionary];
  } else {
    return [self execute:arguments];
  }
}

- (NSDictionary *)execute:(NSArray *)arguments {
  NSPipe *stdout = [NSPipe pipe];
  NSTask *ppane;
  NSDictionary *output = [NSDictionary dictionary];
  
  ppane = [[[NSTask alloc] init] autorelease];
  [ppane setLaunchPath:pathToCLI];
  [ppane setArguments:arguments];
  [ppane setStandardOutput:[stdout fileHandleForWriting]];
  [ppane launch];
  [ppane waitUntilExit];
  
  if ([ppane terminationStatus] == PPANE_SUCCESS) {
    NSLog(@"%@", [[NSString alloc] initWithData:[[stdout fileHandleForReading] availableData] encoding:NSASCIIStringEncoding]);
  }
  
  return output;
}

// Inspired by: http://svn.kismac-ng.org/kmng/trunk/Subprojects/BIGeneric/BLAuthentication.m
- (BOOL)executeCommand:(NSString *)pathToCommand withArgs:(NSArray *)arguments {
  char** args;
  OSStatus err = 0;
  unsigned int i = 0;
  
  if (arguments == nil || [arguments count] < 1) { 
    err = AuthorizationExecuteWithPrivileges(authorizationRef, (char *)pathToCommand, 0, NULL, NULL);
  } else  {
    args = malloc(sizeof(char*) * [arguments count]);
    while(i < [arguments count] && i < 19) {
      args[i] = (char*)[[arguments objectAtIndex:i] UTF8String];
      i++;
    }
    args[i] = NULL;
    err = AuthorizationExecuteWithPrivileges(authorizationRef, (char *)pathToCommand, 0, args, NULL);
    free(args);
  }
  
  if (err != 0)  {
    NSBeep();
    NSLog(@"Error %d in AuthorizationExecuteWithPrivileges",err);
    return NO;
  } else  {
    return YES;
  }
}

- (AuthorizationRef) authorizationRef {
  return authorizationRef;
}

- (void) setAuthorizationRef:(AuthorizationRef)ref {
  authorizationRef = ref;
}

-(void)deauthorize {
  authorizationRef = NULL;
}

-(BOOL)isAuthorized {
  if (authorizationRef == NULL) {
    return NO;
  } else  {
    return YES;
  }
}


@end
