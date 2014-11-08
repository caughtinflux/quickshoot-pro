/*
*       ____        _      __   _____ __                __  ____           
*      / __ \__  __(_)____/ /__/ ___// /_  ____  ____  / /_/ __ \_________ 
*     / / / / / / / / ___/ //_/\__ \/ __ \/ __ \/ __ \/ __/ /_/ / ___/ __ \
*    / /_/ / /_/ / / /__/ ,<  ___/ / / / / /_/ / /_/ / /_/ ____/ /  / /_/ /
*    \___\_\__,_/_/\___/_/|_|/____/_/ /_/\____/\____/\__/_/   /_/   \____/ 
*                                                                          
*   QSVideoInterface.m
*   © 2013 Aditya KD
*/

#import "QSVideoInterface.h"
#import "QSConstants.h"

#import <UIKit/UIKit.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <CommonCrypto/CommonDigest.h>
#import <CoreFoundation/CoreFoundation.h>
#import <SpringBoard/SpringBoard.h>

@interface QSVideoInterface ()
{
    AVCaptureDevice *_videoCaptureDevice;
    AVCaptureDevice *_audioCaptureDevice;
    AVCaptureSession *_captureSession;
    AVCaptureMovieFileOutput *_fileOutput;

    dispatch_queue_t _bgQueue;
}

- (void)_configureCaptureSession;
- (BOOL)_configureCaptureDevices;
- (BOOL)_configureDeviceInputs;
- (BOOL)_configureFileOutput;
- (void)_orientationChanged:(NSNotification *)notification;

@end

@implementation QSVideoInterface {}
- (instancetype)init
{
    if ((self = [super init])) {
        _bgQueue = dispatch_queue_create("com.caughtinflux.quickshootpro.backgroundyoloqueue", NULL);
    }
    return self;
}

- (void)dealloc
{
    DLog();
    [_captureSession release];
    _captureSession = nil;

    [_captureSession release];
    _captureSession = nil;

    [_fileOutput release];
    _fileOutput = nil;

    [_videoQuality release];
    _videoQuality = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    dispatch_release(_bgQueue);
    [super dealloc];
}

- (NSString *)_UUIDString
{
    return [[NSUUID UUID] UUIDString];
}


#pragma mark - Public Methods
- (void)startVideoCapture
{
    dispatch_async(_bgQueue, ^{
       [self _configureCaptureSession];
       if ([self _configureCaptureDevices] && [self _configureDeviceInputs] && [self _configureFileOutput]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                // set up orientation events
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
                [self _orientationChanged:nil]; // force an update
                dispatch_async(_bgQueue, ^(void){
                    NSString *filePath = [NSString stringWithFormat:@"%@quickshoot_%@.mov", NSTemporaryDirectory(), [self _UUIDString]];
                    [_captureSession startRunning];
                    [_fileOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:filePath] recordingDelegate:self];    
                });
            });
        }
    });
}

- (void)stopVideoCapture
{
    dispatch_async(_bgQueue, ^{
        if (_captureSession && [_captureSession isRunning]) {
            [_captureSession stopRunning];
            [_fileOutput stopRecording];
        }
    });
}

- (void)setTorchModeFromFlashMode:(QSFlashMode)flashMode
{
    if (flashMode == QSFlashModeAuto) {
        self.torchMode = AVCaptureTorchModeAuto;
        CLog(@"Setting AVCaptureTorchModeAuto");
    }
    if (flashMode == QSFlashModeOn) {
        self.torchMode = AVCaptureTorchModeOn;
        CLog(@"Setting AVCaptureTorchModeOn");
    }
    if (flashMode == QSFlashModeOff) {
        self.torchMode = AVCaptureTorchModeOff;
        CLog(@"Setting AVCaptureTorchModeOff");
    }
}

#pragma mark - Getter Overrides (Defaults)
- (AVCaptureDevicePosition)devicePosition
{
    if (!_devicePosition) {
        _devicePosition = AVCaptureDevicePositionBack;
    }
    return _devicePosition;
}

- (NSString *)videoQuality
{
    if (!_videoQuality) {
        _videoQuality = AVCaptureSessionPresetMedium;
    }
    return _videoQuality;
}


#pragma mark - Capture Config Methods
- (void)_configureCaptureSession
{
    _captureSession = [[AVCaptureSession alloc] init];
    
    NSString *sessionPreset = self.videoQuality;
    if ([_captureSession canSetSessionPreset:sessionPreset] == NO || (self.devicePosition != AVCaptureDevicePositionBack)) {
        sessionPreset = AVCaptureSessionPresetMedium;
    }
    else {
        _captureSession.sessionPreset = sessionPreset;
    }

    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self selector:@selector(_sessionNotificationReceived:) name:AVCaptureSessionDidStartRunningNotification object:nil];
    [notificationCenter addObserver:self selector:@selector(_sessionNotificationReceived:) name:AVCaptureSessionDidStopRunningNotification object:nil];
    [notificationCenter addObserver:self selector:@selector(_sessionNotificationReceived:) name:AVCaptureSessionWasInterruptedNotification object:nil];
}

- (BOOL)_configureCaptureDevices
{
    // Add video and audio devices
    BOOL success = YES;
    NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in videoDevices) {
        if (device.position == self.devicePosition) {
            _videoCaptureDevice = device;
        }
    }
    if (!_videoCaptureDevice) {
        success = NO;
        goto error;
    }

    NSError *lockError = nil;
    if ([_videoCaptureDevice lockForConfiguration:&lockError]) {
        NSLog(@"Locked video capture device for configuration");
        if ([_videoCaptureDevice hasTorch] && [_videoCaptureDevice isTorchModeSupported:self.torchMode]) {
            NSLog(@"Setting torch mode: %zd", self.torchMode);
            _videoCaptureDevice.torchMode = self.torchMode;
        }
        if ([_videoCaptureDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
            _videoCaptureDevice.focusMode = AVCaptureFocusModeContinuousAutoFocus;
        }
        if ([_videoCaptureDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
            _videoCaptureDevice.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
        }
        if (!([_videoCaptureDevice supportsAVCaptureSessionPreset:self.videoQuality])) {
            [_captureSession setSessionPreset:AVCaptureSessionPresetMedium];
            NSLog(@"QS: Doesn't support preset %@, setting to medium ", self.videoQuality);
        }
        [_videoCaptureDevice unlockForConfiguration];

        success = YES;
    }
    else {
        NSLog(@"QS: An error occurred while trying to acquire a lock for video configuration: %zd %@ with device: %@", lockError.code, lockError.localizedDescription, _videoCaptureDevice);
        success = NO;
        goto error;
    }

    _audioCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    if (!_audioCaptureDevice) {
        NSLog(@"QS: Can't get audio capture device :(");
        success = NO;
        goto error;
    }

error:
    if (!success) {
        if ([self.delegate respondsToSelector:@selector(videoInterfaceCaptureDeviceErrorOccurred:)]) {
            [self.delegate videoInterfaceCaptureDeviceErrorOccurred:self];
        }
    }
    return success;
}

- (BOOL)_configureDeviceInputs
{
    NSError *videoError = nil;
    NSError *audioError = nil;
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:_videoCaptureDevice error:&videoError];
    AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:_audioCaptureDevice error:&audioError];

    [_captureSession beginConfiguration];
    if (!videoInput || videoError) {
        NSLog(@"QS: Couldn't obtain video input! Error %zd %@", videoError.code, videoError.localizedDescription);
        goto notifyDelegateOfError;
    }
    if (!audioInput || audioError) {
        NSLog(@"QS: Couldn't obtain audio input! Error %zd %@", audioError.code, audioError.localizedDescription);
        goto notifyDelegateOfError;
    }
    if ([_captureSession canAddInput:videoInput]) { // video
        [_captureSession addInput:videoInput];
    }
    else {
        NSLog(@"QS: Video interface was not able to add video Input to session!");
        goto notifyDelegateOfError;
    }
    if ([_captureSession canAddInput:audioInput]) { // audio
        [_captureSession addInput:audioInput];
    }
    else {
        NSLog(@"QS: Video interface unable to add audio input to current session!");
        goto notifyDelegateOfError;
    }
    [_captureSession commitConfiguration];
    return YES;

notifyDelegateOfError:
        [_captureSession commitConfiguration];
        if ([self.delegate respondsToSelector:@selector(videoInterfaceCaptureDeviceErrorOccurred:)]) {
            [self.delegate videoInterfaceCaptureDeviceErrorOccurred:self];
        }
        return NO;
}

- (BOOL)_configureFileOutput
{
    _fileOutput = [[AVCaptureMovieFileOutput alloc] init];
    // [_fileOutput connectionWithMediaType:AVMediaTypeVideo].enablesVideoStabilizationWhenAvailable = YES;
    if ([_captureSession canAddOutput:_fileOutput]) {
        [_captureSession addOutput:_fileOutput];
        return YES;
    }
    else {
        return NO;
    }
}

- (void)_orientationChanged:(NSNotification *)notification
{
    // stolen from AVCam!
    UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];

    AVCaptureVideoOrientation newOrientation;

    if (deviceOrientation == UIDeviceOrientationPortrait) {
        DLog(@"deviceOrientationDidChange - Portrait");
        newOrientation = AVCaptureVideoOrientationPortrait;
    }
    else if (deviceOrientation == UIDeviceOrientationPortraitUpsideDown) {
        DLog(@"deviceOrientationDidChange - UpsideDown");
        newOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
    }
    // AVCapture and UIDevice have opposite meanings for landscape left and right (AVCapture orientation is the same as UIInterfaceOrientation)
    else if (deviceOrientation == UIDeviceOrientationLandscapeLeft) {
        DLog(@"deviceOrientationDidChange - LandscapeLeft");
        newOrientation = AVCaptureVideoOrientationLandscapeRight;
    }
    else if (deviceOrientation == UIDeviceOrientationLandscapeRight) {
        DLog(@"deviceOrientationDidChange - LandscapeRight");
        newOrientation = AVCaptureVideoOrientationLandscapeLeft;
    }
    else if (deviceOrientation == UIDeviceOrientationUnknown) {
        DLog(@"deviceOrientationDidChange - Unknown ");
        newOrientation = AVCaptureVideoOrientationPortrait;
    }
    else {
        DLog(@"deviceOrientationDidChange - Face Up or Down");
        newOrientation = AVCaptureVideoOrientationPortrait;
    }
    [[_fileOutput connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:newOrientation];
}

#pragma mark - AVCaptureFileOutput Delegate
- (void)captureOutput:(AVCaptureFileOutput *)ouput didFinishRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    BOOL recordedSuccessfully = YES;
    if ([error code] != noErr) {
        id value = [[error userInfo] objectForKey:AVErrorRecordingSuccessfullyFinishedKey];
        if (value) {
            recordedSuccessfully = [value boolValue];
        }
    }
    if (!recordedSuccessfully) {
        NSLog(@"QS: An error occurred when recording to file: %@ Error: %zd, %@", [fileURL absoluteString], error.code, error.localizedDescription);
    }
    else {
        error = nil; // don't let the delegate know that an error occurred if it recorded successfully
    }
    if ([self.delegate respondsToSelector:@selector(videoInterface:didFinishRecordingToURL:withError:)]) {
        // notify the delegate, yeah?
        [self.delegate videoInterface:self didFinishRecordingToURL:fileURL withError:error];
    }
}

#pragma mark - AVCaptureSession Notifications Handler
- (void)_sessionNotificationReceived:(NSNotification *)notification
{
    CLog(@"%@", notification.name);
    if ([notification.name isEqualToString:AVCaptureSessionDidStartRunningNotification]) {
        _videoCaptureSessionRunning = YES;
        if ([self.delegate respondsToSelector:@selector(videoInterfaceStartedVideoCapture:)]) {
            [self.delegate videoInterfaceStartedVideoCapture:self];
        }
    }
    else if ([notification.name isEqualToString:AVCaptureSessionDidStopRunningNotification]) {
        _videoCaptureSessionRunning = NO;
        if ([self.delegate respondsToSelector:@selector(videoInterfaceStoppedVideoCapture:)]) {
            [self.delegate videoInterfaceStoppedVideoCapture:self];
        }
    }
    else if ([notification.name isEqualToString:AVCaptureSessionWasInterruptedNotification]) {
        _videoCaptureSessionRunning = NO;
        SHOW_USER_NOTIFICATION(@"QuickShoot Pro", @"Video recording interrupted", @"Dismiss");
    }
}

@end
