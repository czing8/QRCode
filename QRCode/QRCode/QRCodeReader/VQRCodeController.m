//
//  VQRCodeController.m
//  QRCode
//
//  Created by Vols on 16/4/2.
//  Copyright © 2016年 Vols. All rights reserved.
//

#import "VQRCodeController.h"
#import <AVFoundation/AVFoundation.h>

#define kDefaultscanCrop CGRectMake(self.view.center.x - 130, self.view.center.y - 130, 260, 260)

@interface VQRCodeController ()<AVCaptureMetadataOutputObjectsDelegate, UIAlertViewDelegate>
{
    AVCaptureSession * _captureSession; //输入输出的中间桥梁
    AVCaptureVideoPreviewLayer * _videoPreviewLayer;

    BOOL _isReading;
    UIView *_highlightView;
    CGRect  _scanCrop;
}

@property (nonatomic, strong) UIView *overlayView;
@property (nonatomic, strong) UIImageView *scanView;
@property (nonatomic, strong) UIImageView *lineView;
@property (nonatomic, strong) UIButton *leftButton;

@property (nonatomic, strong) UIButton *lightButton;


@end

@implementation VQRCodeController

- (id)init {
    self = [super init];
    if (self) {
        _scanCrop = kDefaultscanCrop;
    }
    return self;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    _scanCrop = kDefaultscanCrop;

    [self.view addSubview:self.overlayView];
    [self overlayClipping];

    [self.view addSubview:self.scanView];
    [self.view addSubview:self.lineView];
    [self.view addSubview:self.leftButton];
    [self.view addSubview:self.lightButton];
    
    [self startReading];
}

#pragma mark - 配置相机属性

- (BOOL)startReading {

    NSError *error;
    _isReading = YES;

    AVCaptureDevice         * device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput    * input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    AVCaptureMetadataOutput * output = [[AVCaptureMetadataOutput alloc]init];
    
    if (!input) {
        NSLog(@"%@", [error localizedDescription]);
        return NO;
    }

    //设置代理 在主线程里刷新
    [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    output.rectOfInterest = [self getScanCrop:_scanCrop readerViewBounds:self.view.frame];
    
    _captureSession = [[AVCaptureSession alloc]init];
    [_captureSession setSessionPreset:AVCaptureSessionPresetHigh];
    [_captureSession addInput:input];
    
    if (output) {
        [_captureSession addOutput:output];
        //设置扫码支持的编码格式(如下设置条形码和二维码兼容)
        NSMutableArray *a = [[NSMutableArray alloc] init];
        if ([output.availableMetadataObjectTypes containsObject:AVMetadataObjectTypeQRCode]) {
            [a addObject:AVMetadataObjectTypeQRCode];
        }
        if ([output.availableMetadataObjectTypes containsObject:AVMetadataObjectTypeEAN13Code]) {
            [a addObject:AVMetadataObjectTypeEAN13Code];
        }
        if ([output.availableMetadataObjectTypes containsObject:AVMetadataObjectTypeEAN8Code]) {
            [a addObject:AVMetadataObjectTypeEAN8Code];
        }
        if ([output.availableMetadataObjectTypes containsObject:AVMetadataObjectTypeCode128Code]) {
            [a addObject:AVMetadataObjectTypeCode128Code];
        }
        output.metadataObjectTypes = a;
    }
    
    _videoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_captureSession];
    _videoPreviewLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;
    _videoPreviewLayer.frame = self.view.layer.bounds;
    [self.view.layer insertSublayer:_videoPreviewLayer atIndex:0];

    [_captureSession addObserver:self forKeyPath:@"running" options:NSKeyValueObservingOptionNew context:nil];
    
    [_captureSession startRunning];

    return YES;
}


- (void)overlayClipping {
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    CGMutablePathRef path = CGPathCreateMutable();
    // Left side of the ratio view
    CGPathAddRect(path, nil, CGRectMake(0, 0,
                                        self.scanView.frame.origin.x,
                                        self.overlayView.frame.size.height));
    // Right side of the ratio view
    CGPathAddRect(path, nil, CGRectMake(
                                        self.scanView.frame.origin.x + self.scanView.frame.size.width,
                                        0,
                                        self.overlayView.frame.size.width - self.scanView.frame.origin.x - self.scanView.frame.size.width,
                                        self.overlayView.frame.size.height));
    // Top side of the ratio view
    CGPathAddRect(path, nil, CGRectMake(0, 0,
                                        self.overlayView.frame.size.width,
                                        self.scanView.frame.origin.y));
    // Bottom side of the ratio view
    CGPathAddRect(path, nil, CGRectMake(0,
                                        self.scanView.frame.origin.y + self.scanView.frame.size.height,
                                        self.overlayView.frame.size.width,
                                        self.overlayView.frame.size.height - self.scanView.frame.origin.y + self.scanView.frame.size.height));
    maskLayer.path = path;
    self.overlayView.layer.mask = maskLayer;
    CGPathRelease(path);
}


#pragma mark - 扫描结果

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    if (metadataObjects && metadataObjects.count > 0) {
        [self playAudio:@"noticeMusic" Type:@"wav"];
        [_captureSession stopRunning];
        
        AVMetadataMachineReadableCodeObject * metadataObject = [metadataObjects objectAtIndex : 0 ];
        //输出扫描字符串
        NSString *data = metadataObject.stringValue;
        if (_QRCodeResult) {
            _QRCodeResult(data);
            [self selfRemoveFromSuperview];
        } else {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"扫码" message:data delegate:self cancelButtonTitle:@"好" otherButtonTitles:nil];
                [alert show];
        }
    }
    
//    if ([[result substringToIndex:7] isEqualToString:@"http://"]) {
//        [[UIApplication sharedApplication]openURL:[NSURL URLWithString:result]];
//    }
}



#pragma mark - properties

- (UIView *)overlayView {
    if (!_overlayView) {
        _overlayView = [[UIView alloc] initWithFrame:self.view.bounds];
        _overlayView.alpha = .5f;
        _overlayView.backgroundColor = [UIColor blackColor];
        _overlayView.userInteractionEnabled = NO;
        _overlayView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    }
    return _overlayView;
}

- (UIButton *)leftButton {
    if (!_leftButton) {
        CGRect leftFrame = CGRectMake(-2, 10, 60, 64);
        _leftButton= [UIButton buttonWithType:UIButtonTypeCustom];
        _leftButton.frame = leftFrame;
        [_leftButton addTarget:self action:@selector(dismissOverlayView:) forControlEvents:UIControlEventTouchUpInside];
        [_leftButton setImage:[UIImage imageNamed:@"back"] forState:UIControlStateNormal];

    }
    return _leftButton;
}

- (UIImageView *)scanView {
    if (!_scanView) {
        _scanView = [[UIImageView alloc] initWithFrame:_scanCrop];
        _scanView.image = [UIImage imageNamed:@"scan_box"];
        _scanView.contentMode = UIViewContentModeScaleAspectFit;
        _scanView.backgroundColor = [UIColor clearColor];
    }
    return _scanView;
}

- (UIImageView *)lineView {
    if (!_lineView) {
        _lineView = [[UIImageView alloc] initWithFrame:CGRectMake(_scanCrop.origin.x, _scanView.frame.origin.y, _scanCrop.size.width, 2)];
        _lineView.image = [UIImage imageNamed:@"scan_line"];
        _lineView.contentMode = UIViewContentModeScaleAspectFill;
        _lineView.backgroundColor = [UIColor clearColor];
    }
    return _lineView;
}


- (UIButton *)lightButton {
    if (!_lightButton) {
        _lightButton= [UIButton buttonWithType:UIButtonTypeCustom];
        _lightButton.frame = CGRectMake(0, 0, 100, 100);
        _lightButton.center = CGPointMake(self.view.center.x, self.view.center.y+200);
        _lightButton.backgroundColor = [UIColor clearColor];
        [_lightButton addTarget:self action:@selector(turnLightAction:) forControlEvents:UIControlEventTouchUpInside];
        [_lightButton setBackgroundImage:[UIImage imageNamed:@"light_off"] forState:UIControlStateNormal];
        [_lightButton setBackgroundImage:[UIImage imageNamed:@"light_on"] forState:UIControlStateSelected];
    }
    return _lightButton;
}



#pragma mark - Animation

- (void)addAnimation {
    _lineView.hidden = NO;
    CABasicAnimation *animation = [VQRCodeController moveYTime:2 fromY:[NSNumber numberWithFloat:0] toY:[NSNumber numberWithFloat:CGRectGetHeight(_scanCrop)] rep:OPEN_MAX];
    [_lineView.layer addAnimation:animation forKey:@"LineAnimation"];
}

+ (CABasicAnimation *)moveYTime:(float)time fromY:(NSNumber *)fromY toY:(NSNumber *)toY rep:(int)rep {
    
    CABasicAnimation *animationMove = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    [animationMove setFromValue:fromY];
    [animationMove setToValue:toY];
    animationMove.duration = time;
    animationMove.delegate = self;
    animationMove.repeatCount  = rep;
    animationMove.fillMode = kCAFillModeForwards;
    animationMove.removedOnCompletion = NO;
    animationMove.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    return animationMove;
}


/**
 *  去除扫码动画
 */
- (void)removeAnimation{
    [_lineView.layer removeAnimationForKey:@"LineAnimation"];
    _lineView.hidden = YES;
}

/**
 *  从父视图中移出
 */
- (void)selfRemoveFromSuperview{
    [_captureSession removeObserver:self forKeyPath:@"running" context:nil];
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.view.alpha = 0;
    } completion:^(BOOL finished) {
        [self.view removeFromSuperview];
        [self removeFromParentViewController];
    }];
}

#pragma mark - actions

/**
 *  扫码取消button方法
 */
- (void)dismissOverlayView:(id)sender {
    [self selfRemoveFromSuperview];
}

- (void)turnLightAction:(UIButton *)button {
    button.selected = !button.selected;
 
    [self turnOn:button.selected];
}



#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context{
    
    if ([object isKindOfClass:[AVCaptureSession class]]) {
        BOOL isRunning = ((AVCaptureSession *)object).isRunning;
        if (isRunning) {
            [self addAnimation];
        }else{
            [self removeAnimation];
        }
    }
}



#pragma mark - Tools
/**
 *  二维码扫描有效区域
 */
-(CGRect)getScanCrop:(CGRect)rect readerViewBounds:(CGRect)readerViewBounds {

    CGFloat x,y,width,height;
    
    x = (rect.origin.y)/CGRectGetHeight(readerViewBounds);
    y = rect.origin.x/CGRectGetWidth(readerViewBounds);
    width = CGRectGetHeight(rect)/CGRectGetHeight(readerViewBounds);
    height = CGRectGetWidth(rect)/CGRectGetWidth(readerViewBounds);
    
    return CGRectMake(x, y, width, height);
}

/**
 *  播放声音
 */
- (void)playAudio:(NSString *)name Type:(NSString *)type {

    SystemSoundID soundID;
    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:type];
    NSURL *filePath = [NSURL fileURLWithPath:path isDirectory:NO];
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)filePath, &soundID);
    AudioServicesPlaySystemSound(soundID);
}

/**
 *  开关闪光灯方法
 */
- (void)turnOn:(bool)on {
    Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
    if (captureDeviceClass != nil) {
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        
        if ([device hasTorch] && [device hasFlash]) {
            
            [device lockForConfiguration:nil];
            if (on) {
                [device setTorchMode:AVCaptureTorchModeOn];
                [device setFlashMode:AVCaptureFlashModeOn];
                
            } else {
                [device setTorchMode:AVCaptureTorchModeOff];
                [device setFlashMode:AVCaptureFlashModeOff];
            }
            [device unlockForConfiguration];
        }
    }
}




- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
