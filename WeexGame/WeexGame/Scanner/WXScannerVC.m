/**
 * Created by Weex.
 * Copyright (c) 2016, Alibaba, Inc. All rights reserved.
 *
 * This source code is licensed under the Apache Licence 2.0.
 * For the full copyright and license information,please view the LICENSE file in the root directory of this source tree.
 */

#import "WXScannerVC.h"
#import "AppDelegate.h"
#import "ViewController.h"
#import "WXDebugTool.h"
#import <AudioToolbox/AudioToolbox.h>
#import <WeexSDK/WXSDKEngine.h>

@interface WXScannerVC ()

@property (nonatomic, strong) AVCaptureSession * session;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *captureLayer;
@property (nonatomic, strong) UIView *sanFrameView;

@end

@implementation WXScannerVC

#pragma mark - lifeCircle

- (void)dealloc {
    [_captureLayer removeFromSuperlayer];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.edgesForExtendedLayout = UIRectEdgeNone;
    
    self.session = [[AVCaptureSession alloc]init];
    [_session setSessionPreset:AVCaptureSessionPresetHigh];
    AVCaptureDevice * device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput * input = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
    AVCaptureMetadataOutput * output = [[AVCaptureMetadataOutput alloc]init];
    [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    [_session addInput:input];
    [_session addOutput:output];
    
    output.metadataObjectTypes=@[AVMetadataObjectTypeQRCode,AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode128Code];
    
    _captureLayer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
    _captureLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;
    _captureLayer.frame=self.view.layer.bounds;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.view.layer addSublayer:_captureLayer];
    [_session startRunning];
}

- (void) viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [_captureLayer removeFromSuperlayer];
    [_session stopRunning];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    [_captureLayer removeFromSuperlayer];
    [_session stopRunning];
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    if (metadataObjects.count > 0) {
        AVMetadataMachineReadableCodeObject * metadataObject = [metadataObjects objectAtIndex : 0 ];
        [self openURL:metadataObject.stringValue];
    }
}

- (void)openURL:(NSString*)URL
{
    NSURL *url = [NSURL URLWithString:URL];
    [self remoteDebug:url];
    [self jsReplace:url];
    ViewController * controller = [[ViewController alloc] init];
    controller.url = url;
    controller.source = @"scan";
    
    if ([url.port integerValue] == 8081) {
        NSURL *socketURL = [NSURL URLWithString:[NSString stringWithFormat:@"ws://%@:8082", url.host]];
        controller.hotReloadSocket = [[SRWebSocket alloc] initWithURL:socketURL protocols:@[@"echo-protocol"]];
        controller.hotReloadSocket.delegate = controller;
        [controller.hotReloadSocket open];
    }
    
    [[self navigationController] pushViewController:controller animated:YES];
}

#pragma mark - Replace JS
- (void)jsReplace:(NSURL *)url
{
    if ([[url host] isEqualToString:@"weex-remote-debugger"]){
        NSString* path = [url path];
        if ([path isEqualToString:@"/dynamic/replace/bundle"]){
            for (NSString * param in [[url query] componentsSeparatedByString:@"&"]) {
                NSArray* elts = [param componentsSeparatedByString:@"="];
                if ([elts count] < 2) {
                    continue;
                }
                if ([[elts firstObject] isEqualToString:@"bundle"]){
                    [WXDebugTool setReplacedBundleJS:[NSURL URLWithString:[elts lastObject]]];
                }
            }
        }
        
        if ([path isEqualToString:@"/dynamic/replace/framework"]){
            for (NSString * param in [[url query] componentsSeparatedByString:@"&"]) {
                NSArray* elts = [param componentsSeparatedByString:@"="];
                if ([elts count] < 2) {
                    continue;
                }
                if ([[elts firstObject] isEqualToString:@"framework"]){
                    [WXDebugTool setReplacedJSFramework:[NSURL URLWithString:[elts lastObject]]];
                }
            }
        }
    }
}

#pragma mark Remote debug
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
- (void)remoteDebug:(NSURL *)url
{
    if ([url.scheme isEqualToString:@"ws"]) {
        [WXSDKEngine connectDebugServer:url.absoluteString];
        [WXSDKEngine initSDKEnviroment];
    }
    
    NSString *query = url.query;
    for (NSString *param in [query componentsSeparatedByString:@"&"]) {
        NSArray *elts = [param componentsSeparatedByString:@"="];
        if([elts count] < 2) continue;
        if ([[elts firstObject] isEqualToString:@"_wx_debug"]) {
            [WXDebugTool setDebug:YES];
            [WXSDKEngine connectDebugServer:[[elts lastObject]  stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
            if ([[[self.navigationController viewControllers] objectAtIndex:0] isKindOfClass:NSClassFromString(@"WXDemoViewController")]) {
                ViewController * vc = (ViewController*)[[self.navigationController viewControllers] objectAtIndex:0];
                [vc performSelector:NSSelectorFromString(@"loadRefreshCtl")];
                [self.navigationController popToViewController:vc animated:NO];
            }
            return;
        }
    }
}
#pragma clang diagnostic pop

@end
