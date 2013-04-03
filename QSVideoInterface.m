#import "QSVideoInterface.h"
#import "QSConstants.h"

#import <AssetsLibrary/AssetsLibrary.h>
#import <CommonCrypto/CommonDigest.h>
#import <CoreFoundation/CoreFoundation.h>

@interface QSVideoInterface ()
{
    AVCaptureDevice          *_videoCaptureDevice;
    AVCaptureDevice          *_audioCaptureDevice;
    AVCaptureSession         *_captureSession;
    AVCaptureMovieFileOutput *_fileOutput;

    dispatch_queue_t          _backgroundCauseYOLOQueue;
}

- (void)_configureCaptureSession;
- (BOOL)_configureCaptureDevices;
- (BOOL)_configureDeviceInputs;
- (BOOL)_configureFileOutput;

@end

@implementation QSVideoInterface {}
- (instancetype)init
{
    if ((self = [super init])) {
        _backgroundCauseYOLOQueue = dispatch_queue_create("com.caughtinflux.quickshootpro.backgroundyoloqueue", NULL);
    }
    return self;
}

- (NSString *)_UUIDString
{
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    return [(NSString *)string autorelease];
}


#pragma mark - Public Methods
- (void)startVideoCapture
{
    dispatch_async(_backgroundCauseYOLOQueue, ^{
       [self _configureCaptureSession];

       if ([self _configureCaptureDevices] && [self _configureDeviceInputs] && [self _configureFileOutput]) {
            // use a randomized file path.
            NSString *filePath = [NSString stringWithFormat:@"%@_quickshoot_temp_record_%@.mov", NSTemporaryDirectory(), [self _UUIDString]];
            [_captureSession startRunning];
            [_fileOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:filePath] recordingDelegate:self];
        }
    });
}

- (void)stopVideoCapture
{
    DLog(@"");
    dispatch_async(_backgroundCauseYOLOQueue, ^{
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
    }
    if (flashMode == QSFlashModeOn) {
        self.torchMode = AVCaptureTorchModeOn;
    }
    if (flashMode == QSFlashModeOff) {
        self.torchMode = AVCaptureTorchModeOff;
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
        DLog(@"Setting torch mode: %i", self.torchMode);
        if ([_videoCaptureDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
            _videoCaptureDevice.focusMode = AVCaptureFocusModeContinuousAutoFocus;
        }
        if ([_videoCaptureDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
            _videoCaptureDevice.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
        }
        if ([_videoCaptureDevice hasTorch] && [_videoCaptureDevice isTorchModeSupported:self.torchMode]) {
            _videoCaptureDevice.torchMode = self.torchMode;
        }
        if (!([_videoCaptureDevice supportsAVCaptureSessionPreset:self.videoQuality])) {
            success = NO;
            DLog(@"doesn't support preset");
            goto error;
        }
        [_videoCaptureDevice unlockForConfiguration];

        success = YES;
    }
    else {
        DLog(@"QS: An error occurred while trying to acquire a lock for video configuration: %i %@ with device: %@", lockError.code, lockError.localizedDescription, _videoCaptureDevice);
        success = NO;
        goto error;
    }

    _audioCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    if (!_audioCaptureDevice) {
        DLog(@"QS: Can't get AVCaptureDevice");
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
        DLog(@"QS: Couldn't obtain video input! Error %i %@", videoError.code, videoError.localizedDescription);
        goto notifyDelegateOfError;
    }
    if (!audioInput || audioError) {
        DLog(@"QS: Couldn't obtain audio input! Error %i %@", audioError.code, audioError.localizedDescription);
        goto notifyDelegateOfError;
    }
    if ([_captureSession canAddInput:videoInput]) { // video
        [_captureSession addInput:videoInput];
    }
    else {
        DLog(@"QS: Video interface was not able to add video Input to session!");
        goto notifyDelegateOfError;
    }
    if ([_captureSession canAddInput:audioInput]) { // audio
        [_captureSession addInput:audioInput];
    }
    else {
        DLog(@"QS: Video interface unable to add audio input to current session!");
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
    if ([_captureSession canAddOutput:_fileOutput]) {
        [_captureSession addOutput:_fileOutput];
        return YES;
    }
    else {
        return NO;
    }
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
        NSLog(@"QS: An error occurred when recording to file: %@ \n Error: %i, %@", [fileURL absoluteString], error.code, error.localizedDescription);
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
    if ([self.delegate respondsToSelector:@selector(videoInterfaceStartedVideoCapture:)] && [notification.name isEqualToString:AVCaptureSessionDidStartRunningNotification]) {
        [self.delegate videoInterfaceStartedVideoCapture:self];
    }
}

- (void)dealloc
{
    [_captureSession release];
    _captureSession = nil;

    [_captureSession release];
    _captureSession = nil;

    [_fileOutput release];
    _fileOutput = nil;

    [_videoQuality release];
    _videoQuality = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    dispatch_release(_backgroundCauseYOLOQueue);
    [super dealloc];
}

@end